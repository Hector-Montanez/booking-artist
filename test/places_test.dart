import 'package:booking_artist/places.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Los 78 municipios', () {
    expect(municipios.length, 78);
    expect(municipios.toSet().length, 78);
  });

  test('Reconoce el pueblo con o sin acentos', () {
    expect(matchMunicipio('mayaguez'), 'Mayagüez');
    expect(matchMunicipio('  San  Juan '), 'San Juan');
    expect(matchMunicipio('Loiza'), 'Loíza');
    expect(matchMunicipio('Levittown'), isNull);
    expect(matchMunicipio(null), isNull);
  });
}
