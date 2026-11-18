import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/main.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/screens/artist_calendar_screen.dart';
import 'package:booking_artist/screens/explore_screen.dart';
import 'package:booking_artist/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<AppState> artistState() async {
    final state = AppState();
    await state.login(AppState.demoArtistEmail, AppState.demoPassword);
    return state;
  }

  Future<void> show(WidgetTester tester, AppState state, Widget w) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: futuristTheme(),
          home: Scaffold(body: w),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el artista se busca en Explorar y ve que está apareciendo', (
    tester,
  ) async {
    final state = await artistState();
    final me = state.myArtistProfile;
    await show(tester, state, const ExploreScreen(forArtist: true));
    expect(find.text('Artistas en Tarima'), findsOneWidget);
    expect(find.textContaining('Estás apareciendo en la app'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, me.name);
    await tester.pumpAndSettle();
    expect(find.text('Este eres tú'), findsOneWidget);

    // Sin membresía activa no aparece en la lista.
    me.subscription = Subscription(
      status: 'canceled',
      trialEnd: DateTime.now().subtract(const Duration(days: 1)),
    );
    state.artistUpdated();
    await tester.pumpAndSettle();
    expect(find.text('Este eres tú'), findsNothing);
    expect(find.textContaining('membresía no está activa'), findsOneWidget);
  });

  testWidgets('el calendario muestra las actividades reservadas', (
    tester,
  ) async {
    final state = await artistState();
    final me = state.myArtistProfile;
    final day = DateTime.now();
    state.addBooking(
      Booking(
        id: 'cal-1',
        artist: me,
        package: me.packages.first.name,
        eventType: EventType.boda,
        date: DateTime(day.year, day.month, day.day),
        time: const TimeOfDay(hour: 20, minute: 0),
        venue: 'Hacienda Siesta Alegre',
        clientName: 'Boda Rivera-Cruz',
        notes: '',
        total: 300,
        amountCharged: 300,
        payDeposit: false,
        cardLast4: '4242',
      ),
    );
    await show(tester, state, const ArtistCalendarScreen());
    expect(find.text('Mi calendario'), findsOneWidget);
    expect(find.textContaining('Boda Rivera-Cruz'), findsOneWidget);
    expect(find.text('Hacienda Siesta Alegre'), findsOneWidget);
    expect(find.text('Esperando respuesta'), findsWidgets);

    // Otro mes: la actividad ya no sale en la lista del día escogido.
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Boda Rivera-Cruz'), findsOneWidget);
  });

  testWidgets('el artista tiene Calendario y Explorar en la barra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await artistState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    await tester.tap(find.byTooltip('Mi cuenta').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Mi cuenta'), findsOneWidget);
  });
}
