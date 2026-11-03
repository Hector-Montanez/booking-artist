import 'package:flutter/material.dart';

import '../models.dart';

/// Lista de tipos de artista con su descripción.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ArtistCategory value;
  final ValueChanged<ArtistCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<ArtistCategory>(
      groupValue: value,
      onChanged: (c) => onChanged(c!),
      child: Column(
        children: [
          for (final c in ArtistCategory.values)
            RadioListTile<ArtistCategory>(
              value: c,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(c.icon),
              title: Text(c.label),
              subtitle: Text(c.description),
            ),
        ],
      ),
    );
  }
}

/// Chips para marcar los instrumentos que toca el artista.
class InstrumentPicker extends StatelessWidget {
  const InstrumentPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final i in instrumentOptions)
          FilterChip(
            label: Text(i),
            selected: selected.contains(i),
            onSelected: (on) => onChanged(
              on ? [...selected, i] : selected.where((x) => x != i).toList(),
            ),
          ),
      ],
    );
  }
}
