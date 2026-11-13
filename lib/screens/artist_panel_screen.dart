import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/subscription_card.dart';
import 'availability_screen.dart';
import 'inbox_screen.dart';

/// Vista del artista: fija sus precios, pega sus enlaces y acepta solicitudes.
class ArtistPanelScreen extends StatelessWidget {
  const ArtistPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.myArtistProfile;
    // Las reservas sin pagar no le llegan al artista.
    final requests = state.bookings
        .where((b) => b.artist == me && b.payment != PaymentStatus.porPagar)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de artista')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ArtistAvatar(artist: me),
            title: Text(me.name, style: Theme.of(context).textTheme.titleLarge),
            subtitle: Text(
              me.packages.isEmpty
                  ? 'Añade al menos un precio para aparecer en Explorar.'
                  : me.listed
                  ? 'Tu página está publicada.'
                  : 'Tu página no aparece: activa tu suscripción.',
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
          _header(context, 'Solicitudes recibidas'),
          if (requests.isEmpty)
            const Text(
              'Sin solicitudes todavía. Aquí verás las reservas que te envíen los clientes.',
            ),
          for (final b in requests) _RequestCard(booking: b, state: state),
          _header(
            context,
            'Mis precios',
            onAdd: () => _editPackage(context, state, me),
          ),
          for (final p in me.packages)
            Card(
              child: ListTile(
                leading: Icon(p.kind.icon),
                title: Text(p.name),
                subtitle: Text(
                  '${p.kind.label} · '
                  '${p.takesDeposit ? 'depósito ${me.depositPercent}%' : 'sin depósito'} · '
                  '${p.hours} h${p.description.isEmpty ? '' : ' · ${p.description}'}',
                ),
                trailing: Text(
                  money(p.price),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => _editPackage(context, state, me, existing: p),
              ),
            ),
          _header(context, 'Reseñas de mis clientes'),
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
            'Mis videos y redes',
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

  Future<void> _editPackage(
    BuildContext context,
    AppState state,
    Artist me, {
    PricePackage? existing,
  }) async {
    final name = TextEditingController(text: existing?.name);
    final price = TextEditingController(
      text: existing?.price.toStringAsFixed(0),
    );
    final hours = TextEditingController(
      text: existing?.hours.toString() ?? '2',
    );
    final desc = TextEditingController(text: existing?.description);
    var kind = existing?.kind ?? PackageKind.actividad;
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Nuevo paquete' : 'Editar paquete',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SegmentedButton<PackageKind>(
                  segments: [
                    for (final k in PackageKind.values)
                      ButtonSegment(
                        value: k,
                        icon: Icon(k.icon),
                        label: Text(
                          k == PackageKind.actividad ? 'Actividad' : k.label,
                        ),
                      ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (v) => setSheet(() => kind = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  kind == PackageKind.actividad
                      ? 'Bodas, cumpleaños, actividades. El cliente deja un '
                            'depósito del ${me.depositPercent}% (lo cambias en '
                            'Mi página).'
                      : kind.description,
                  style: Theme.of(ctx).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio',
                          prefixText: r'$ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'Número' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: hours,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Horas',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'Número' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: desc,
                  decoration: const InputDecoration(
                    labelText: 'Qué incluye (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () {
                          state.removePackage(me, existing);
                          Navigator.pop(ctx, false);
                        },
                        child: const Text('Eliminar'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      state.savePackage(
        me,
        PricePackage(
          name: name.text.trim(),
          price: double.parse(price.text),
          hours: double.parse(hours.text),
          description: desc.text.trim(),
          kind: kind,
        ),
        replacing: existing,
      );
    }
  }

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
  const _RequestCard({required this.booking, required this.state});

  final Booking booking;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fmt = DateFormat.yMMMEd('es');
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
                  child: Text(
                    b.clientName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
            Text('${b.clientType.label} · ${b.eventType.label}'),
            const SizedBox(height: 4),
            Text('${fmt.format(b.date)} · ${b.time.format(context)}'),
            Text(b.venue),
            Text(b.package),
            if (b.notes.isNotEmpty) Text('Notas: ${b.notes}'),
            const SizedBox(height: 4),
            Text(
              b.noDeposit
                  ? 'Restaurante, sin depósito: ${money(b.total)} a pagar '
                        'directo al artista'
                  : '${b.payDeposit ? 'Depósito' : 'Pago completo'} '
                        '(${b.paidWith}): '
                        '${money(b.amountCharged)} de ${money(b.total)} · '
                        '${b.payment.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (b.status == BookingStatus.pendiente) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _respond(context, () => state.rejectBooking(b)),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _respond(context, () => state.acceptBooking(b)),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Acepta o rechaza y muestra el error del servidor de pagos, si hay.
Future<void> _respond(
  BuildContext context,
  Future<String?> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await action();
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}
