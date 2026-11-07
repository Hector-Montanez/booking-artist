import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../cloud.dart' show PayError;
import '../models.dart';
import 'common.dart';

/// Estado de la suscripción del artista ($10 al mes, el primer mes gratis) y
/// el botón para activarla o cancelarla.
class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({super.key});

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _busy = false;
  Timer? _poll;
  DateTime? _pollUntil;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final s = state.myArtistProfile.effectiveSubscription;
    final fmt = DateFormat.yMMMMd('es');
    final price = '${money(subscriptionPrice)} al mes';

    final IconData icon;
    final Color color;
    final String title;
    final String body;
    String? action;
    VoidCallback? onAction;

    if (s.subscribed && s.cancelAtPeriodEnd) {
      icon = Icons.event_busy;
      color = const Color(0xFFF9A825);
      title = 'Suscripción cancelada';
      body =
          'Tu página sigue en la app hasta el ${fmt.format(s.visibleUntil)}. '
          'Después deja de aparecer.';
      action = 'Seguir suscrito';
      onAction = () => _setCanceled(false);
    } else if (s.subscribed && s.status == 'past_due') {
      icon = Icons.credit_card_off;
      color = const Color(0xFFC62828);
      title = 'No se pudo cobrar tu tarjeta';
      body =
          'Actualiza tu tarjeta antes del ${fmt.format(s.visibleUntil)} para '
          'seguir apareciendo en la app.';
      action = 'Actualizar tarjeta';
      onAction = _subscribe;
    } else if (s.subscribed) {
      icon = Icons.verified;
      color = const Color(0xFF2E7D32);
      title = s.inTrial
          ? 'Suscrito · mes gratis'
          : 'Suscripción activa · $price';
      body = s.inTrial
          ? 'Te quedan ${_days(s.trialDaysLeft)} gratis. El primer cobro de '
                '$price es el ${fmt.format(s.trialEnd)}.'
          : 'Próximo cobro: ${fmt.format(s.visibleUntil)}.';
      action = 'Cancelar';
      onAction = _confirmCancel;
    } else if (s.inTrial) {
      icon = Icons.card_giftcard;
      color = theme.colorScheme.primary;
      title = 'Mes gratis: te quedan ${_days(s.trialDaysLeft)}';
      body =
          'Tu página aparece en la app gratis hasta el '
          '${fmt.format(s.trialEnd)}. Después cuesta $price. Activa tu '
          'suscripción ya y no se te cobra nada hasta que termine el mes '
          'gratis.';
      action = 'Activar suscripción';
      onAction = _subscribe;
    } else {
      icon = Icons.visibility_off;
      color = const Color(0xFFC62828);
      title = 'Tu página no aparece en la app';
      body =
          'Se acabó tu mes gratis. Suscríbete por $price para que los '
          'clientes te encuentren y te reserven.';
      action = 'Suscribirme · $price';
      onAction = _subscribe;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(body),
            if (s.simulated)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Suscripción de prueba: no se cobró nada.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_pollUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Esperando la confirmación de Stripe…',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : onAction == _confirmCancel
                  ? TextButton(onPressed: onAction, child: Text(action))
                  : FilledButton(onPressed: onAction, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }

  String _days(int n) => n == 1 ? '1 día' : '$n días';

  Future<void> _subscribe() async {
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final url = await state.startSubscription();
      if (url != null) {
        await launchUrl(
          url,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.inAppBrowserView,
          webOnlyWindowName: '_blank',
        );
        _waitForStripe();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Suscripción activada.')),
        );
      }
    } on PayError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Después de poner la tarjeta en Stripe, pregunta cada pocos segundos si
  /// ya quedó suscrito.
  void _waitForStripe() {
    final state = AppScope.of(context);
    _poll?.cancel();
    setState(
      () => _pollUntil = DateTime.now().add(const Duration(minutes: 10)),
    );
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      final done = state.myArtistProfile.effectiveSubscription.subscribed;
      if (done || DateTime.now().isAfter(_pollUntil!)) {
        t.cancel();
        if (mounted) setState(() => _pollUntil = null);
        return;
      }
      try {
        await state.cloud?.refreshSubscription();
      } catch (_) {}
    });
  }

  Future<void> _confirmCancel() async {
    final until = DateFormat.yMMMMd('es').format(
      AppScope.of(context).myArtistProfile.effectiveSubscription.visibleUntil,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la suscripción?'),
        content: Text(
          'No se te cobra más. Tu página sigue en la app hasta el $until y '
          'después deja de aparecer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok == true) await _setCanceled(true);
  }

  Future<void> _setCanceled(bool cancel) async {
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await state.setSubscriptionCanceled(cancel);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
