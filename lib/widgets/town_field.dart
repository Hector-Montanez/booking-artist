import 'package:flutter/material.dart';

import '../app_state.dart';
import '../places.dart' show municipios;

/// Lista desplegable con los 78 pueblos de Puerto Rico.
class PuebloField extends StatelessWidget {
  const PuebloField({
    super.key,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // La key cambia con el valor para que el campo se actualice si el
      // pueblo cambia desde fuera.
      key: ValueKey(value),
      initialValue: municipios.contains(value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: InputDecoration(
        labelText: 'Pueblo',
        helperText: helper,
        prefixIcon: const Icon(Icons.location_city),
        border: const OutlineInputBorder(),
      ),
      hint: const Text('Escoge tu pueblo'),
      items: [
        for (final m in municipios) DropdownMenuItem(value: m, child: Text(m)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Escoge tu pueblo' : null,
    );
  }
}

/// Pide (o cambia) el pueblo de la cuenta. Si [required] es true no se puede
/// cerrar sin escoger uno: así lo completan las cuentas creadas antes de que
/// la app pidiera el pueblo.
Future<void> askForTown(
  BuildContext context,
  AppState state, {
  bool required = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !required,
    builder: (_) => _TownDialog(state: state, required: required),
  );
}

class _TownDialog extends StatefulWidget {
  const _TownDialog({required this.state, required this.required});

  final AppState state;
  final bool required;

  @override
  State<_TownDialog> createState() => _TownDialogState();
}

class _TownDialogState extends State<_TownDialog> {
  late String? _town = municipios.contains(widget.state.myTown)
      ? widget.state.myTown
      : null;

  @override
  Widget build(BuildContext context) {
    final isArtist = widget.state.isArtist;
    return PopScope(
      canPop: !widget.required,
      child: AlertDialog(
        title: Text(widget.required ? '¿De qué pueblo eres?' : 'Tu pueblo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArtist
                  ? 'Los clientes de tu pueblo te verán entre los primeros '
                        'cuando busquen artistas.'
                  : 'Te mostraremos primero los artistas de tu pueblo.',
            ),
            const SizedBox(height: 16),
            PuebloField(
              value: _town,
              onChanged: (t) => setState(() => _town = t),
            ),
          ],
        ),
        actions: [
          if (!widget.required)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          FilledButton(
            onPressed: _town == null
                ? null
                : () {
                    widget.state.setTown(_town!);
                    Navigator.of(context).pop();
                  },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
