import 'package:booking_artist/widgets/embed_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte enlaces públicos en reproductores oficiales', () {
    expect(
      embedUrl('https://www.youtube.com/watch?v=abc123'),
      'https://www.youtube.com/embed/abc123?playsinline=1',
    );
    expect(
      embedUrl('https://youtu.be/abc123?si=x'),
      'https://www.youtube.com/embed/abc123?playsinline=1',
    );
    expect(
      embedUrl('https://www.youtube.com/shorts/abc123'),
      'https://www.youtube.com/embed/abc123?playsinline=1',
    );
    expect(
      embedUrl('https://www.instagram.com/reel/C0dE/?igsh=1'),
      'https://www.instagram.com/reel/C0dE/embed',
    );
    expect(
      embedUrl('https://www.tiktok.com/@x/video/123'),
      'https://www.tiktok.com/embed/v2/123',
    );
    expect(embedUrl('https://www.instagram.com/kimykacoustic/'), isNull);
  });
}
