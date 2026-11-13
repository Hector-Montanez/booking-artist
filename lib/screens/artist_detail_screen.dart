import 'package:flutter/material.dart';

import '../app_state.dart';
import '../availability.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/embed_player.dart';
import 'booking_screen.dart';
import 'inbox_screen.dart';

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artist,
    this.preview = false,
  });

  final Artist artist;

  /// El artista está viendo su propia página: se oculta el botón Reservar.
  final bool preview;

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // se reconstruye si el artista cambia sus precios
    // La página entera usa el color que escogió el artista.
    final theme = artistPageTheme(Theme.of(context), artist.color);
    return Theme(
      data: theme,
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    // Videos y publicaciones que se pueden ver con el reproductor oficial.
    final videos = artist.links
        .where((l) => embedUrl(l.url) != null || l.kind == LinkKind.youtube)
        .toList();
    final socials = artist.links.where((l) => !videos.contains(l)).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (isFuturista(context))
            SliverAppBar(
              pinned: true,
              expandedHeight: 340,
              backgroundColor: NeonColors.bg,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  end: 16,
                  bottom: 14,
                ),
                title: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Colors.white,
                    shadows: [Shadow(color: accent, blurRadius: 14)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'avatar-${artist.id}',
                      child: ArtistCoverImage(artist: artist),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0x8005060F),
                            const Color(0x0005060F),
                            accent.withValues(alpha: 0.45),
                            NeonColors.bg,
                          ],
                          stops: const [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverAppBar.large(
              title: Text(artist.name),
              expandedHeight: 220,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    image: artist.cover == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(artist.cover!),
                            fit: BoxFit.cover,
                            // Tiñe la portada con el color de la página.
                            colorFilter: ColorFilter.mode(
                              artist.color.withValues(alpha: 0.35),
                              BlendMode.srcATop,
                            ),
                          ),
                    gradient: LinearGradient(
                      colors: [
                        artist.color.withValues(alpha: 0.85),
                        theme.colorScheme.surface,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  alignment: const Alignment(0, -0.1),
                  child: Hero(
                    tag: 'avatar-${artist.id}',
                    child: ArtistAvatar(artist: artist, size: 88),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: Icon(artist.category.icon, size: 18),
                      label: Text(artist.category.label),
                    ),
                    RatingLabel(artist: artist),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place, size: 16),
                        Text(' ${artist.distanceKm} km · ${artist.zone}'),
                      ],
                    ),
                  ],
                ),
                if (artist.tagline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      artist.tagline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (artist.demoNote != null)
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(artist.demoNote!),
                    ),
                  ),
                Text(artist.bio, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final g in artist.genres)
                      Chip(
                        label: Text(g),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (artist.instruments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final i in artist.instruments)
                        Chip(
                          avatar: const Icon(Icons.music_note, size: 16),
                          label: Text(i),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Disponible para: ${artist.eventTypes.map((e) => e.label).join(', ')}',
                  style: theme.textTheme.bodyMedium,
                ),
                const _SectionTitle('Precios del artista'),
                for (final p in artist.packages)
                  Card(
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        [
                          '${_hours(p.hours)} de presentación · '
                              '${p.takesDeposit ? 'Actividad (depósito ${artist.depositPercent}%)' : 'Restaurante (sin depósito)'}',
                          if (p.description.isNotEmpty) p.description,
                        ].join('\n'),
                      ),
                      leading: Icon(p.kind.icon),
                      isThreeLine: p.description.isNotEmpty,
                      trailing: Text(
                        money(p.price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _book(context, p),
                    ),
                  ),
                const _SectionTitle('Horario'),
                if (artist.weeklyHours.isEmpty)
                  const Text('Este artista aún no ha publicado su horario.'),
                for (final day in weekdayNames.keys)
                  if (artist.weeklyHours[day] case final h?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 110, child: Text(weekdayNames[day]!)),
                          Expanded(
                            child: Text(
                              '${formatMinutes(context, h.start)} a '
                              '${formatMinutes(context, h.end)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                const _SectionTitle('Condiciones'),
                Text(
                  [
                    if (artist.takesDeposits)
                      'Paquetes de actividades: depósito de '
                          '${artist.depositPercent}% del total para reservar.',
                    if (artist.packages.any((p) => !p.takesDeposit))
                      'Paquetes de restaurante: sin depósito, solo la reserva.',
                    artist.conditions,
                  ].join(' '),
                ),
                const _SectionTitle('Reseñas'),
                if (artist.reviews == 0)
                  const Text(
                    'Todavía no tiene reseñas. Los clientes que lo contraten '
                    'podrán dejarle estrellas después del evento.',
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        artist.rating.toStringAsFixed(1),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stars(rating: artist.rating.round()),
                          Text(
                            '${artist.reviews} '
                            '${artist.reviews == 1 ? 'reseña' : 'reseñas'}',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final r in artist.reviewList.take(10))
                    ReviewTile(review: r),
                ],
                if (artist.gallery.isNotEmpty) ...[
                  const _SectionTitle('Fotos'),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: artist.gallery.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            clipBehavior: Clip.antiAlias,
                            child: InteractiveViewer(
                              child: Image.memory(artist.gallery[i]),
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            artist.gallery[i],
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (videos.isNotEmpty) ...[
                  const _SectionTitle('Videos'),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: videos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) =>
                          _VideoTile(link: videos[i], color: artist.color),
                    ),
                  ),
                ],
                if (socials.isNotEmpty) ...[
                  const _SectionTitle('Redes y enlaces'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in socials)
                        ActionChip(
                          avatar: Icon(
                            l.kind.icon,
                            color: l.kind.color,
                            size: 18,
                          ),
                          label: Text(l.title),
                          onPressed: () => openLink(context, l.url),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: preview
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('desde'),
                        Text(
                          money(artist.minPrice),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: isFuturista(context) ? accent : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      tooltip: 'Enviar mensaje',
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: AppScope.of(context).account == null
                          ? null
                          : () => chatWithArtist(context, artist),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: artist.packages.isEmpty
                            ? null
                            : () => _book(context, null),
                        icon: const Icon(Icons.event_available),
                        label: const Text('Reservar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _book(BuildContext context, PricePackage? p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(artist: artist, initialPackage: p),
      ),
    );
  }
}

String _hours(double h) => h == h.roundToDouble() ? '${h.toInt()} h' : '$h h';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    if (!isFuturista(context)) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: style),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  NeonColors.magenta,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(text, style: style?.copyWith(fontSize: 15, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.link, required this.color});

  final MediaLink link;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl(link.url);
    final placeholder = Container(color: color.withValues(alpha: 0.25));
    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => playMedia(context, link),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb == null)
                      placeholder
                    else
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
                    Center(
                      child: Icon(
                        link.kind.icon == Icons.smart_display
                            ? Icons.play_circle_fill
                            : link.kind.icon,
                        size: 48,
                        color: link.kind.color,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  link.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
