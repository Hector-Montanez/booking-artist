import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'account_screen.dart';
import 'artist_detail_screen.dart';

/// Colores que el artista puede escoger para su página.
const pageColors = [
  Color(0xFF6A1B9A),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF2E7D32),
  Color(0xFFF9A825),
  Color(0xFFE65100),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF263238),
];

Future<Uint8List?> pickPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // Fotos livianas: se guardan dentro de la base de datos.
    maxWidth: 1000,
    imageQuality: 75,
  );
  return file?.readAsBytes();
}

/// Editor de la página pública del artista.
class EditPageScreen extends StatefulWidget {
  const EditPageScreen({super.key});

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  late final AppState _state = AppScope.of(context);
  late final Artist _me = _state.myArtistProfile;
  late final _name = TextEditingController(text: _me.name);
  late final _tagline = TextEditingController(text: _me.tagline);
  late final _bio = TextEditingController(text: _me.bio);
  late final _genres = TextEditingController(text: _me.genres.join(', '));
  late final _conditions = TextEditingController(text: _me.conditions);
  late final _whatsapp = TextEditingController(text: _me.whatsapp);
  late final _priceFrom = TextEditingController(
    text: _me.priceFrom?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    for (final c in [
      _name,
      _tagline,
      _bio,
      _genres,
      _conditions,
      _whatsapp,
      _priceFrom,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(change);
    _state.artistUpdated();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    // El editor también toma el color escogido, para que se vea el cambio.
    return Theme(
      data: artistPageTheme(Theme.of(context), _me.color),
      child: Builder(builder: _editor),
    );
  }

  Widget _editor(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi página'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Ver'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistDetailScreen(artist: _me, preview: true),
              ),
            ),
          ),
          const AccountButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          ProfileSwitcher(state: _state),
          const SizedBox(height: 12),
          // Portada y foto de perfil, como se verán en la página.
          SizedBox(
            height: 200,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: 40,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final b = await pickPhoto();
                      if (b != null) _update(() => _me.cover = b);
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: _me.color.withValues(alpha: 0.3),
                        image: _me.cover == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(_me.cover!),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Chip(
                            avatar: const Icon(Icons.photo_camera, size: 18),
                            label: Text(
                              _me.cover == null
                                  ? 'Añadir portada'
                                  : 'Cambiar portada',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () async {
                      final b = await pickPhoto();
                      if (b != null) _update(() => _me.photo = b);
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 4,
                            ),
                          ),
                          child: ArtistAvatar(artist: _me, size: 88),
                        ),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 16,
                            child: Icon(Icons.photo_camera, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca la portada o tu foto para cambiarlas.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre artístico',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _me.name = v.trim()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagline,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Frase corta',
              hintText: 'Ej. La voz romántica de Puerto Rico',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _me.tagline = v.trim()),
          ),
          TextField(
            controller: _bio,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Sobre mí',
              alignLabelWithHint: true,
              hintText: 'Tu experiencia, tu repertorio, qué incluye tu show…',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _me.bio = v.trim()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _genres,
            decoration: const InputDecoration(
              labelText: 'Géneros (separados por coma)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(
              () => _me.genres = v
                  .split(',')
                  .map((g) => g.trim())
                  .where((g) => g.isNotEmpty)
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tipo de artista', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          CategoryPicker(
            value: _me.category,
            onChanged: (c) => _update(() => _me.category = c),
          ),
          if (_me.category.hasInstruments) ...[
            const SizedBox(height: 8),
            Text('Instrumentos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            InstrumentPicker(
              selected: _me.instruments,
              onChanged: (l) => _update(() => _me.instruments = l),
            ),
          ],
          const SizedBox(height: 16),
          Text('Eventos que aceptas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in EventType.values)
                FilterChip(
                  avatar: Icon(e.icon, size: 18),
                  label: Text(e.label),
                  selected: _me.eventTypes.contains(e),
                  onSelected: (on) => _update(() {
                    final next = {..._me.eventTypes};
                    on ? next.add(e) : next.remove(e);
                    if (next.isNotEmpty) _me.eventTypes = next;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Precio y contacto', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'No tienes que fijar precios: cada cliente te pide cotización '
            'con su fecha y detalles, y tú le respondes con tu precio. '
            'Tarima no cobra nada de las reservas.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceFrom,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Precio desde (opcional)',
              helperText:
                  'Si lo pones, los clientes ven "Desde \$…". Si no, ven '
                  '"Precio a cotizar".',
              prefixText: r'$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final n = double.tryParse(v.trim());
              _update(() => _me.priceFrom = n != null && n > 0 ? n : null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp (opcional)',
              hintText: '787 555 1234',
              helperText:
                  'Los clientes te escriben aquí para preguntar tu precio. '
                  'Se ve en tu página.',
              prefixIcon: Icon(Icons.chat_rounded, color: whatsappGreen),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _me.whatsapp = v.trim()),
          ),
          const SizedBox(height: 24),
          Text('Condiciones', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _conditions,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Condiciones que acepta el cliente',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _update(() => _me.conditions = v.trim()),
          ),
          const SizedBox(height: 16),
          Text('Color de tu página', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in pageColors)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _update(() => _me.color = c),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: c,
                    child: _me.color == c
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Fotos', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Añadir'),
                onPressed: () async {
                  final b = await pickPhoto();
                  if (b != null) _update(() => _me.gallery.add(b));
                },
              ),
            ],
          ),
          if (_me.gallery.isEmpty)
            const Text(
              'Sube fotos de tus presentaciones para que los clientes te conozcan.',
            ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final img in _me.gallery)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(img, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Quitar foto',
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => _update(() => _me.gallery.remove(img)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_state.isMine(_me) && _me != _state.account?.artist) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text('Borrar el perfil ${_me.name}'),
              onPressed: _deleteProfile,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar ${_me.name}?'),
        content: const Text(
          'El perfil deja de salir en la app. Tus otros perfiles y tu '
          'membresía siguen igual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await _state.deleteProfile(_me);
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Perfil borrado.')));
  }
}

/// Perfiles de la cuenta (solista, agrupación, músico independiente…): se
/// escoge cuál editar o se crea otro. Cada uno sale aparte en Explorar.
class ProfileSwitcher extends StatelessWidget {
  const ProfileSwitcher({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final profiles = state.myProfiles;
    if (profiles.isEmpty) return const SizedBox.shrink();
    final current = state.myArtistProfile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profiles.length > 1 ? 'Tus perfiles' : 'Tu perfil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes tener varios perfiles (por ejemplo solista y '
              'agrupación). Cada uno sale aparte en la búsqueda y tu '
              'membresía de \$${subscriptionPrice.toStringAsFixed(0)} al mes '
              'los cubre todos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in profiles)
                  ChoiceChip(
                    avatar: Icon(p.category.icon, size: 18),
                    label: Text(p.name.isEmpty ? 'Sin nombre' : p.name),
                    selected: p == current,
                    onSelected: (_) => state.switchProfile(p),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Crear otro perfil'),
                  onPressed: () => showCreateProfile(context, state),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide el nombre y el tipo del perfil nuevo y lo crea.
Future<void> showCreateProfile(BuildContext context, AppState state) async {
  final name = TextEditingController();
  var category = ArtistCategory.agrupacion;
  var instruments = <String>[];
  final formKey = GlobalKey<FormState>();
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perfil nuevo', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Sale aparte en la búsqueda, con su propia página. Usa tu '
                  'mismo pueblo, horario y WhatsApp; los puedes cambiar '
                  'después.',
                ),
                const SizedBox(height: 12),
                Text('¿Qué tipo?', style: Theme.of(ctx).textTheme.titleMedium),
                CategoryPicker(
                  value: category,
                  onChanged: (c) => setSheet(() => category = c),
                ),
                if (category.hasInstruments) ...[
                  const SizedBox(height: 8),
                  InstrumentPicker(
                    selected: instruments,
                    onChanged: (l) => setSheet(() => instruments = l),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre artístico de este perfil',
                    hintText: 'Ej. Sofía Rivera Trío',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Crear perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (created != true) return;
  state.createProfile(
    name: name.text.trim(),
    category: category,
    instruments: instruments,
  );
}
