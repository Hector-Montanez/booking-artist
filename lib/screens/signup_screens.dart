import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/pickers.dart';
import '../widgets/stage_slideshow.dart';

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null;

String? _validEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Campo requerido';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
      ? null
      : 'Correo no válido';
}

String? _validPhone(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length < 10 ? 'Escribe 10 dígitos, ej. 787 555 1234' : null;
}

String? _password(String? v) =>
    (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null;

InputDecoration _deco(String label, IconData icon, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );

/// Formulario común: campos en lista y botón fijo abajo.
class _SignupScaffold extends StatelessWidget {
  const _SignupScaffold({
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSubmit,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final c in children)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: onSubmit,
            child: const Text('Crear cuenta'),
          ),
        ),
      ),
    );
  }
}

class ClientSignupScreen extends StatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  State<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends State<ClientSignupScreen>
    with _CreatesAccount {
  final _form = GlobalKey<FormState>();
  ClientType _type = ClientType.privado;
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _address = TextEditingController();
  final _town = TextEditingController(text: 'Caguas');
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _smsOptIn = false;
  final _pass = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _name,
      _business,
      _address,
      _town,
      _email,
      _phone,
      _pass,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = _type.hasBusinessName;
    return _SignupScaffold(
      title: 'Crear cuenta de cliente',
      formKey: _form,
      onSubmit: _busy ? null : _submit,
      children: [
        Text(
          '¿Quién contrata?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        RadioGroup<ClientType>(
          groupValue: _type,
          onChanged: (t) => setState(() => _type = t!),
          child: Column(
            children: [
              for (final t in ClientType.values)
                RadioListTile<ClientType>(
                  value: t,
                  secondary: Icon(t.icon),
                  title: Text(t.label),
                  subtitle: Text(switch (t) {
                    ClientType.privado => 'Bodas, cumpleaños y fiestas en casa',
                    ClientType.restaurante =>
                      'Música para tu local o tus eventos',
                    ClientType.agrupacion =>
                      'Busca músicos para tocar con tu grupo',
                  }),
                ),
            ],
          ),
        ),
        if (isBusiness)
          TextFormField(
            controller: _business,
            decoration: _deco(
              _type == ClientType.agrupacion
                  ? 'Nombre de la agrupación'
                  : 'Nombre del restaurante o negocio',
              _type.icon,
            ),
            validator: _required,
          ),
        TextFormField(
          controller: _name,
          decoration: _deco(
            isBusiness ? 'Persona de contacto' : 'Nombre completo',
            Icons.person,
          ),
          validator: _required,
        ),
        if (_type == ClientType.restaurante)
          TextFormField(
            controller: _address,
            decoration: _deco(
              'Dirección del local',
              Icons.place,
              hint: 'Calle, número, sector',
            ),
            validator: _required,
          ),
        TextFormField(
          controller: _town,
          decoration: _deco('Pueblo', Icons.location_city),
          validator: _required,
        ),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: _deco('Teléfono', Icons.phone, hint: '787 555 1234'),
          validator: _validPhone,
        ),
        _SmsConsent(
          value: _smsOptIn,
          onChanged: (v) => setState(() => _smsOptIn = v),
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _deco('Correo electrónico', Icons.email),
          validator: _validEmail,
        ),
        TextFormField(
          controller: _pass,
          obscureText: true,
          decoration: _deco('Contraseña', Icons.lock),
          validator: _password,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    await _create(
      Account(
        role: UserRole.cliente,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        smsOptIn: _smsOptIn,
        clientType: _type,
        businessName: _type.hasBusinessName ? _business.text.trim() : '',
        address: _type == ClientType.restaurante ? _address.text.trim() : '',
        town: _town.text.trim(),
        password: _pass.text,
      ),
    );
  }
}

class ArtistSignupScreen extends StatefulWidget {
  const ArtistSignupScreen({super.key});

  @override
  State<ArtistSignupScreen> createState() => _ArtistSignupScreenState();
}

class _ArtistSignupScreenState extends State<ArtistSignupScreen>
    with _CreatesAccount {
  final _form = GlobalKey<FormState>();
  ArtistCategory _category = ArtistCategory.solista;
  List<String> _instruments = [];
  final _stage = TextEditingController();
  final _name = TextEditingController();
  final _genres = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _smsOptIn = false;
  final _pass = TextEditingController();

  @override
  void dispose() {
    for (final c in [_stage, _name, _genres, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SignupScaffold(
      title: 'Crear cuenta de artista',
      formKey: _form,
      onSubmit: _busy ? null : _submit,
      children: [
        Text(
          '¿Qué tipo de artista eres?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        CategoryPicker(
          value: _category,
          onChanged: (c) => setState(() => _category = c),
        ),
        if (_category.hasInstruments) ...[
          Text(
            _category == ArtistCategory.solista
                ? '¿Qué instrumentos tocas mientras cantas?'
                : '¿Qué instrumentos tocas?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          InstrumentPicker(
            selected: _instruments,
            onChanged: (l) => setState(() => _instruments = l),
          ),
        ],
        TextFormField(
          controller: _stage,
          decoration: _deco('Nombre artístico', Icons.star),
          validator: _required,
        ),
        TextFormField(
          controller: _name,
          decoration: _deco('Tu nombre (privado)', Icons.person),
          validator: _required,
        ),
        TextFormField(
          controller: _genres,
          decoration: _category == ArtistCategory.payaso
              ? _deco(
                  'Tipo de show',
                  Icons.celebration,
                  hint: 'Show infantil, Globos, Pintacaras',
                )
              : _deco(
                  'Géneros',
                  Icons.library_music,
                  hint: 'Salsa, Bolero, Acústico',
                ),
          validator: _required,
        ),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: _deco('Teléfono', Icons.phone, hint: '787 555 1234'),
          validator: _validPhone,
        ),
        _SmsConsent(
          value: _smsOptIn,
          onChanged: (v) => setState(() => _smsOptIn = v),
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _deco('Correo electrónico', Icons.email),
          validator: _validEmail,
        ),
        TextFormField(
          controller: _pass,
          obscureText: true,
          decoration: _deco('Contraseña', Icons.lock),
          validator: _password,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_category == ArtistCategory.musicoIndependiente &&
        _instruments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos un instrumento')),
      );
      return;
    }
    final artist = Artist(
      id: 'u${DateTime.now().millisecondsSinceEpoch}',
      name: _stage.text.trim(),
      category: _category,
      instruments: _category.hasInstruments ? _instruments : [],
      genres: _genres.text
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList(),
      bio: '',
      zone: 'Caguas',
      distanceKm: 1.0,
      rating: 0,
      reviews: 0,
      color: const Color(0xFF6A1B9A),
      packages: [],
      links: [],
      eventTypes: EventType.values.toSet(),
      email: _email.text.trim(),
    );
    await _create(
      Account(
        role: UserRole.artista,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        smsOptIn: _smsOptIn,
        artist: artist,
        password: _pass.text,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: StageSlideshow(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassPanel(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.queue_music,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bienvenido de vuelta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _deco('Correo electrónico', Icons.email),
                          validator: _validEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass,
                          obscureText: true,
                          decoration: _deco('Contraseña', Icons.lock),
                          validator: _required,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy ? 'Entrando…' : 'Entrar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _busy = false;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final error = await AppScope.of(context).login(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Crea la cuenta y vuelve al inicio, o muestra el error.
mixin _CreatesAccount<T extends StatefulWidget> on State<T> {
  bool _busy = false;

  Future<void> _create(Account account) async {
    setState(() => _busy = true);
    final error = await AppScope.of(context)
        .register(account, account.password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Permiso para enviar SMS. Las compañías de teléfono exigen que la persona lo
/// acepte por su cuenta, así que empieza sin marcar y no es obligatorio.
class _SmsConsent extends StatelessWidget {
  const _SmsConsent({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: const Text(smsConsentTitle),
      subtitle: const Text(smsConsentDetail),
    );
  }
}
