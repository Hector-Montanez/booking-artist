import 'package:booking_artist/cloud.dart';
import 'package:booking_artist/models.dart';
import 'package:booking_artist/places.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hay 78 pueblos', () {
    expect(municipios.length, 78);
    expect(municipios.toSet().length, 78);
  });

  test('Cuentas viejas: el cliente conserva un pueblo real escrito a mano', () {
    final a = accountFromMap({
      'role': 'cliente',
      'name': 'Ana',
      'town': ' mayaguez ',
    }, null);
    expect(a.town, 'Mayagüez');
    final b = accountFromMap({
      'role': 'cliente',
      'name': 'Ana',
      'town': 'Mi casa',
    }, null);
    expect(b.town, '');
  });

  test('Artista viejo sin pueblo queda sin pueblo; el nuevo lo guarda', () {
    final old = artistFromMap('x', {'name': 'Viejo', 'zone': 'Caguas'});
    expect(old.zone, '');
    final acc = accountFromMap({'role': 'artista', 'town': 'Caguas'}, old);
    expect(acc.town, '');

    old.zone = 'Ponce';
    final saved = artistToMap(old);
    expect(saved['pueblo'], 'Ponce');
    expect(artistFromMap('x', saved).zone, 'Ponce');
    final withTown = accountToMap(
      Account(
        role: UserRole.cliente,
        name: 'N',
        email: 'n@x.com',
        phone: '',
        town: 'Ponce',
      ),
    );
    expect(withTown['pueblo'], 'Ponce');
  });
}
