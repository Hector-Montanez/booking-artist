import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../availability.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.artist, this.initialPackage});

  final Artist artist;
  final PricePackage? initialPackage;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _form = GlobalKey<FormState>();
  late PricePackage _package = widget.initialPackage ?? _defaultPackage();
  late EventType _eventType = _defaultEventType();
  DateTime? _date;
  TimeOfDay? _time;
  bool _accepted = false;
  bool _payDeposit = true;
  bool _sending = false;

  // Se llenan con los datos de la cuenta; el cliente puede cambiarlos.
  late final Account? _account = AppScope.of(context).account;
  late final _venue = TextEditingController(
    text: _account?.clientType == ClientType.restaurante
        ? [
            _account!.businessName,
            _account.address,
          ].where((s) => s.isNotEmpty).join(', ')
        : '',
  );
  late final _name = TextEditingController(text: _account?.displayName);
  final _notes = TextEditingController();

  /// Tarifa de servicio de la plataforma. El servidor de pagos usa la misma
  /// (FEE_RATE en Vercel) y es el que decide el monto final.
  static const _feeRate = 0.10;

  /// Un restaurante empieza con un paquete de restaurante, si el artista
  /// tiene uno.
  PricePackage _defaultPackage() {
    final packages = widget.artist.packages;
    if (AppScope.of(context).account?.clientType == ClientType.restaurante) {
      return packages.where((p) => !p.takesDeposit).firstOrNull ??
          packages.first;
    }
    return packages.first;
  }

  /// Paquete de restaurante: sin depósito, solo la reserva.
  bool get _noDeposit => !_package.takesDeposit;

  /// Tipos de evento que van con el paquete: los de restaurante son para
  /// restaurantes; los de actividades, para todo lo demás.
  List<EventType> get _eventTypes {
    if (_noDeposit) return const [EventType.restaurante];
    final types = widget.artist.eventTypes
        .where((e) => e != EventType.restaurante)
        .toList();
    return types.isEmpty ? const [EventType.actividad] : types;
  }

  EventType _defaultEventType() {
    final types = _eventTypes;
    final account = AppScope.of(context).account;
    final preferred = switch (account?.clientType) {
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
    // Sin depósito no se cobra nada por la app, ni la tarifa de servicio.
    final noDeposit = _noDeposit;
    final total = noDeposit
        ? _package.price
        : ((_package.price * (1 + _feeRate)) * 100).round() / 100;
    final fee = total - _package.price;
    final deposit = (total * artist.depositPercent / 100).roundToDouble();
    final dueNow = noDeposit ? 0.0 : (_payDeposit ? deposit : total);
    final dateFmt = DateFormat.yMMMMEEEEd('es');

    return Scaffold(
      appBar: AppBar(title: Text('Reservar a ${artist.name}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepTitle(1, 'Escoge el paquete'),
            RadioGroup<PricePackage>(
              groupValue: _package,
              onChanged: (v) => setState(() {
                _package = v!;
                if (!_eventTypes.contains(_eventType)) {
                  _eventType = _eventTypes.first;
                }
                // Un paquete más largo puede no caber en la hora elegida.
                if (_date != null && !_slots(_date!).contains(_time)) {
                  _time = null;
                }
              }),
              child: Column(
                children: [
                  for (final p in artist.packages)
                    RadioListTile<PricePackage>(
                      value: p,
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.hours} h · ${p.takesDeposit ? 'Actividad, con depósito' : 'Restaurante, sin depósito'}',
                      ),
                      secondary: Text(
                        money(p.price),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
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
            _StepTitle(2, 'Fecha, hora y lugar'),
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
                labelText: 'Lugar del evento',
                hintText: 'Ej. Restaurante El Patio, San Juan',
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
                labelText: 'Notas para el artista (opcional)',
                hintText: 'Canciones especiales, número de invitados…',
                border: OutlineInputBorder(),
              ),
            ),
            _StepTitle(3, 'Condiciones del artista'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noDeposit
                          ? 'Paquete de restaurante: sin depósito'
                          : 'Depósito para reservar: ${artist.depositPercent}%',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(artist.conditions),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Acepto las condiciones del artista'),
            ),
            if (noDeposit) ...[
              _StepTitle(4, 'Sin depósito'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Precio del artista', money(_package.price)),
                      const Divider(),
                      _row('A pagar ahora', money(0), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los paquetes de restaurante no llevan depósito: solo reservas '
                'la fecha. El pago se arregla directo con ${artist.name}.',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              _StepTitle(4, '¿Cuánto pagas ahora?'),
              RadioGroup<bool>(
                groupValue: _payDeposit,
                onChanged: (v) => setState(() => _payDeposit = v!),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      title: Text('Depósito del ${artist.depositPercent}%'),
                      subtitle: Text(
                        'El resto (${money(total - deposit)}) se paga por la app '
                        'el día del evento.',
                      ),
                      secondary: Text(
                        money(deposit),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      title: const Text('Pago completo'),
                      secondary: Text(
                        money(total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Precio del artista', money(_package.price)),
                      _row(
                        'Tarifa de servicio (${(_feeRate * 100).round()}%)',
                        money(fee),
                      ),
                      _row('Total del evento', money(total)),
                      const Divider(),
                      _row('A pagar ahora', money(dueNow), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pagas con tarjeta o ATH Móvil. Con tarjeta no se cobra nada '
                'hasta que ${artist.name} acepte; con ATH Móvil, si rechaza, te '
                'devolvemos el dinero.',
                style: theme.textTheme.bodySmall,
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
            icon: Icon(noDeposit ? Icons.send : Icons.lock),
            onPressed: _sending
                ? null
                : () => _continueToPayment(total, dueNow),
            label: Text(
              noDeposit
                  ? 'Enviar solicitud'
                  : 'Continuar al pago · ${money(dueNow)}',
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(l, style: style)),
          Text(v, style: style),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null;

  int get _duration => (_package.hours * 60).round();

  List<TimeOfDay> _slots(DateTime day) => availableStarts(
    artist: widget.artist,
    bookings: AppScope.of(context).bookings,
    day: day,
    durationMinutes: _duration,
  );

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final last = today.add(const Duration(days: 180));
    bool available(DateTime d) => _slots(d).isNotEmpty;

    var first = _date;
    for (var d = today; first == null && !d.isAfter(last);) {
      if (available(d)) first = d;
      d = d.add(const Duration(days: 1));
    }
    if (first == null) {
      return _snack(
        '${widget.artist.name} no tiene fechas disponibles en los próximos '
        '6 meses para este paquete.',
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

  Future<void> _continueToPayment(double total, double dueNow) async {
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
      package: _package.name,
      eventType: _eventType,
      date: _date!,
      time: _time!,
      hours: _package.hours,
      venue: _venue.text.trim(),
      clientName: _name.text.trim(),
      clientType: _account?.clientType ?? ClientType.privado,
      clientEmail: _account?.email ?? '',
      clientUid: state.uid,
      notes: _notes.text.trim(),
      total: total,
      amountCharged: dueNow,
      payDeposit: !_noDeposit && _payDeposit,
      noDeposit: _noDeposit,
      paymentMethod: _noDeposit ? PaymentMethod.ninguno : PaymentMethod.tarjeta,
      cardLast4: '',
    );

    if (_noDeposit) {
      // Paquete de restaurante: no hay pago, solo la solicitud.
      String? error;
      if (state.serverPayments) {
        setState(() => _sending = true);
        error = await state.bookWithoutDeposit(booking);
        if (!mounted) return;
        setState(() => _sending = false);
        if (error == null) state.notifyArtist(booking);
      } else {
        state.addBooking(booking);
      }
      if (error != null) return _snack(error);
      await showPaidDialog(context, booking);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    // Con cobro real la reserva se guarda primero (sin pagar) y el servidor
    // la marca como pagada.
    final live = state.serverPayments;
    if (live) {
      try {
        await state.createUnpaidBooking(booking);
      } catch (_) {
        return _snack('No se pudo guardar la reserva. Intenta otra vez.');
      }
      if (!mounted) return;
    }
    final paid = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          amount: dueNow,
          concept: '${_package.name} · ${widget.artist.name}',
          booking: live ? booking : null,
          phone: _account?.phone ?? '',
        ),
      ),
    );
    if (paid == null) {
      // Se fue sin pagar: la reserva no sigue.
      if (live) unawaited(state.cancelBooking(booking));
      return;
    }
    if (!mounted) return;
    booking
      ..paymentMethod = paid.method
      ..cardLast4 = paid.last4;
    if (live) {
      state.notifyArtist(booking);
    } else {
      state.addBooking(booking);
    }
    await showPaidDialog(context, booking);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Confirma que la solicitud se envió y cómo quedó el pago.
Future<void> showPaidDialog(BuildContext context, Booking b) {
  final amount = money(b.amountCharged);
  final name = b.artist.name;
  final how = b.noDeposit
      ? 'No pagaste nada: es un paquete de restaurante, sin depósito. El pago '
            'se arregla directo con $name.'
      : b.paymentMethod == PaymentMethod.ath
      ? 'Pagaste $amount con ATH Móvil. Si $name no acepta, te devolvemos el '
            'dinero.'
      : 'Retuvimos $amount en tu tarjeta${b.cardLast4.isEmpty ? '' : ' terminada en ${b.cardLast4}'}. '
            'Se cobra solo si $name acepta.';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: const Text('¡Solicitud enviada!'),
      content: Text(
        '$how Le avisamos al artista por notificación en su teléfono y por '
        'email. Puedes seguirla en "Mis reservas".',
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
