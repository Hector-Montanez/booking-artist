import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../cloud.dart';
import '../models.dart';
import '../widgets/common.dart';

/// Cómo pagó el cliente.
class PaymentResult {
  const PaymentResult(this.method, this.last4);

  final PaymentMethod method;

  /// Últimos 4 dígitos de la tarjeta o del teléfono de ATH Móvil.
  final String last4;
}

/// Pantalla de pago: tarjeta (Stripe) o ATH Móvil.
///
/// Si se le pasa una [booking] y el servidor de pagos está listo, cobra de
/// verdad: el servidor calcula el monto, abre la página segura de Stripe o
/// envía la solicitud a ATH Móvil, y la pantalla espera la confirmación.
/// Sin servidor (modo demo), simula el pago con un formulario de prueba.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.amount,
    required this.concept,
    this.booking,
    this.phone = '',
  });

  final double amount;
  final String concept;
  final Booking? booking;

  /// Teléfono de la cuenta, para ATH Móvil.
  final String phone;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _form = GlobalKey<FormState>();
  final _card = TextEditingController();
  final _exp = TextEditingController();
  final _cvc = TextEditingController();
  final _holder = TextEditingController();
  late final _phone = TextEditingController(
    text: widget.phone.replaceAll(RegExp(r'\D'), ''),
  );
  PaymentMethod _method = PaymentMethod.tarjeta;
  bool _paying = false;

  // Cobro real: esperando que el cliente pague en Stripe o en ATH Móvil.
  bool _waiting = false;
  bool _checking = false;
  Uri? _checkoutUrl;
  String? _error;
  Timer? _poll;
  DateTime? _waitUntil;

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [_card, _exp, _cvc, _holder, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  AppState get _state => AppScope.of(context);
  Booking? get _live =>
      widget.booking != null && _state.serverPayments ? widget.booking : null;
  PayConfig? get _config => _state.cloud?.payConfig;

  double get _amount => _live?.amountCharged ?? widget.amount;

  bool get _athAllowed => _amount <= (_config?.athMax ?? 1500);

  /// Este método cobra de verdad (o con la llave de prueba de Stripe).
  bool _real(PaymentMethod m) =>
      _live != null &&
      switch (m) {
        PaymentMethod.tarjeta => _config?.card == true,
        PaymentMethod.ath => _config?.ath == true,
        PaymentMethod.prueba => false,
      };

  String get _digits => _card.text.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final simulated = !_real(_method);
    final ath = _method == PaymentMethod.ath;
    return PopScope(
      canPop: !_paying,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pago seguro')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.concept, style: theme.textTheme.bodyLarge),
              Text(
                money(_amount),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('Forma de pago', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<PaymentMethod>(
                groupValue: _method,
                onChanged: (v) {
                  if (_waiting || v == null) return;
                  setState(() {
                    _method = v;
                    _error = null;
                  });
                },
                child: Column(
                  children: [
                    _methodTile(
                      PaymentMethod.tarjeta,
                      Icons.credit_card,
                      'Tarjeta de crédito o débito',
                      'Visa, Mastercard, American Express o Discover.',
                    ),
                    const SizedBox(height: 8),
                    _methodTile(
                      PaymentMethod.ath,
                      Icons.phone_iphone,
                      'ATH Móvil',
                      _athAllowed
                          ? 'Confirmas el pago en la app de ATH Móvil.'
                          : 'ATH Móvil acepta pagos de hasta '
                                '${money(_config?.athMax ?? 1500)}. Escoge '
                                'depósito o paga con tarjeta.',
                      enabled: _athAllowed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (simulated)
                _notice(
                  'Pago de prueba',
                  'Esta forma de pago todavía no está conectada, así que no se '
                      'cobra dinero. ${ath ? 'Escribe cualquier teléfono de 10 dígitos.' : 'Usa la tarjeta 4242 4242 4242 4242 con cualquier fecha futura y CVC.'}',
                )
              else if (!ath && _config?.cardTest == true)
                _notice(
                  'Stripe en modo de prueba',
                  'No se cobra dinero real. En la página de pago usa la '
                      'tarjeta 4242 4242 4242 4242, cualquier fecha futura y '
                      'cualquier CVC.',
                ),
              const SizedBox(height: 12),
              if (_waiting)
                _waitingPanel(theme)
              else if (ath)
                _athField()
              else if (simulated)
                ..._cardFields()
              else
                Text(
                  'Al tocar Pagar se abre la página segura de Stripe para '
                  'escribir los datos de tu tarjeta. Booking Artist nunca ve '
                  'ni guarda el número completo.',
                  style: theme.textTheme.bodyMedium,
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.lock, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ath
                          ? 'ATH Móvil cobra al momento. Si el artista rechaza '
                                'o cancelas antes de que responda, te '
                                'devolvemos el dinero.'
                          : 'El monto queda retenido en tu tarjeta y solo se '
                                'cobra si el artista acepta tu solicitud.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: _waiting
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _paying ? null : _pay,
                    child: _paying
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '${ath ? 'Pagar con ATH Móvil' : 'Pagar y enviar solicitud'} · ${money(_amount)}',
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _methodTile(
    PaymentMethod m,
    IconData icon,
    String title,
    String subtitle, {
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _method == m;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: RadioListTile<PaymentMethod>(
        value: m,
        enabled: enabled && !_waiting,
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _notice(String title, String text) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.science),
      title: Text(title),
      subtitle: Text(text),
    ),
  );

  Widget _athField() => TextFormField(
    controller: _phone,
    keyboardType: TextInputType.phone,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ],
    decoration: const InputDecoration(
      labelText: 'Teléfono de tu cuenta de ATH Móvil',
      hintText: '7875550101',
      prefixIcon: Icon(Icons.phone),
      border: OutlineInputBorder(),
    ),
    validator: (v) =>
        (v ?? '').length != 10 ? 'Escribe los 10 dígitos del teléfono' : null,
  );

  Widget _waitingPanel(ThemeData theme) {
    final ath = _method == PaymentMethod.ath;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              ath
                  ? 'Abre ATH Móvil en tu teléfono y confirma el pago de '
                        '${money(_amount)}. Tienes 10 minutos.'
                  : 'Completa el pago en la página de Stripe. Esta pantalla '
                        'se actualiza sola cuando termines.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (!ath && _checkoutUrl != null)
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir la página de pago'),
                onPressed: _openCheckout,
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _check(manual: true),
              child: const Text('Ya pagué, verificar'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _stopWaiting();
                _error = null;
              }),
              child: const Text('Cambiar forma de pago'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cardFields() => [
    TextFormField(
      controller: _card,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(16),
        _CardNumberFormatter(),
      ],
      decoration: const InputDecoration(
        labelText: 'Número de tarjeta',
        hintText: '4242 4242 4242 4242',
        prefixIcon: Icon(Icons.credit_card),
        border: OutlineInputBorder(),
      ),
      validator: (_) =>
          _digits.length < 15 ? 'Número de tarjeta incompleto' : null,
    ),
    const SizedBox(height: 12),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _exp,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
              _ExpiryFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Vence (MM/AA)',
              hintText: '12/28',
              border: OutlineInputBorder(),
            ),
            validator: _validExp,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _cvc,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: 'CVC',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v ?? '').length < 3 ? 'CVC incompleto' : null,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _holder,
      decoration: const InputDecoration(
        labelText: 'Nombre en la tarjeta',
        border: OutlineInputBorder(),
      ),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Campo requerido' : null,
    ),
  ];

  String? _validExp(String? v) {
    final m = RegExp(r'^(\d{2})/?(\d{2})$').firstMatch((v ?? '').trim());
    if (m == null) return 'Usa MM/AA';
    final month = int.parse(m[1]!);
    final year = 2000 + int.parse(m[2]!);
    if (month < 1 || month > 12) return 'Mes no válido';
    final now = DateTime.now();
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month))) {
      return 'La tarjeta está vencida';
    }
    return null;
  }

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    final live = _live;
    if (live == null) {
      // Modo demo: se simula la respuesta del procesador de pagos.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final digits = _method == PaymentMethod.ath ? _phone.text : _digits;
      Navigator.of(context)
          .pop(PaymentResult(_method, digits.substring(digits.length - 4)));
      return;
    }
    try {
      final r = await _state.cloud!.pay('start', live, {
        'method': _method.name,
        'phone': _phone.text,
      });
      if (!mounted || _finished()) return;
      final url = r['url'] as String?;
      setState(() {
        _paying = false;
        _waiting = true;
        _checkoutUrl = url == null ? null : Uri.parse(url);
        _waitUntil = DateTime.now().add(const Duration(minutes: 12));
      });
      if (_checkoutUrl != null) unawaited(_openCheckout());
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } on PayError catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _openCheckout() async {
    final url = _checkoutUrl;
    if (url == null) return;
    await launchUrl(
      url,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      webOnlyWindowName: '_blank',
    );
  }

  /// Pregunta al servidor si ya se pagó.
  Future<void> _check({bool manual = false}) async {
    final live = _live;
    if (live == null || _checking || !_waiting) return;
    if (_waitUntil != null && DateTime.now().isAfter(_waitUntil!)) {
      setState(() {
        _stopWaiting();
        _error = 'Se acabó el tiempo para pagar. Intenta otra vez.';
      });
      return;
    }
    _checking = true;
    try {
      final r = await _state.cloud!.pay('status', live);
      if (!mounted || _finished()) return;
      final failed = r['failed'] as String?;
      if (failed != null) {
        setState(() {
          _stopWaiting();
          _error = failed;
        });
      } else if (manual) {
        setState(
          () => _error = 'Todavía no vemos el pago. Espera unos segundos.',
        );
      }
    } on PayError catch (e) {
      if (manual && mounted) setState(() => _error = e.message);
    } finally {
      _checking = false;
    }
  }

  void _stopWaiting() {
    _poll?.cancel();
    _waiting = false;
    _paying = false;
  }

  /// Si la reserva ya quedó pagada, cierra la pantalla. Devuelve true si cerró.
  bool _finished() {
    final b = _live!;
    if (b.payment != PaymentStatus.retenido &&
        b.payment != PaymentStatus.pagado) {
      return false;
    }
    _poll?.cancel();
    Navigator.of(context).pop(PaymentResult(b.paymentMethod, b.cardLast4));
    return true;
  }
}

/// Pone la barra sola: al escribir 1228 se ve 12/28.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text;
    final text = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Agrupa el número de tarjeta de 4 en 4: 4242 4242 4242 4242.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(d[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
