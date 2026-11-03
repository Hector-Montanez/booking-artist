import 'dart:typed_data';

import 'package:booking_artist/cloud.dart';
import 'package:booking_artist/data/mock_artists.dart';
import 'package:booking_artist/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la página del artista se guarda y se recupera igual', () {
    final a = buildMockArtists().firstWhere((a) => a.id == 'p1')
      ..photo = Uint8List.fromList([1, 2, 3])
      ..daysOff.add(DateTime(2026, 12, 24));
    a.gallery.add(Uint8List.fromList([4, 5]));

    final b = artistFromMap(a.id, artistToMap(a));
    expect(b.name, a.name);
    expect(b.category, ArtistCategory.payaso);
    expect(b.packages.map((p) => p.price), a.packages.map((p) => p.price));
    expect(b.links.length, a.links.length);
    expect(b.weeklyHours.keys, a.weeklyHours.keys);
    expect(b.weeklyHours[6]!.end, a.weeklyHours[6]!.end);
    expect(b.daysOff, contains(DateTime(2026, 12, 24)));
    expect(b.photo, [1, 2, 3]);
    expect(b.gallery.single, [4, 5]);
    expect(b.color.toARGB32(), a.color.toARGB32());
    expect(b.eventTypes, a.eventTypes);
  });

  test('fotos que no caben no rompen el documento', () {
    final a = buildMockArtists().first..photo = Uint8List(500000);
    a.gallery.add(Uint8List(500000));
    final map = artistToMap(a);
    expect(map['photo'], isNotNull);
    expect(map['gallery'], isEmpty);
  });
}
