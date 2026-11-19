import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'cloud.dart' show apiUri;

/// Los 78 municipios de Puerto Rico.
const municipios = [
  'Adjuntas', 'Aguada', 'Aguadilla', 'Aguas Buenas', 'Aibonito', 'Añasco', //
  'Arecibo', 'Arroyo', 'Barceloneta', 'Barranquitas', 'Bayamón', 'Cabo Rojo',
  'Caguas', 'Camuy', 'Canóvanas', 'Carolina', 'Cataño', 'Cayey', 'Ceiba',
  'Ciales', 'Cidra', 'Coamo', 'Comerío', 'Corozal', 'Culebra', 'Dorado',
  'Fajardo', 'Florida', 'Guánica', 'Guayama', 'Guayanilla', 'Guaynabo',
  'Gurabo', 'Hatillo', 'Hormigueros', 'Humacao', 'Isabela', 'Jayuya',
  'Juana Díaz', 'Juncos', 'Lajas', 'Lares', 'Las Marías', 'Las Piedras',
  'Loíza', 'Luquillo', 'Manatí', 'Maricao', 'Maunabo', 'Mayagüez', 'Moca',
  'Morovis', 'Naguabo', 'Naranjito', 'Orocovis', 'Patillas', 'Peñuelas',
  'Ponce', 'Quebradillas', 'Rincón', 'Río Grande', 'Sabana Grande', 'Salinas',
  'San Germán', 'San Juan', 'San Lorenzo', 'San Sebastián', 'Santa Isabel',
  'Toa Alta', 'Toa Baja', 'Trujillo Alto', 'Utuado', 'Vega Alta', 'Vega Baja',
  'Vieques', 'Villalba', 'Yabucoa', 'Yauco',
];

String _plain(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Devuelve el municipio con su ortografía oficial ("mayaguez" → "Mayagüez"),
/// o null si el texto no es un municipio de Puerto Rico.
String? matchMunicipio(String? text) {
  if (text == null) return null;
  final t = _plain(text);
  for (final m in municipios) {
    if (_plain(m) == t) return m;
  }
  return null;
}

/// Una sugerencia de Google Maps mientras se escribe la dirección.
class PlaceSuggestion {
  const PlaceSuggestion(this.id, this.main, this.secondary);
  final String id;
  final String main;
  final String secondary;
}

/// La dirección escogida, con el pueblo que sacó el servidor.
class PlaceDetails {
  const PlaceDetails({
    required this.address,
    this.town,
    this.inPR = true,
    this.lat,
    this.lng,
  });
  final String address;
  final String? town;
  final bool inPR;
  final double? lat;
  final double? lng;
}

/// Habla con /api/places (Google Maps desde el servidor). Se puede cambiar
/// en las pruebas por una versión simulada.
class PlacesClient {
  static PlacesClient instance = PlacesClient();

  bool? _ready;

  /// El servidor tiene la llave de Google Maps.
  Future<bool> ready() async {
    if (_ready != null) return _ready!;
    try {
      final r = await http.get(apiUri('/api/places'));
      _ready = r.statusCode == 200 && jsonDecode(r.body)['ready'] == true;
    } catch (_) {
      _ready = false;
    }
    return _ready!;
  }

  /// Agrupa las búsquedas y la dirección escogida en una sola sesión, que
  /// Google cobra como una sola búsqueda.
  static String newSession() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<List<PlaceSuggestion>> search(String text, String session) async {
    final r = await http.get(
      apiUri('/api/places')
          .replace(queryParameters: {'q': text, 'session': session}),
    );
    if (r.statusCode != 200) return const [];
    final list = (jsonDecode(r.body)['suggestions'] as List?) ?? const [];
    return [
      for (final s in list)
        PlaceSuggestion(
          s['id'] as String,
          (s['main'] ?? '') as String,
          (s['secondary'] ?? '') as String,
        ),
    ];
  }

  Future<PlaceDetails?> details(String id, String session) async {
    final r = await http.get(
      apiUri('/api/places')
          .replace(queryParameters: {'id': id, 'session': session}),
    );
    if (r.statusCode != 200) return null;
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return PlaceDetails(
      address: (d['address'] ?? '') as String,
      town: matchMunicipio(d['town'] as String?),
      inPR: d['inPR'] != false,
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
    );
  }
}
