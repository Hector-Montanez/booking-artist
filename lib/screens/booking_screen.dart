import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../availability.dart';
import '../models.dart';
import '../widgets/common.dart';

/// El cliente pide cotización: cuenta qué evento es, la fecha, la hora, el
/// lugar y los detalles. El artista responde con su precio y el cliente lo
/// acepta para reservar. Nada se paga por la app.
class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({super.key, required this.artist});

  final Artist artist;

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final _form = GlobalKey<FormState>();
  late EventType _eventType = _defaultEventType();
  double _hours = 2;
  DateTime? _date;
  TimeOfDay? _time;
  bool _accepted = false;
  bool _sending = false;

  // Se llenan con los datos de la cuenta; el cliente puede cambiarlos.
  late final Account? _account = AppScope.of(context).account;
  late final _venue = TextEditingController(
    text: _account?.clientType == ClientType.restaurante
        ? [
            _account!.businessName,
            _account.address,
            _account.town,
          ].where((s) => s.isNotEmpty).join(', ')
        : _account?.town ?? '',
  );
  late final _name = TextEditingController(text: _account?.displayName);
  final _notes = TextEditingController();

  static const _durations = [1.0, 2.0, 3.0, 4.0, 5.0];

  List<EventType> get _eventTypes {
    final types = widget.artist.eventTypes.toList();
    return types.isEmpty ? EventType.values : types;
  }

  EventType _defaultEventType() {
    final types = _eventTypes;
    final preferred = switch (AppScope.of(context).account?.clientType) {
      ClientType.restaurante => EventType.restaurante,
      ClientType.agrupacion => EventType.conAgrupacion,
      _ => null,
    };
    return types.contains(preferred) ? preferred! : types.first;
  }

  @override
  void dispose() {
    _venue.dispose();
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artist = widget.artist;
    final dateFmt = DateFormat.yMMMMEEEEd('es');

    return Scaffold(
      appBar: AppBar(title: Text('Cotizar con ${artist.name}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Cuéntale a ${artist.name} de tu evento. Te responde con '
                  'su precio aquí en la app y, si te gusta, lo aceptas para '
                  'reservar la fecha. No pagas nada por la app.',
                ),
              ),
            ),
            const _StepTitle(1, '¿Qué evento es?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _eventTypes)
                  ChoiceChip(
                    avatar: Icon(e.icon, size: 18),
                    label: Text(e.label),
                    selected: _eventType == e,
                    onSelected: (_) => setState(() => _eventType = e),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('¿Cuántas horas?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in _durations)
                  ChoiceChip(
                    label: Text('${h.toInt()} h'),
                    selected: _hours == h,
                    onSelected: (_) => setState(() {
                      _hours = h;
                      // Un evento más largo puede no caber en la hora elegida.
                      if (_date != null && !_slots(_date!).contains(_time)) {
                        _time = null;
                      }
                    }),
                  ),
              ],
            ),
            const _StepTitle(2, 'Fecha, hora y lugar'),
            Text(
              'Solo ves los días y horas en que ${artist.name} está disponible.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _date == null ? 'Elegir fecha' : dateFmt.format(_date!),
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: _pickDate,
            ),
            if (_date != null) ...[
              const SizedBox(height: 12),
              Text('Horas disponibles', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _slots(_date!))
                    ChoiceChip(
                      label: Text(t.format(context)),
                      selected: _time == t,
                      onSelected: (_) => setState(() => _time = t),
                    ),
                ],
              ),
              if (_time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'De ${_time!.format(context)} a '
                    '${formatMinutes(context, _time!.hour * 60 + _time!.minute + _duration)}',
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(
                labelText: 'Lugar y pueblo del evento',
                hintText: 'Ej. Salón Los Robles, Caguas',
                prefixIcon: Icon(Icons.place),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Tu nombre o negocio',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalles del evento (opcional)',
                hintText:
                    'Número de invitados, canciones especiales, '
                    'si hay sonido en el lugar…',
                border: OutlineInputBorder(),
              ),
            ),
            const _StepTitle(3, 'Condiciones del artista'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(artist.conditions),
              ),
            ),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Acepto las condiciones del artista'),
            ),
            if (artist.hasWhatsapp) ...[
              const SizedBox(height: 4),
              Text(
                '¿Prefieres hablarlo primero? Escríbele por WhatsApp y luego '
                'envía la solicitud con lo que acuerden.',
                style: theme.textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: WhatsAppButton(
                  artist: artist,
                  message: _whatsappMessage(),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.send),
            onPressed: _sending ? null : _send,
            label: const Text('Pedir cotización'),
          ),
        ),
      ),
    );
  }

  /// Mensaje para WhatsApp con lo que el cliente ya escogió.
  String _whatsappMessage() {
    final date = _date == null
        ? ''
        : ' el ${DateFormat.yMMMMEEEEd('es').format(_date!)}';
    return quoteWhatsappText(
      artist: widget.artist,
      eventType: _eventType,
      when: date,
      place: _venue.text.trim(),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null;

  int get _duration => (_hours * 60).round();

  List<TimeOfDay> _slots(DateTime day) => availableStarts(
    artist: widget.artist,
    bookings: AppScope.of(context).bookings,
    day: day,
    durationMinutes: _duration,
  );

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final last = today.add(const Duration(days: 365));
    bool available(DateTime d) => _slots(d).isNotEmpty;

    var first = _date;
    for (var d = today; first == null && !d.isAfter(last);) {
      if (available(d)) first = d;
      d = d.add(const Duration(days: 1));
    }
    if (first == null) {
      return _snack(
        '${widget.artist.name} no tiene fechas disponibles en el próximo año '
        'para un evento de ${_hours.toInt()} horas. Escríbele para '
        'preguntarle.',
      );
    }
    final d = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: today,
      lastDate: last,
      selectableDayPredicate: available,
      helpText: 'Días disponibles',
    );
    if (d != null) {
      setState(() {
        _date = d;
        if (!_slots(d).contains(_time)) _time = null;
      });
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (_date == null) return _snack('Elige la fecha del evento');
    if (_time == null || !_slots(_date!).contains(_time)) {
      setState(() => _time = null);
      return _snack('Escoge una hora disponible');
    }
    if (!_accepted) return _snack('Acepta las condiciones del artista');

    final state = AppScope.of(context);
    final booking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      artist: widget.artist,
      eventType: _eventType,
      date: _date!,
      time: _time!,
      hours: _hours,
      venue: _venue.text.trim(),
      clientName: _name.text.trim(),
      clientType: _account?.clientType ?? ClientType.privado,
      clientEmail: _account?.email ?? '',
      clientUid: state.uid,
      notes: _notes.text.trim(),
      total: 0,
      amountCharged: 0,
      payDeposit: false,
      noDeposit: true,
      paymentMethod: PaymentMethod.ninguno,
      cardLast4: '',
    );
    setState(() => _sending = true);
    final error = await state.requestQuote(booking);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) return _snack(error);
    await showRequestSentDialog(context, booking);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Confirma que la solicitud de cotización se envió.
Future<void> showRequestSentDialog(BuildContext context, Booking b) {
  final name = b.artist.name;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: const Text('¡Solicitud enviada!'),
      content: Text(
        'Le avisamos a $name por notificación y por email. Cuando te envíe '
        'su precio lo verás en "Reservas" y ahí lo aceptas para reservar la '
        'fecha. No pagas nada por la app: el pago se arregla directo con '
        '$name.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Listo'),
        ),
      ],
    ),
  );
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: scheme.primary,
            child: Text(
              '$number',
              style: TextStyle(color: scheme.onPrimary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
