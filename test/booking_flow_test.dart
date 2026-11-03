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
  package: a.packages.first.name,
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
