import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/main.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre la lista de pueblos y escoge uno.
Future<void> pickTown(WidgetTester tester, String town) async {
  final field = find.byType(DropdownButtonFormField<String>).last;
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.text(town),
    find.byType(Scrollable).last,
    const Offset(0, -100),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(town).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Un restaurante crea su cuenta y ve los artistas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quiero contratar'));
    await tester.pumpAndSettle();
    // Escoge el estilo claro con su miniatura: la app cambia enseguida.
    addTearDown(() => appStyle.value = AppStyle.futurista);
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(appStyle.value, AppStyle.claro);
    await tester.tap(find.text('Restaurante o negocio'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'El Patio');
    await tester.enterText(fields.at(1), 'Ana Ortiz');
    await tester.enterText(fields.at(2), 'Calle Ruiz Belvis 10');
    await tester.enterText(fields.at(3), '787 555 1234');
    await tester.enterText(fields.at(4), 'ana@elpatio.com');
    await tester.enterText(fields.at(5), 'secreto1');
    await pickTown(tester, 'Caguas');
    // El permiso para SMS empieza sin marcar.
    expect(state.account, isNull);
    await tester.ensureVisible(find.text(smsConsentTitle));
    await tester.tap(find.text(smsConsentTitle));
    await tester.pump();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(state.account?.clientType, ClientType.restaurante);
    expect(state.account?.displayName, 'El Patio');
    expect(state.account?.smsOptIn, isTrue);
    expect(state.account?.theme, 'claro');
    // Cambia de estilo desde su cuenta y se guarda.
    state.setStyle(AppStyle.clasico);
    expect(state.account?.theme, 'clasico');
    expect(appStyle.value, AppStyle.clasico);
    expect(state.account?.town, 'Caguas');
    expect(find.text('Caguas, Puerto Rico'), findsOneWidget);
    // Los artistas de Caguas salen primero, bajo su título.
    expect(find.text('En Caguas'), findsOneWidget);
    expect(find.text('Otros pueblos'), findsOneWidget);
    final caguasY = tester.getTopLeft(find.text('Sofía Rivera')).dy;
    final otherY = tester.getTopLeft(find.text('Otros pueblos')).dy;
    expect(caguasY, lessThan(otherY));
    expect(tester.getTopLeft(find.text('DJ Nova')).dy, greaterThan(otherY));
    await tester.tap(find.text('Sofía Rivera'));
    await tester.pumpAndSettle();
    expect(find.text('Precios del artista'), findsOneWidget);
  });

  testWidgets('Un artista crea su cuenta y edita su página', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soy artista'));
    await tester.pumpAndSettle();
    Future<void> fill(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, text);
    }

    await tester.tap(find.text('Bongosero'));
    await fill('Nombre artístico', 'Trío Borinquen');
    await fill('Tu nombre (privado)', 'Luis Rivera');
    await fill('Géneros', 'Bolero, Trova');
    await pickTown(tester, 'Ponce');
    await fill('Teléfono', '7875551234');
    await fill('Correo electrónico', 'luis@example.com');
    await fill('Contraseña', 'secreto1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(state.myArtistProfile.name, 'Trío Borinquen');
    expect(state.myArtistProfile.instruments, ['Bongosero']);
    expect(state.myArtistProfile.zone, 'Ponce');
    expect(state.myTown, 'Ponce');
    expect(find.text('Solicitudes'), findsOneWidget);
    await tester.tap(find.text('Mi página'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Frase corta'),
      'Boleros de siempre',
    );
    expect(state.myArtistProfile.tagline, 'Boleros de siempre');
  });

  testWidgets('Una cuenta sin pueblo lo escoge al entrar', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    // Cuenta creada antes de que la app pidiera el pueblo.
    state.signIn(
      Account(
        role: UserRole.cliente,
        name: 'Cliente Viejo',
        email: 'viejo@example.com',
        phone: '787 555 0000',
      ),
    );
    await tester.pumpAndSettle();
    expect(state.needsTown, isTrue);
    expect(find.text('¿De qué pueblo eres?'), findsOneWidget);
    await pickTown(tester, 'Bayamón');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(state.needsTown, isFalse);
    expect(state.account?.town, 'Bayamón');
    expect(find.text('En Bayamón'), findsOneWidget);
  });

  testWidgets('El cliente ve sus actividades en Calendario', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    final client = state.findAccount(
      AppState.demoClientEmail,
      AppState.demoPassword,
    )!;
    final sofia = state.artists.firstWhere((a) => a.id == 'a1');
    final today = DateTime.now();
    state.bookings.add(
      Booking(
        id: 'hoy',
        artist: sofia,
        package: sofia.packages.first.name,
        eventType: EventType.restaurante,
        date: DateTime(today.year, today.month, today.day),
        time: const TimeOfDay(hour: 23, minute: 0),
        venue: 'Restaurante El Patio',
        clientName: 'Restaurante El Patio',
        clientType: ClientType.restaurante,
        clientEmail: AppState.demoClientEmail,
        notes: '',
        total: sofia.packages.first.price,
        amountCharged: 0,
        payDeposit: false,
        noDeposit: true,
        cardLast4: '',
        status: BookingStatus.confirmada,
        payment: PaymentStatus.sinPago,
        paymentMethod: PaymentMethod.ninguno,
        hours: 1,
      ),
    );
    state.signIn(client);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();
    expect(find.text('Mi calendario'), findsOneWidget);
    // Ve el artista que contrató, no su propio nombre.
    expect(find.text('Sofía Rivera · Restaurante'), findsOneWidget);
    expect(find.text('Día libre'), findsNothing);
  });
}
