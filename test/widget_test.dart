import 'package:booking_artist/app_state.dart';
import 'package:booking_artist/main.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/places.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google Maps simulado: siempre sugiere la dirección de El Patio.
class _FakeMaps extends PlacesClient {
  final searches = <String>[];
  @override
  Future<bool> ready() async => true;
  @override
  Future<List<PlaceSuggestion>> search(String text, String session) async {
    searches.add(text);
    return const [
      PlaceSuggestion('p1', 'Calle Ruiz Belvis 10', 'Caguas, Puerto Rico'),
    ];
  }

  @override
  Future<PlaceDetails?> details(String id, String session) async =>
      const PlaceDetails(
        address: 'Calle Ruiz Belvis 10, Caguas, 00725',
        town: 'Caguas',
        lat: 18.23,
        lng: -66.03,
      );
}

void main() {
  testWidgets('Un restaurante crea su cuenta y ve los artistas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final maps = _FakeMaps();
    PlacesClient.instance = maps;
    addTearDown(() => PlacesClient.instance = PlacesClient());
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
    await tester.enterText(fields.at(2), 'Calle Ruiz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(maps.searches, ['Calle Ruiz']);
    await tester.tap(find.text('Caguas, Puerto Rico'));
    await tester.pumpAndSettle();
    // El pueblo se llena solo con lo que dice Google Maps.
    expect(find.text('Tomado de la dirección en Google Maps'), findsOneWidget);
    await tester.enterText(fields.at(3), '787 555 1234');
    await tester.enterText(fields.at(4), 'ana@elpatio.com');
    await tester.enterText(fields.at(5), 'secreto1');
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
    expect(state.account?.address, 'Calle Ruiz Belvis 10, Caguas, 00725');
    expect(state.account?.town, 'Caguas');
    expect(state.account?.lat, 18.23);
    expect(find.text('Puerto Rico'), findsOneWidget);
    await tester.tap(find.text('Sofía Rivera'));
    await tester.pumpAndSettle();
    expect(find.text('Precios del artista'), findsOneWidget);
  });

  testWidgets('Un cliente privado escoge su pueblo de la lista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(
      AppScope(state: state, child: const BookingArtistApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiero contratar'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Carmen Díaz');
    await tester.enterText(fields.at(1), '787 555 4321');
    await tester.enterText(fields.at(2), 'carmen@example.com');
    await tester.enterText(fields.at(3), 'secreto1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(state.account, isNull);
    expect(find.text('Escoge tu pueblo'), findsOneWidget);

    await tester.tap(find.text('Pueblo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añasco').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(state.account?.town, 'Añasco');
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
