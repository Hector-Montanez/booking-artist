import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'artist_detail_screen.dart';

enum SortBy { distancia, precio, valoracion }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _query = '';
  ArtistCategory? _category;
  String? _instrument;
  EventType? _eventType;
  SortBy _sort = SortBy.distancia;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.toLowerCase();
    final list =
        state.artists.where((a) {
          // Un artista aparece cuando ya publicó al menos un precio.
          if (a.packages.isEmpty) return false;
          if (_category != null && a.category != _category) return false;
          if (_instrument != null && !a.instruments.contains(_instrument)) {
            return false;
          }
          if (_eventType != null && !a.eventTypes.contains(_eventType)) {
            return false;
          }
          if (q.isEmpty) return true;
          return a.name.toLowerCase().contains(q) ||
              a.genres.any((g) => g.toLowerCase().contains(q)) ||
              a.instruments.any((i) => i.toLowerCase().contains(q));
        }).toList()..sort(
          (a, b) => switch (_sort) {
            SortBy.distancia => a.distanceKm.compareTo(b.distanceKm),
            SortBy.precio => a.minPrice.compareTo(b.minPrice),
            SortBy.valoracion => b.rating.compareTo(a.rating),
          },
        );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Caguas, Puerto Rico',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿A quién quieres contratar?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SearchBar(
                    hintText: 'Busca por nombre, género o instrumento',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in ArtistCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: Icon(c.icon, size: 18),
                              label: Text(c.label),
                              selected: _category == c,
                              onSelected: (s) => setState(() {
                                _category = s ? c : null;
                                _instrument = null;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_category == ArtistCategory.musicoIndependiente)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final ins in instrumentOptions.where(
                            (ins) => state.artists.any(
                              (a) => a.instruments.contains(ins),
                            ),
                          ))
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(ins),
                                selected: _instrument == ins,
                                onSelected: (s) => setState(
                                  () => _instrument = s ? ins : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in EventType.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(e.icon, size: 18),
                              label: Text(e.label),
                              selected: _eventType == e,
                              onSelected: (s) =>
                                  setState(() => _eventType = s ? e : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${list.length} artistas cerca de ti',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      DropdownButton<SortBy>(
                        value: _sort,
                        underline: const SizedBox(),
                        onChanged: (v) => setState(() => _sort = v!),
                        items: const [
                          DropdownMenuItem(
                            value: SortBy.distancia,
                            child: Text('Más cerca'),
                          ),
                          DropdownMenuItem(
                            value: SortBy.precio,
                            child: Text('Menor precio'),
                          ),
                          DropdownMenuItem(
                            value: SortBy.valoracion,
                            child: Text('Mejor valorados'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No hay artistas con esos filtros.')),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => ArtistCard(artist: list[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'avatar-${artist.id}',
                child: ArtistAvatar(artist: artist, size: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            artist.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (artist.verified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 18, color: scheme.primary),
                        ],
                      ],
                    ),
                    Text(
                      '${artist.category.label} · ${(artist.category == ArtistCategory.musicoIndependiente ? artist.instruments : artist.genres).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingLabel(artist: artist),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.place,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        Flexible(
                          child: Text(
                            ' ${artist.distanceKm} km · ${artist.zone}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'desde',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    money(artist.minPrice),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
