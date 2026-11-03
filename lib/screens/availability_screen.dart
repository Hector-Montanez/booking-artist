import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../availability.dart';
import '../models.dart';

/// El artista define qué días y horas trabaja, sus días libres y ve lo que ya
/// tiene reservado.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final AppState _state = AppScope.of(context);
  late final Artist _me = _state.myArtistProfile;

  void _update(VoidCallback change) {
    setState(change);
    _state.artistUpdated();
  }

  Future<int?> _pickTime(int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _editStart(int day) async {
    final h = _me.weeklyHours[day]!;
    final m = await _pickTime(h.start);
    if (m == null) return;
    if (m >= h.end) {
      return _snack('La hora de inicio debe ser antes del cierre');
    }
    _update(() => _me.weeklyHours[day] = DayHours(m, h.end));
  }

  Future<void> _editEnd(int day) async {
    final h = _me.weeklyHours[day]!;
    var m = await _pickTime(h.end);
    if (m == null) return;
    // Las 12:00 de la medianoche cierran el día.
    if (m == 0) m = 24 * 60;
    if (m <= h.start) {
      return _snack('La hora de cierre debe ser después del inicio');
    }
    _update(() => _me.weeklyHours[day] = DayHours(h.start, m!));
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addDayOff() async {
    final today = dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Día libre',
    );
    if (d != null) _update(() => _me.daysOff.add(dayOnly(d)));
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMEd('es');
    final now = DateTime.now();
    final upcoming =
        _state.bookings
            .where(
              (b) => b.artist == _me && b.blocksSchedule && b.end.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final daysOff = _me.daysOff.where((d) => !d.isBefore(dayOnly(now))).toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi disponibilidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Los clientes solo pueden reservarte en estos días y horas. '
            'Lo que ya tienes reservado se bloquea solo.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Horario semanal', style: theme.textTheme.titleMedium),
          for (final day in weekdayNames.keys)
            _DayRow(
              name: weekdayNames[day]!,
              hours: _me.weeklyHours[day],
              onToggle: (on) => _update(() {
                if (on) {
                  _me.weeklyHours[day] = const DayHours(18 * 60, 23 * 60);
                } else {
                  _me.weeklyHours.remove(day);
                }
              }),
              onStart: () => _editStart(day),
              onEnd: () => _editEnd(day),
            ),
          const SizedBox(height: 16),
          Text('Tiempo entre eventos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Para trasladarte y montar el equipo. Se deja antes y después de '
            'cada reserva.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final m in const [0, 30, 60, 90, 120])
                ChoiceChip(
                  label: Text(
                    m == 0
                        ? 'Nada'
                        : '${m ~/ 60 > 0 ? '${m ~/ 60} h ' : ''}${m % 60 > 0 ? '${m % 60} min' : ''}'
                              .trim(),
                  ),
                  selected: _me.bufferMinutes == m,
                  onSelected: (_) => _update(() => _me.bufferMinutes = m),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Días libres', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _addDayOff,
                icon: const Icon(Icons.event_busy),
                label: const Text('Añadir'),
              ),
            ],
          ),
          if (daysOff.isEmpty)
            const Text('Vacaciones o días que no puedes tocar.'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in daysOff)
                InputChip(
                  label: Text(dateFmt.format(d)),
                  onDeleted: () => _update(() => _me.daysOff.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Ya reservado', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (upcoming.isEmpty) const Text('Todavía no tienes eventos.'),
          for (final b in upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: b.status.color),
              title: Text(
                '${dateFmt.format(b.date)} · '
                '${b.time.format(context)} a '
                '${TimeOfDay.fromDateTime(b.end).format(context)}',
              ),
              subtitle: Text('${b.clientName} · ${b.status.label}'),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.name,
    required this.hours,
    required this.onToggle,
    required this.onStart,
    required this.onEnd,
  });

  final String name;
  final DayHours? hours;
  final ValueChanged<bool> onToggle;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final h = hours;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Switch(value: h != null, onChanged: onToggle),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Text(name)),
          Expanded(
            child: h == null
                ? Text(
                    'No disponible',
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  )
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: onStart,
                        child: Text(formatMinutes(context, h.start)),
                      ),
                      const Text('a'),
                      TextButton(
                        onPressed: onEnd,
                        child: Text(formatMinutes(context, h.end)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
