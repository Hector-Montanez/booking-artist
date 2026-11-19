import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../availability.dart';
import '../models.dart';
import '../widgets/common.dart';

/// Calendario del artista: cada día con actividades lleva puntos de color
/// (verde confirmada, amarillo esperando respuesta). Al tocar un día se ven
/// sus actividades abajo.
///
/// El cliente (quien contrata) ve el mismo calendario con las actividades que
/// reservó.
class ArtistCalendarScreen extends StatefulWidget {
  const ArtistCalendarScreen({super.key, this.forClient = false});

  final bool forClient;

  @override
  State<ArtistCalendarScreen> createState() => _ArtistCalendarScreenState();
}

class _ArtistCalendarScreenState extends State<ArtistCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  void _moveMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() => setState(() {
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dayOnly(now);
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final client = widget.forClient;
    final me = client ? null : state.myArtistProfile;
    final daysOff = me?.daysOff ?? const <DateTime>{};
    final theme = Theme.of(context);

    // Solo las actividades vivas: las rechazadas, canceladas o sin pagar no
    // ocupan el calendario.
    final byDay = <DateTime, List<Booking>>{};
    for (final b in client ? state.myClientBookings : state.bookings) {
      // El artista ve las fechas de todos sus perfiles.
      if ((!client && !state.isMine(b.artist)) || !b.blocksSchedule) continue;
      if (b.payment == PaymentStatus.porPagar) continue;
      byDay.putIfAbsent(dayOnly(b.date), () => []).add(b);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    final inMonth = byDay.entries
        .where((e) => e.key.year == _month.year && e.key.month == _month.month)
        .expand((e) => e.value)
        .toList();
    final confirmed = inMonth
        .where((b) => b.status == BookingStatus.confirmada)
        .length;
    final pending = inMonth.length - confirmed;
    final dayList = byDay[_selected] ?? const <Booking>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi calendario'),
        actions: [TextButton(onPressed: _goToday, child: const Text('Hoy'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _moveMonth(-1),
              ),
              Expanded(
                child: Text(
                  _capitalize(DateFormat.yMMMM('es').format(_month)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _moveMonth(1),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              inMonth.isEmpty
                  ? 'Sin actividades este mes'
                  : '$confirmed confirmadas · $pending esperando respuesta',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          _MonthGrid(
            month: _month,
            selected: _selected,
            byDay: byDay,
            daysOff: daysOff,
            onTap: (d) => setState(() => _selected = d),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              const _Legend(color: Color(0xFF2E7D32), text: 'Confirmada'),
              const _Legend(
                color: Color(0xFFF9A825),
                text: 'Esperando respuesta',
              ),
              if (!client)
                const _Legend(
                  color: Colors.grey,
                  text: 'Día libre',
                  outline: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _capitalize(DateFormat.yMMMMEEEEd('es').format(_selected)),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (dayList.isEmpty)
            Text(
              daysOff.contains(_selected)
                  ? 'Día libre: no recibes reservas este día.'
                  : 'No tienes actividades este día.',
            ),
          for (final b in dayList) _EventCard(booking: b, forClient: client),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.daysOff,
    required this.onTap,
  });

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<Booking>> byDay;
  final Set<DateTime> daysOff;
  final ValueChanged<DateTime> onTap;

  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dayOnly(DateTime.now());
    // La semana empieza el lunes.
    final first = DateTime(month.year, month.month);
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells ~/ 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final n = row * 7 + col - leading + 1;
                      if (n < 1 || n > daysInMonth) {
                        return const SizedBox(height: 52);
                      }
                      final day = DateTime(month.year, month.month, n);
                      return _DayCell(
                        day: day,
                        bookings: byDay[day] ?? const [],
                        isToday: day == today,
                        isSelected: day == selected,
                        isOff: daysOff.contains(day),
                        onTap: () => onTap(day),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.bookings,
    required this.isToday,
    required this.isSelected,
    required this.isOff,
    required this.onTap,
  });

  final DateTime day;
  final List<Booking> bookings;
  final bool isToday;
  final bool isSelected;
  final bool isOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasConfirmed = bookings.any(
      (b) => b.status == BookingStatus.confirmada,
    );
    final fill = isSelected
        ? scheme.primary
        : hasConfirmed
        ? const Color(0xFF2E7D32).withValues(alpha: 0.18)
        : bookings.isNotEmpty
        ? const Color(0xFFF9A825).withValues(alpha: 0.18)
        : null;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fill ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isToday && !isSelected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : isOff
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: bookings.isNotEmpty || isToday
                        ? FontWeight.bold
                        : null,
                    color: isSelected
                        ? scheme.onPrimary
                        : isOff
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                        : null,
                    decoration: isOff ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final b in bookings.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? scheme.onPrimary : b.status.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.text,
    this.outline = false,
  });

  final Color color;
  final String text;
  final bool outline;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: outline ? null : color,
          border: outline ? Border.all(color: color) : null,
        ),
      ),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.booking, this.forClient = false});

  final Booking booking;

  /// El cliente ve el artista que contrató; el artista ve quién lo contrató.
  final bool forClient;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final end = b.end;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: b.status.color, width: 5)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(b.eventType.icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${b.time.format(context)} a '
                    '${TimeOfDay.fromDateTime(end).format(context)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  b.status.label,
                  style: TextStyle(
                    color: b.status.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${forClient ? b.artist.name : b.clientName} · '
              '${b.eventType.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            // Con varios perfiles, el artista ve con cuál toca.
            Text(forClient || !b.isQuote ? b.package : b.artist.name),
            Row(
              children: [
                const Icon(Icons.place, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(b.venue)),
              ],
            ),
            if (b.notes.isNotEmpty) Text('Notas: ${b.notes}'),
            const SizedBox(height: 4),
            Text(
              money(b.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
