import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/subscription_card.dart';
import 'account_screen.dart';
import 'availability_screen.dart';
import 'inbox_screen.dart';

/// Vista del artista: responde las solicitudes de cotización de todos sus
/// perfiles y pega sus enlaces.
class ArtistPanelScreen extends StatelessWidget {
  const ArtistPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.myArtistProfile;
    final several = state.myProfiles.length > 1;
    // Solicitudes a cualquiera de sus perfiles; las abiertas primero. Las
    // reservas sin pagar (de cuando había pagos) no le llegan al artista.
    final requests =
        state.bookings
            .where(
              (b) =>
                  state.isMine(b.artist) && b.payment != PaymentStatus.porPagar,
            )
            .toList()
          ..sort((a, b) {
            if (a.open != b.open) return a.open ? -1 : 1;
            return a.start.compareTo(b.start);
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de artista'),
        actions: const [AccountButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ArtistAvatar(artist: me),
            title: Text(me.name, style: Theme.of(context).textTheme.titleLarge),
            subtitle: Text(
              me.listed
                  ? several
                        ? 'Tus ${state.myProfiles.length} perfiles están '
                              'publicados.'
                        : 'Tu página está publicada.'
                  : 'Tu página no aparece: activa tu membresía.',
            ),
          ),
          const SubscriptionCard(),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Mi disponibilidad'),
              subtitle: Text(
                me.weeklyHours.isEmpty
                    ? 'Aún no has puesto tu horario: nadie puede reservarte.'
                    : 'Disponible ${me.weeklyHours.length} días a la semana'
                          '${me.daysOff.isEmpty ? '' : ' · ${me.daysOff.length} días libres'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
              ),
            ),
          ),
          _header(context, 'Solicitudes de cotización'),
          if (requests.isEmpty)
            const Text(
              'Sin solicitudes todavía. Cuando un cliente te pida precio, '
              'aquí le respondes con tu cotización.',
            ),
          for (final b in requests)
            _RequestCard(booking: b, state: state, showProfile: several),
          _header(
            context,
            several ? 'Reseñas de ${me.name}' : 'Reseñas de mis clientes',
          ),
          if (me.reviews == 0)
            const Text(
              'Aún no tienes reseñas. Tus clientes pueden dejarte estrellas '
              'después de cada evento confirmado.',
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.star_rounded, color: starColor),
                const SizedBox(width: 4),
                Text(
                  '${me.rating.toStringAsFixed(1)} · ${me.reviews} '
                  '${me.reviews == 1 ? 'reseña' : 'reseñas'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in me.reviewList.take(20)) ReviewTile(review: r),
          ],
          _header(
            context,
            several ? 'Videos y redes de ${me.name}' : 'Mis videos y redes',
            onAdd: () => _addLink(context, state, me),
          ),
          for (final l in me.links)
            Card(
              child: ListTile(
                leading: Icon(l.kind.icon, color: l.kind.color),
                title: Text(l.title),
                subtitle: Text(
                  l.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => state.removeLink(me, l),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text, {VoidCallback? onAdd}) =>
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
          ],
        ),
      );

  Future<void> _addLink(BuildContext context, AppState state, Artist me) async {
    final url = TextEditingController();
    final link = await showDialog<MediaLink>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pega un enlace público'),
        content: TextField(
          controller: url,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://youtube.com/watch?v=…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final u = url.text.trim();
              if (Uri.tryParse(u)?.hasScheme != true) return;
              final kind = detectLinkKind(u);
              Navigator.pop(
                ctx,
                MediaLink(kind: kind, title: kind.label, url: u),
              );
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (link != null) state.addLink(me, link);
  }
}

