import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/main.dart';
import 'package:booking_artist/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Un restaurante crea su cuenta y ve los artistas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quiero contratar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurante o negocio'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'El Patio');
    await tester.enterText(fields.at(1), 'Ana Ortiz');
    await tester.enterText(fields.at(2), 'Calle Ruiz Belvis 10');
    await tester.enterText(fields.at(4), '787 555 1234');
    await tester.enterText(fields.at(5), 'ana@elpatio.com');
    await tester.enterText(fields.at(6), 'secreto1');
    // El permiso para SMS empieza sin marcar.
    await tester.ensureVisible(
      find.text('Acepto recibir SMS sobre mis reservas'),
    );
    await tester.tap(find.text('Acepto recibir SMS sobre mis reservas'));
    await tester.pump();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(state.account?.clientType, ClientType.restaurante);
    expect(state.account?.displayName, 'El Patio');
    expect(state.account?.smsOptIn, isTrue);
    expect(find.text('Caguas, Puerto Rico'), findsOneWidget);
    await tester.tap(find.text('Sofía Rivera'));
    await tester.pumpAndSettle();
    expect(find.text('Precios del artista'), findsOneWidget);
  });

  testWidgets('Un artista crea su cuenta y edita su página', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
    await fill('Teléfono', '7875551234');
    await fill('Correo electrónico', 'luis@example.com');
    await fill('Contraseña', 'secreto1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(state.myArtistProfile.name, 'Trío Borinquen');
    expect(state.myArtistProfile.instruments, ['Bongosero']);
    expect(find.text('Solicitudes'), findsOneWidget);
    await tester.tap(find.text('Mi página'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Frase corta'),
      'Boleros de siempre',
    );
    expect(state.myArtistProfile.tagline, 'Boleros de siempre');
  });
}
