import 'package:booking_artist/availability.dart';
import 'package:booking_artist/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Artist _artist() => Artist(
  id: 'x',
  name: 'Prueba',
  category: ArtistCategory.solista,
  genres: [],
  bio: '',
  zone: 'Caguas',
  distanceKm: 1,
  rating: 0,
  reviews: 0,
  color: Colors.purple,
  packages: [PricePackage(name: 'Show', price: 100, hours: 2)],
  links: [],
  eventTypes: {EventType.boda},
  weeklyHours: {6: const DayHours(18 * 60, 24 * 60)}, // sábados 6 p. m. a 12
  bufferMinutes: 60,
);

Booking _booked(Artist a, DateTime day, int hour, BookingStatus status) =>
    Booking(
      id: '1',
      artist: a,
      package: 'Show',
      eventType: EventType.boda,
      date: day,
      time: TimeOfDay(hour: hour, minute: 0),
      venue: 'Caguas',
      clientName: 'Otro cliente',
      notes: '',
      total: 108,
      amountCharged: 32,
      payDeposit: true,
      cardLast4: '4242',
      status: status,
      hours: 2,
    );

void main() {
  final saturday = DateTime(2030, 6, 1); // sábado
  final friday = DateTime(2030, 5, 31);
  final now = DateTime(2030, 5, 1);
  String fmt(List<TimeOfDay> l) => l
      .map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}')
      .join(' ');

  test('solo ofrece horas dentro del horario del artista', () {
    final a = _artist();
    final slots = availableStarts(
      artist: a,
      bookings: [],
      day: saturday,
      durationMinutes: 120,
      now: now,
    );
    expect(fmt(slots), '18:00 18:30 19:00 19:30 20:00 20:30 21:00 21:30 22:00');
    expect(
      availableStarts(
        artist: a,
        bookings: [],
        day: friday,
        durationMinutes: 120,
        now: now,
      ),
      isEmpty,
    );
  });

  test('una reserva bloquea su horario más el tiempo de traslado', () {
    final a = _artist();
    // Evento de 8 a 10 p. m.: con 1 h de traslado queda ocupado de 7 a 11.
    final slots = availableStarts(
      artist: a,
      bookings: [_booked(a, saturday, 20, BookingStatus.confirmada)],
      day: saturday,
      durationMinutes: 60,
      now: now,
    );
    expect(fmt(slots), '18:00 23:00');

    // Una reserva rechazada libera el horario.
    final freed = availableStarts(
      artist: a,
      bookings: [_booked(a, saturday, 20, BookingStatus.rechazada)],
      day: saturday,
      durationMinutes: 60,
      now: now,
    );
    expect(freed.length, 11);
  });

  test('un día libre no tiene horas', () {
    final a = _artist()..daysOff.add(saturday);
    expect(
      availableStarts(
        artist: a,
        bookings: [],
        day: saturday,
        durationMinutes: 60,
        now: now,
      ),
      isEmpty,
    );
  });
}
