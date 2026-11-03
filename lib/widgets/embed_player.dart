import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models.dart';
import 'common.dart';

/// URL del reproductor oficial (embed) de YouTube, Instagram o TikTok para un
/// enlace público. Devuelve null si el enlace no es un video o publicación.
String? embedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  final yt = youtubeId(url);
  if (yt != null) return 'https://www.youtube.com/embed/$yt?playsinline=1';

  if (host.contains('instagram.com') &&
      seg.length >= 2 &&
      const {'p', 'reel', 'tv'}.contains(seg[0])) {
    return 'https://www.instagram.com/${seg[0]}/${seg[1]}/embed';
  }

  if (host.contains('tiktok.com')) {
    final i = seg.indexOf('video');
    if (i >= 0 && i + 1 < seg.length) {
      return 'https://www.tiktok.com/embed/v2/${seg[i + 1]}';
    }
  }
  return null;
}

String? youtubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (host.endsWith('youtu.be') && seg.isNotEmpty) return seg[0];
  if (!host.contains('youtube.com')) return null;
  if (uri.queryParameters['v'] case final v?) return v;
  if (seg.length >= 2 && const {'shorts', 'embed', 'live'}.contains(seg[0])) {
    return seg[1];
  }
  return null;
}

/// Miniatura pública de YouTube para mostrar en la tarjeta del video.
String? thumbnailUrl(String url) {
  final id = youtubeId(url);
  return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

/// Abre el video dentro de la app con el reproductor oficial. En la versión web
/// lo abre en una pestaña nueva.
void playMedia(BuildContext context, MediaLink link) {
  final embed = embedUrl(link.url);
  if (embed == null || kIsWeb) {
    openLink(context, link.url);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EmbedPlayerScreen(link: link, embed: embed),
    ),
  );
}

class EmbedPlayerScreen extends StatefulWidget {
  const EmbedPlayerScreen({super.key, required this.link, required this.embed});

  final MediaLink link;
  final String embed;

  @override
  State<EmbedPlayerScreen> createState() => _EmbedPlayerScreenState();
}

class _EmbedPlayerScreenState extends State<EmbedPlayerScreen> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    // YouTube exige un origen https para permitir el reproductor incrustado.
    ..loadHtmlString('''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
</head><body>
<iframe src="${widget.embed}" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
</body></html>''', baseUrl: 'https://bookingartist.app');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.link.title),
        actions: [
          IconButton(
            tooltip: 'Abrir en ${widget.link.kind.label}',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openLink(context, widget.link.url),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
