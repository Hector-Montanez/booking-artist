import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
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
                  if (isFuturista(context)) ...[
                    NeonText(
                      'TARIMA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Caguas, Puerto Rico',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isFuturista(context))
                    NeonText(
                      '¿A quién quieres contratar?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  else
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
    if (isFuturista(context)) return _NeonArtistCard(artist: artist);
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

/// Tarjeta del estilo futurista: la foto del artista a todo lo ancho, con
/// el nombre y el precio encima en letras neón.
class _NeonArtistCard extends StatelessWidget {
  const _NeonArtistCard({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail =
        (artist.category == ArtistCategory.musicoIndependiente
                ? artist.instruments
                : artist.genres)
            .join(' · ');
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeonColors.cyan.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: artist.color.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: NeonColors.card,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistDetailScreen(artist: artist),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'avatar-${artist.id}',
                child: ArtistCoverImage(artist: artist),
              ),
              // Capa oscura abajo para que el texto se lea.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x66050612),
                      Color(0xF2050612),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              // Línea neón arriba.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: NeonColors.gradient),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _Pill(
                  icon: artist.category.icon,
                  text: artist.category.label.toUpperCase(),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _Pill(
                  icon: Icons.place,
                  text: '${artist.distanceKm} km',
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  artist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              if (artist.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: NeonColors.cyan,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFB9C0E6)),
                          ),
                          const SizedBox(height: 4),
                          RatingLabel(artist: artist),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xCC05060F),
                        border: Border.all(color: NeonColors.cyan),
                        boxShadow: [
                          BoxShadow(
                            color: NeonColors.cyan.withValues(alpha: 0.45),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DESDE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: NeonColors.muted,
                            ),
                          ),
                          Text(
                            money(artist.minPrice),
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: NeonColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xB305060F),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: NeonColors.cyan),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
