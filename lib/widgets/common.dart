import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

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
          '${artist.rating}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          ' (${artist.reviews})',
          style: TextStyle(color: Colors.grey.shade600),
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
