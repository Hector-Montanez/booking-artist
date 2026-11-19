import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/screens/payment_screen.dart';
import 'package:booking_artist/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Booking _booking(Artist a) => Booking(
  id: '1',
  artist: a,
  package: 'Toque con agrupación',
  eventType: EventType.conAgrupacion,
  date: DateTime(2026, 12, 20),
  time: const TimeOfDay(hour: 20, minute: 0),
  venue: 'Plaza de Caguas',
  clientName: 'Orquesta La Criolla',
  clientType: ClientType.agrupacion,
  notes: '',
  total: 129.6,
  amountCharged: 26,
  payDeposit: true,
  cardLast4: '4242',
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('el pago se cobra solo si el artista acepta', () {
    final state = AppState();
    final bongo = state.artists.firstWhere((a) => a.id == 'i1');

    final accepted = _booking(bongo);
    state.addBooking(accepted);
    expect(accepted.payment, PaymentStatus.retenido);
    state.acceptBooking(accepted);
    expect(accepted.status, BookingStatus.confirmada);
    expect(accepted.payment, PaymentStatus.cobrado);

    final rejected = _booking(bongo);
    state.addBooking(rejected);
    state.rejectBooking(rejected);
    expect(rejected.status, BookingStatus.rechazada);
    expect(rejected.payment, PaymentStatus.liberado);
  });

  Booking quote(Artist a, {String id = 'q1', int hour = 20}) => Booking(
    id: id,
    artist: a,
    eventType: EventType.boda,
    date: DateTime(2030, 6, 1),
    time: TimeOfDay(hour: hour, minute: 0),
    hours: 2,
    venue: 'Hacienda Siesta Alegre, Cayey',
    clientName: 'Boda Rivera-Cruz',
    clientEmail: 'novios@ejemplo.com',
    notes: '120 invitados',
    total: 0,
    amountCharged: 0,
    payDeposit: false,
    cardLast4: '',
  );

  test(
    'cotización: el artista envía su precio y el cliente lo acepta',
    () async {
      final state = AppState();
      final sofia = state.artists.firstWhere((a) => a.id == 'a1');
      final b = quote(sofia);
      expect(b.isQuote, isTrue);
      expect(await state.requestQuote(b), isNull);
      expect(b.status, BookingStatus.pendiente);
      expect(b.payment, PaymentStatus.sinPago);
      expect(b.blocksSchedule, isFalse, reason: 'pedir precio no aparta');
      expect(state.notifications.first.title, 'Nueva solicitud de cotización');

      expect(await state.sendQuote(b, 450, 'Incluye sonido'), isNull);
      expect(b.status, BookingStatus.cotizada);
      expect(b.quotePrice, 450);
      expect(b.quoteNote, 'Incluye sonido');
      expect(state.notifications.first.recipientEmail, 'novios@ejemplo.com');
      expect(state.notifications.first.title, contains('te envió su precio'));

      // El artista puede cambiar el precio antes de que el cliente acepte.
      expect(await state.sendQuote(b, 420, ''), isNull);
      expect(b.quotePrice, 420);

      expect(await state.acceptQuote(b), isNull);
      expect(b.status, BookingStatus.confirmada);
      expect(b.total, 420);
      expect(b.blocksSchedule, isTrue);
      expect(state.notifications.first.recipientEmail, sofia.email);
      expect(await state.acceptQuote(b), isNotNull, reason: 'ya está cerrada');
    },
  );

  test('el cliente puede decir que no al precio', () async {
    final state = AppState();
    final sofia = state.artists.firstWhere((a) => a.id == 'a1');
    final b = quote(sofia);
    await state.requestQuote(b);
    await state.sendQuote(b, 900, '');
    expect(await state.cancelBooking(b), isNull);
    expect(b.status, BookingStatus.cancelada);
    expect(state.notifications.first.title, contains('no aceptó tu precio'));
  });

  test(
    'el artista puede confirmar directo lo que acordaron por WhatsApp',
    () async {
      final state = AppState();
      final sofia = state.artists.firstWhere((a) => a.id == 'a1');
      final b = quote(sofia);
      await state.requestQuote(b);
      expect(await state.acceptBooking(b, price: 300), isNull);
      expect(b.status, BookingStatus.confirmada);
      expect(b.total, 300);
    },
  );

  test(
    'dos clientes piden la misma hora: el segundo no puede aceptar',
    () async {
      final state = AppState();
      final sofia = state.artists.firstWhere((a) => a.id == 'a1');
      // El trío es otro perfil de Sofía: tampoco puede tocar a esa hora.
      final trio = state.artists.firstWhere((a) => a.id == 'a1__2');
      final first = quote(sofia, id: 'q1');
      final second = quote(trio, id: 'q2', hour: 21);
      await state.requestQuote(first);
      await state.requestQuote(second);
      await state.sendQuote(first, 400, '');
      await state.sendQuote(second, 600, '');
      expect(await state.acceptQuote(first), isNull);
      expect(await state.acceptQuote(second), contains('otra reserva'));
      expect(second.status, BookingStatus.cotizada);
    },
  );

  test('el enlace de WhatsApp lleva el número de PR con el 1', () {
    expect(whatsappDigits('(787) 555-0202'), '17875550202');
    expect(whatsappDigits('+1 787 555 0202'), '17875550202');
    final state = AppState();
    final sofia = state.artists.firstWhere((a) => a.id == 'a1');
    expect(sofia.hasWhatsapp, isTrue);
    final text = quoteWhatsappText(
      artist: sofia,
      eventType: EventType.boda,
      when: ' el sábado',
    );
    expect(text, contains('una boda el sábado'));
    expect(text, contains('¿Cuánto cobrarías?'));
  });

  test('se pueden contratar payasos', () {
    final state = AppState();
    expect(
      state.artists.where((a) => a.category == ArtistCategory.payaso),
      isNotEmpty,
    );
  });

  test('hay músicos independientes por instrumento', () {
    final state = AppState();
    final bongoseros = state.artists.where(
      (a) =>
          a.category == ArtistCategory.musicoIndependiente &&
          a.instruments.contains('Bongosero'),
    );
    expect(bongoseros, isNotEmpty);
  });

  testWidgets('la pantalla de pago valida la tarjeta', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PaymentResult? result;
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PaymentResult>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const PaymentScreen(amount: 26, concept: 'Prueba'),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Pagar y enviar'));
    await tester.pump();
    expect(find.text('Número de tarjeta incompleto'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '4242424242424242');
    // En el teléfono solo hay números: la barra se pone sola.
    await tester.enterText(fields.at(1), '1230');
    String shown(int i) => tester
        .widget<EditableText>(
          find.descendant(
            of: fields.at(i),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
    expect(shown(0), '4242 4242 4242 4242');
    expect(shown(1), '12/30');
    await tester.enterText(fields.at(2), '123');
    await tester.enterText(fields.at(3), 'Ana Ortiz');
    await tester.tap(find.textContaining('Pagar y enviar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(result?.last4, '4242');
    expect(result?.method, PaymentMethod.tarjeta);
  });

  testWidgets('se puede pagar con ATH Móvil', (tester) async {
    PaymentResult? result;
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PaymentResult>(
                  MaterialPageRoute(
                    builder: (_) => const PaymentScreen(
                      amount: 58,
                      concept: 'Prueba',
                      phone: '787 555 0101',
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATH Móvil'));
    await tester.pump();
    expect(find.text('Teléfono de tu cuenta de ATH Móvil'), findsOneWidget);
    await tester.tap(find.textContaining('Pagar con ATH Móvil'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(result?.method, PaymentMethod.ath);
    expect(result?.last4, '0101');
  });

  test('el monto se muestra con centavos cuando hace falta', () {
    expect(money(192.5), r'$192.50');
    expect(money(198), r'$198');
  });
}
