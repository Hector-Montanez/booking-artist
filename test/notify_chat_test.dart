import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('el artista recibe aviso por teléfono y email, y pueden chatear', () {
    final state = AppState();
    final client = state.findAccount(
      AppState.demoClientEmail,
      AppState.demoPassword,
    )!;
    final artistAccount = state.findAccount(
      AppState.demoArtistEmail,
      AppState.demoPassword,
    )!;
    final sofia = artistAccount.artist!;

    // El restaurante reserva y escribe al artista.
    state.signIn(client);
    final booking = Booking(
      id: '1',
      artist: sofia,
      package: sofia.packages.first.name,
      eventType: EventType.restaurante,
      date: DateTime(2026, 11, 14),
      time: const TimeOfDay(hour: 19, minute: 0),
      venue: 'Restaurante El Patio',
      clientName: client.displayName,
      clientType: client.clientType,
      clientEmail: client.email,
      notes: '',
      total: 194.4,
      amountCharged: 58,
      payDeposit: true,
      cardLast4: '4242',
    );
    state.addBooking(booking);
    final chat = state.conversationWith(
      artist: sofia,
      clientEmail: client.email,
      clientName: client.displayName,
      clientType: client.clientType,
    );
    state.sendMessage(chat, '¿Puedes tocar "Sabor a mí"?');

    // La artista entra y ve la solicitud, el aviso por email y el mensaje.
    state.signIn(artistAccount);
    expect(state.unreadNotifications, 2);
    final request = state.myNotifications.last;
    expect(request.title, 'Nueva solicitud de reserva');
    expect(request.byEmail, isTrue);
    expect(state.unreadMessages, 1);

    state.sendMessage(chat, '¡Claro que sí!');
    state.acceptBooking(booking);

    // El restaurante ve la respuesta y la confirmación.
    state.signIn(client);
    expect(state.unreadMessages, 1);
    expect(
      state.myNotifications.map((n) => n.title),
      contains('Sofía Rivera aceptó tu reserva'),
    );
    expect(chat.messages.map((m) => m.fromArtist), [false, true]);
  });
}
