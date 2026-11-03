import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import 'booking_screen.dart';
import 'payment_screen.dart';
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
                  'Aún no tienes reservas.\nExplora artistas y envía tu primera solicitud.',
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
                          b.payment == PaymentStatus.porPagar
                              ? '${money(b.amountCharged)} · ${b.payment.label}'
                              : '${b.paidWith}: ${money(b.amountCharged)} · '
                                    '${b.payment.label}',
                        ),
                        if (b.status == BookingStatus.confirmada &&
                            b.balance > 0)
                          Text(
                            'Resto a pagar el día del evento: ${money(b.balance)}',
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Total: ${money(b.total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Escribir al artista',
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () =>
                                  chatWithArtist(context, b.artist),
                            ),
                            if (b.status == BookingStatus.pendiente &&
                                b.payment == PaymentStatus.porPagar)
                              TextButton(
                                onPressed: () => _finishPayment(context, b),
                                child: const Text('Pagar'),
                              ),
                            if (b.status == BookingStatus.pendiente)
                              TextButton(
                                onPressed: () => _cancel(context, b),
                                child: const Text('Cancelar'),
                              ),
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
  final error = await AppScope.of(context).cancelBooking(b);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error ??
            (b.payment == PaymentStatus.reembolsado
                ? 'Reserva cancelada. Te devolvimos el pago de ATH Móvil.'
                : 'Reserva cancelada. No se cobró nada.'),
      ),
    ),
  );
}

/// Termina de pagar una reserva que quedó sin pagar.
Future<void> _finishPayment(BuildContext context, Booking b) async {
  final state = AppScope.of(context);
  final paid = await Navigator.of(context).push<PaymentResult>(
    MaterialPageRoute(
      builder: (_) => PaymentScreen(
        amount: b.amountCharged,
        concept: '${b.package} · ${b.artist.name}',
        booking: b,
        phone: state.account?.phone ?? '',
      ),
    ),
  );
  if (paid == null || !context.mounted) return;
  state.notifyArtist(b);
  await showPaidDialog(context, b);
}
