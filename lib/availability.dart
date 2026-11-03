import 'package:flutter/material.dart';

import 'models.dart';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatMinutes(BuildContext context, int minutes) {
  if (minutes >= 24 * 60) return 'medianoche';
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
}

/// Horas en que el cliente puede empezar un evento de [durationMinutes] con
/// [artist] el día [day]. Respeta el horario semanal, los días libres y las
/// reservas pendientes o confirmadas (más el tiempo de traslado).
List<TimeOfDay> availableStarts({
  required Artist artist,
  required List<Booking> bookings,
  required DateTime day,
  required int durationMinutes,
  DateTime? now,
  int stepMinutes = 30,
}) {
  final date = dayOnly(day);
  if (artist.daysOff.contains(date)) return [];
  final hours = artist.weeklyHours[date.weekday];
  if (hours == null) return [];

  final current = now ?? DateTime.now();
  final buffer = Duration(minutes: artist.bufferMinutes);
  final busy = bookings
      .where((b) => b.artist == artist && b.blocksSchedule)
      .map((b) => (b.start, b.end))
      .followedBy(artist.busy)
      .map((r) => (r.$1.subtract(buffer), r.$2.add(buffer)))
      .toList();

  final result = <TimeOfDay>[];
  for (
    var m = hours.start;
    m + durationMinutes <= hours.end;
    m += stepMinutes
  ) {
    final start = date.add(Duration(minutes: m));
    final end = start.add(Duration(minutes: durationMinutes));
    if (!start.isAfter(current)) continue;
    final overlaps = busy.any((r) => start.isBefore(r.$2) && end.isAfter(r.$1));
    if (!overlaps) result.add(TimeOfDay(hour: m ~/ 60, minute: m % 60));
  }
  return result;
}
