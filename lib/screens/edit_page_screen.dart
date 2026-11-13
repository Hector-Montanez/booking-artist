import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
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

  @override
  void dispose() {
    for (final c in [_name, _tagline, _bio, _genres, _conditions]) {
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
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
          Text('Condiciones de reserva', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Depósito para reservar: ${_me.depositPercent}% del total'),
          Slider(
            value: _me.depositPercent.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: '${_me.depositPercent}%',
            onChanged: (v) => _update(() => _me.depositPercent = v.round()),
          ),
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
        ],
      ),
    );
  }
}
