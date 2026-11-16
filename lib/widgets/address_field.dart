import 'dart:async';

import 'package:flutter/material.dart';

import '../places.dart';

/// Campo de dirección que busca en Google Maps mientras se escribe. Al
/// escoger una sugerencia llena la dirección y avisa con el pueblo.
/// Si el servidor no tiene la llave de Google, es un campo de texto normal.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.controller,
    required this.onPicked,
    this.label = 'Dirección del local',
    this.icon = Icons.place,
  });

  final TextEditingController controller;
  final ValueChanged<PlaceDetails> onPicked;
  final String label;
  final IconData icon;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  bool _maps = false;
  bool _picked = false;
  bool _loading = false;
  String _session = PlacesClient.newSession();
  List<PlaceSuggestion> _suggestions = const [];
  Timer? _debounce;
  int _query = 0;

  @override
  void initState() {
    super.initState();
    PlacesClient.instance.ready().then((ok) {
      if (mounted && ok) setState(() => _maps = true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String text) {
    if (!_maps) return;
    _picked = false;
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final n = ++_query;
      setState(() => _loading = true);
      List<PlaceSuggestion> found = const [];
      try {
        found = await PlacesClient.instance.search(text.trim(), _session);
      } catch (_) {}
      if (!mounted || n != _query) return;
      setState(() {
        _loading = false;
        _suggestions = found;
      });
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() {
      _loading = true;
      _suggestions = const [];
    });
    PlaceDetails? d;
    try {
      d = await PlacesClient.instance.details(s.id, _session);
    } catch (_) {}
    if (!mounted) return;
    _session = PlacesClient.newSession();
    setState(() => _loading = false);
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo leer esa dirección. Intenta otra vez.'),
        ),
      );
      return;
    }
    if (!d.inPR) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escoge una dirección en Puerto Rico.')),
      );
      return;
    }
    widget.controller.text = d.address.isNotEmpty
        ? d.address
        : [s.main, s.secondary].where((t) => t.isNotEmpty).join(', ');
    _picked = true;
    FocusScope.of(context).unfocus();
    widget.onPicked(d);
  }

  String? _validate(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Campo requerido';
    if (_maps && !_picked) {
      return 'Escoge tu dirección de la lista de Google Maps';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          onChanged: _changed,
          validator: _validate,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: _maps
                ? 'Escribe y escoge de la lista de Google Maps'
                : 'Calle, número, sector',
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _maps
                ? Icon(
                    _picked ? Icons.check_circle : Icons.search,
                    color: _picked ? Colors.green : null,
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(s.main),
                    subtitle: s.secondary.isEmpty ? null : Text(s.secondary),
                    onTap: () => _pick(s),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Resultados de Google Maps',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lista de los 78 municipios para escoger el pueblo.
class TownField extends StatelessWidget {
  const TownField({
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
      // La key cambia con el valor para que el campo se actualice cuando el
      // pueblo llega desde Google Maps.
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: InputDecoration(
        labelText: 'Pueblo',
        helperText: helper,
        prefixIcon: const Icon(Icons.location_city),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in municipios) DropdownMenuItem(value: m, child: Text(m)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Escoge tu pueblo' : null,
    );
  }
}
