import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme.dart';

final _money = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 0,
);
final _cents = NumberFormat.currency(locale: 'en_US', symbol: r'$');

/// $180, o $192.50 si hay centavos.
String money(double v) =>
    (v * 100).round() % 100 == 0 ? _money.format(v) : _cents.format(v);

class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({super.key, required this.artist, this.size = 56});

  final Artist artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final neon = isFuturista(context);
    final initials = Text(
      artist.initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.36,
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: neon
            ? Border.all(
                color: NeonColors.cyan.withValues(alpha: 0.8),
                width: 2,
              )
            : null,
        boxShadow: neon
            ? [
                BoxShadow(
                  color: NeonColors.cyan.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
        gradient: LinearGradient(
          colors: [artist.color, Color.lerp(artist.color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: artist.photo != null
          ? Image.memory(
              artist.photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : artist.photoUrl == null
          ? initials
          : Image.network(
              artist.photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => initials,
            ),
    );
  }
}

class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    if (artist.reviews == 0) {
      return const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.w600));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFB300)),
        const SizedBox(width: 2),
        Text(
          artist.rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          ' (${artist.reviews})',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo abrir $url')));
  }
}

/// Foto del artista a todo lo ancho (portada). Si no tiene foto, queda un
/// degradado con su color.
class ArtistCoverImage extends StatelessWidget {
  const ArtistCoverImage({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [artist.color, Color.lerp(artist.color, Colors.black, 0.7)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
    if (artist.cover != null) {
      return Image.memory(artist.cover!, fit: BoxFit.cover);
    }
    if (artist.photo != null) {
      return Image.memory(artist.photo!, fit: BoxFit.cover);
    }
    if (artist.photoUrl == null) return fallback;
    return Image.network(
      artist.photoUrl!,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

const starColor = Color(0xFFFFB300);

/// Estrellas de una reseña (solo para ver).
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 18});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: starColor,
        ),
    ],
  );
}

/// Estrellas que se tocan para escoger de 1 a 5.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
          iconSize: 40,
          onPressed: () => onChanged(i),
          icon: Icon(
            i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
            color: starColor,
          ),
        ),
    ],
  );
}

/// Una reseña: quién, estrellas, cuándo y lo que escribió.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.clientName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat.yMMMd('es').format(review.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stars(rating: review.rating, size: 16),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.text),
            ],
          ],
        ),
      ),
    );
  }
}
