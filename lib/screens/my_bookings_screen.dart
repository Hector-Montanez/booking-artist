import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'inbox_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = state.myClientBookings;
    final fmt = DateFormat.yMMMEd('es');

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: mine.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aún no tienes reservas.\nExplora artistas y pídeles '
                  'cotización para tu evento.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mine.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final b = mine[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ArtistAvatar(artist: b.artist, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.artist.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text('${b.package} · ${b.eventType.label}'),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(b.status.label),
                              backgroundColor: b.status.color.withValues(
                                alpha: 0.15,
                              ),
                              side: BorderSide(color: b.status.color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${fmt.format(b.date)} · ${b.time.format(context)}',
                        ),
                        Text(b.venue),
                        const SizedBox(height: 4),
                        Text(
                          switch (b.status) {
                            BookingStatus.pendiente =>
                              'Esperando que ${b.artist.name} te envíe su '
                                  'precio.',
                            BookingStatus.cotizada =>
                              '${b.artist.name} te propone '
                                  '${money(b.quotePrice ?? b.total)}.',
                            _ when b.total > 0 =>
                              'Precio: ${money(b.total)} · el pago se arregla '
                                  'directo con el artista',
                            _ => 'El pago se arregla directo con el artista',
                          },
                          style: b.status == BookingStatus.cotizada
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
                        if (b.quoteNote.isNotEmpty)
                          Text(
                            b.quoteNote,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (state.reviewFor(b) case final r?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Text('Tu reseña: '),
                                Stars(rating: r.rating, size: 16),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Escribir al artista',
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () =>
                                  chatWithArtist(context, b.artist),
                            ),
                            WhatsAppButton(
                              artist: b.artist,
                              compact: true,
                              message: quoteWhatsappText(
                                artist: b.artist,
                                eventType: b.eventType,
                                when:
                                    ' el ${DateFormat.yMMMMEEEEd('es').format(b.date)}',
                                place: b.venue,
                              ),
                            ),
                            if (state.canReview(b))
                              TextButton.icon(
                                icon: const Icon(Icons.star_rounded),
                                onPressed: () => showReviewSheet(context, b),
                                label: Text(
                                  state.reviewFor(b) == null
                                      ? 'Dejar reseña'
                                      : 'Editar reseña',
                                ),
                              ),
                            if (b.status == BookingStatus.pendiente)
                              TextButton(
                                onPressed: () => _cancel(context, b),
                                child: const Text('Cancelar'),
                              ),
                            if (b.status == BookingStatus.cotizada) ...[
                              TextButton(
                                onPressed: () => _cancel(context, b),
                                child: const Text('No, gracias'),
                              ),
                              FilledButton(
                                onPressed: () => _acceptQuote(context, b),
                                child: const Text('Aceptar y reservar'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> _cancel(BuildContext context, Booking b) async {
  final messenger = ScaffoldMessenger.of(context);
  final quoted = b.status == BookingStatus.cotizada;
  final error = await AppScope.of(context).cancelBooking(b);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error ??
            (quoted
                ? 'Listo. Le avisamos a ${b.artist.name} que no aceptaste.'
                : 'Solicitud cancelada.'),
      ),
    ),
  );
}

/// El cliente acepta el precio del artista: la fecha queda reservada.
Future<void> _acceptQuote(BuildContext context, Booking b) async {
  final state = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('¿Reservar a ${b.artist.name}?'),
      content: Text(
        'Aceptas el precio de ${money(b.quotePrice ?? b.total)} y la fecha '
        'queda reservada. No pagas nada por la app: el pago se arregla '
        'directo con ${b.artist.name}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Todavía no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Aceptar y reservar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final error = await state.acceptQuote(b);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error ?? '¡Listo! Tu fecha con ${b.artist.name} quedó reservada.',
      ),
    ),
  );
}

/// Hoja para dejar (o cambiar) estrellas y un comentario al artista.
Future<void> showReviewSheet(BuildContext context, Booking b) async {
  final state = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final existing = state.reviewFor(b);
  var rating = existing?.rating ?? 0;
  final text = TextEditingController(text: existing?.text);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo te fue con ${b.artist.name}?',
              style: Theme.of(ctx).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            StarPicker(
              value: rating,
              onChanged: (v) => setSheet(() => rating = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: text,
              maxLines: 4,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'Cuéntales a otros clientes (opcional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: rating == 0 ? null : () => Navigator.pop(ctx, true),
              child: const Text('Publicar reseña'),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved != true) return;
  final error = await state.saveReview(b, rating, text.text.trim());
  messenger.showSnackBar(
    SnackBar(
      content: Text(error ?? '¡Gracias! Tu reseña ya se ve en su página.'),
    ),
  );
}
