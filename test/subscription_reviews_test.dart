import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/screens/artist_detail_screen.dart';
import 'package:booking_artist/screens/artist_panel_screen.dart';
import 'package:booking_artist/screens/booking_screen.dart';
import 'package:booking_artist/screens/my_bookings_screen.dart';
import 'package:booking_artist/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('el artista aparece durante su mes gratis y después solo si paga', () {
    final now = DateTime.now();
    final a = AppState().artists.first
      ..subscription = null
      ..createdAt = now;
    expect(a.trialEnd.isAfter(now.add(const Duration(days: 29))), isTrue);
    expect(a.listed, isTrue);

    a.subscription = Subscription(
      status: 'sinTarjeta',
      trialEnd: now.subtract(const Duration(days: 1)),
    );
    expect(a.listed, isFalse, reason: 'se acabó el mes gratis');

    a.subscription = Subscription(
      status: 'active',
      trialEnd: now.subtract(const Duration(days: 1)),
      paidUntil: now.add(const Duration(days: 20)),
    );
    expect(a.listed, isTrue);

    a.subscription!.status = 'canceled';
    expect(a.listed, isFalse);
  });

  test('en la demo el artista activa su suscripción sin cobrar', () async {
    final state = AppState();
    await state.login(AppState.demoArtistEmail, AppState.demoPassword);
    final s0 = state.myArtistProfile.effectiveSubscription;
    expect(s0.subscribed, isFalse);
    expect(s0.inTrial, isTrue);
    expect(await state.startSubscription(), isNull);
    final s = state.myArtistProfile.effectiveSubscription;
    expect(s.subscribed, isTrue);
    expect(s.simulated, isTrue);
    await state.setSubscriptionCanceled(true);
    expect(s.cancelAtPeriodEnd, isTrue);
  });

  test(
    'el cliente reseña un evento que ya pasó y sube la valoración',
    () async {
      final state = AppState();
      await state.login(AppState.demoClientEmail, AppState.demoPassword);
      final past = state.myClientBookings.firstWhere(
        (b) => b.id == 'seed-pasada',
      );
      final sofia = past.artist;
      final before = sofia.reviews;
      expect(state.canReview(past), isTrue);
      expect(await state.saveReview(past, 5, '¡Excelente!'), isNull);
      expect(sofia.reviews, before + 1);
      expect(state.reviewFor(past)!.rating, 5);
      // Editar no crea otra reseña.
      expect(await state.saveReview(past, 3, 'Bien'), isNull);
      expect(sofia.reviews, before + 1);
      expect(sofia.reviewList.first.text, 'Bien');

      final future = Booking(
        id: 'x',
        artist: sofia,
        package: sofia.packages.first.name,
        eventType: EventType.boda,
        date: DateTime.now().add(const Duration(days: 3)),
        time: const TimeOfDay(hour: 20, minute: 0),
        venue: 'Caguas',
        clientName: 'Ana',
        clientEmail: AppState.demoClientEmail,
        notes: '',
        total: 100,
        amountCharged: 30,
        payDeposit: true,
        cardLast4: '',
        status: BookingStatus.confirmada,
      );
      expect(
        state.canReview(future),
        isFalse,
        reason: 'el evento no ha pasado',
      );
    },
  );

  testWidgets('un paquete de restaurante se reserva sin depósito', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    await state.login(AppState.demoClientEmail, AppState.demoPassword);
    final sofia = state.artists.firstWhere((a) => a.id == 'a1');
    final cena = sofia.packages.firstWhere((p) => !p.takesDeposit);
    final boda = sofia.packages.firstWhere((p) => p.takesDeposit);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: BookingScreen(artist: sofia, initialPackage: cena),
        ),
      ),
    );
    expect(find.text('Enviar solicitud'), findsOneWidget);
    expect(find.text('Paquete de restaurante: sin depósito'), findsOneWidget);
    expect(find.textContaining('Depósito del'), findsNothing);

    await tester.tap(find.text(boda.name));
    await tester.pumpAndSettle();
    expect(find.textContaining('Continuar al pago'), findsOneWidget);
    expect(find.textContaining('Depósito del'), findsOneWidget);
  });

  testWidgets('las pantallas nuevas caben en un teléfono', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    Future<void> show(Widget w) async {
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(theme: futuristTheme(), home: w),
        ),
      );
      await tester.pumpAndSettle();
    }

    await state.login(AppState.demoArtistEmail, AppState.demoPassword);
    await show(const ArtistPanelScreen());
    expect(find.textContaining('Mes gratis'), findsOneWidget);
    await tester.tap(find.text('Activar suscripción'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Suscrito'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reseñas de mis clientes'), 300);
    expect(find.text('Reseñas de mis clientes'), findsOneWidget);

    state.signOut();
    await state.login(AppState.demoClientEmail, AppState.demoPassword);
    await show(const MyBookingsScreen());
    await tester.tap(find.text('Dejar reseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pump();
    await tester.tap(find.text('Publicar reseña'));
    await tester.pumpAndSettle();
    expect(find.text('Editar reseña'), findsOneWidget);

    final sofia = state.artists.firstWhere((a) => a.id == 'a1');
    await show(ArtistDetailScreen(artist: sofia));
    await tester.scrollUntilVisible(find.text('Reseñas'), 300);
    expect(find.text('Restaurante El Patio'), findsWidgets);
  });
}