LinkKind detectLinkKind(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.contains('youtube') || host.contains('youtu.be')) {
    return LinkKind.youtube;
  }
  if (host.contains('instagram')) return LinkKind.instagram;
  if (host.contains('tiktok')) return LinkKind.tiktok;
  if (host.contains('spotify')) return LinkKind.spotify;
  if (host.contains('facebook') || host.contains('fb.')) {
    return LinkKind.facebook;
  }
  return LinkKind.web;
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.booking,
    required this.state,
    this.showProfile = false,
  });

  final Booking booking;
  final AppState state;

  /// La cuenta tiene varios perfiles: se dice a cuál le pidieron.
  final bool showProfile;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fmt = DateFormat.yMMMEd('es');
    final theme = Theme.of(context);
    final price = b.quotePrice ?? (b.isQuote ? null : b.total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(b.clientType.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(b.clientName, style: theme.textTheme.titleMedium),
                ),
                Text(b.status.label, style: TextStyle(color: b.status.color)),
                if (b.clientEmail.isNotEmpty)
                  IconButton(
                    tooltip: 'Escribir al cliente',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => chatWithClient(context, b),
                  ),
              ],
            ),
            if (showProfile)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Para: ${b.artist.name}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text('${b.clientType.label} · ${b.eventType.label}'),
            const SizedBox(height: 4),
            Text(
              '${fmt.format(b.date)} · ${b.time.format(context)} · '
              '${_hours(b.hours)}',
            ),
            Text(b.venue),
            if (!b.isQuote) Text(b.package),
            if (b.notes.isNotEmpty) Text('Detalles: ${b.notes}'),
            const SizedBox(height: 4),
            Text(switch (b.status) {
              BookingStatus.pendiente when b.isQuote =>
                'Te pide cotización. Envíale tu precio.',
              BookingStatus.cotizada =>
                'Le enviaste ${money(price ?? 0)}. Falta que el cliente '
                    'lo acepte.',
              _ when price != null && price > 0 =>
                '${money(price)} · el pago se arregla directo contigo',
              _ => 'El pago se arregla directo contigo',
            }, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (b.quoteNote.isNotEmpty)
              Text('Tu nota: ${b.quoteNote}', style: theme.textTheme.bodySmall),
            if (b.open) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _respond(context, () => state.rejectBooking(b)),
                      child: const Text('No puedo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _quote(context, b),
                      child: Text(
                        b.status == BookingStatus.cotizada
                            ? 'Cambiar precio'
                            : 'Enviar precio',
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirm(context, b),
                  child: const Text('Ya acordamos: confirmar fecha'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El artista escribe su precio (y qué incluye) para esta solicitud.
  Future<void> _quote(BuildContext context, Booking b) async {
    final result = await _askPrice(
      context,
      title: 'Tu precio para ${b.clientName}',
      button: 'Enviar precio',
      initial: b.quotePrice,
      withNote: true,
      note: b.quoteNote,
      required: true,
    );
    if (result == null || !context.mounted) return;
    await _respond(
      context,
      () => state.sendQuote(b, result.$1!, result.$2),
      done: 'Le enviamos tu precio a ${b.clientName}.',
    );
  }

  /// Confirma la fecha sin esperar al cliente (ya acordaron, p. ej. por
  /// WhatsApp). El precio acordado es opcional.
  Future<void> _confirm(BuildContext context, Booking b) async {
    final result = await _askPrice(
      context,
      title: 'Confirmar la fecha',
      button: 'Confirmar',
      initial: b.quotePrice,
      intro:
          'Usa esto si ya acordaste el precio con ${b.clientName} (por '
          'ejemplo, por WhatsApp). La fecha queda reservada.',
    );
    if (result == null || !context.mounted) return;
    await _respond(
      context,
      () => state.acceptBooking(b, price: result.$1),
      done: 'Fecha confirmada. Le avisamos a ${b.clientName}.',
    );
  }
}

String _hours(double h) => h == h.roundToDouble() ? '${h.toInt()} h' : '$h h';

/// Pide un precio (y una nota). Devuelve null si se canceló.
Future<(double?, String)?> _askPrice(
  BuildContext context, {
  required String title,
  required String button,
  double? initial,
  String intro = '',
  bool withNote = false,
  String note = '',
  bool required = false,
}) {
  final price = TextEditingController(
    text: initial == null ? '' : initial.toStringAsFixed(0),
  );
  final noteCtrl = TextEditingController(text: note);
  final formKey = GlobalKey<FormState>();
  return showDialog<(double?, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (intro.isNotEmpty) ...[Text(intro), const SizedBox(height: 12)],
            TextFormField(
              controller: price,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: required ? 'Precio' : 'Precio acordado (opcional)',
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return required ? 'Escribe tu precio' : null;
                final n = double.tryParse(t);
                if (n == null || n <= 0 || n > 100000) {
                  return 'Escribe un número';
                }
                return null;
              },
            ),
            if (withNote) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Qué incluye (opcional)',
                  hintText: 'Ej. 3 sets de 45 minutos con sonido incluido',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final t = price.text.trim();
            Navigator.pop(ctx, (
              t.isEmpty ? null : double.parse(t),
              noteCtrl.text.trim(),
            ));
          },
          child: Text(button),
        ),
      ],
    ),
  );
}

/// Hace el cambio y muestra el error del servidor, o [done] si salió bien.
Future<void> _respond(
  BuildContext context,
  Future<String?> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await action();
  final text = error ?? done;
  if (text != null) messenger.showSnackBar(SnackBar(content: Text(text)));
}
