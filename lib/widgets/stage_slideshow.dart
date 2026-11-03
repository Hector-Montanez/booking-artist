import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fotos de fondo para las pantallas de bienvenida e inicio de sesión.
///
/// Todas son de Unsplash bajo la Unsplash License (uso comercial gratis,
/// sin atribución obligatoria). Se dejan los créditos aquí por cortesía.
class StagePhoto {
  const StagePhoto(this.id, this.credit);

  final String id;
  final String credit;

  String get url =>
      'https://images.unsplash.com/$id?auto=format&fit=crop&w=1600&q=70';
}

const stagePhotos = <StagePhoto>[
  // Cantante en tarima.
  StagePhoto('photo-1767376133991-a3306ad0817f', 'Amonwat Dumkrut'),
  // DJ en tarima.
  StagePhoto('photo-1596485952606-35cd3df9f3e8', 'Susanne Neumair'),
  // Público con confeti en un concierto.
  StagePhoto('photo-1757062768062-ad29deec7df4', 'Giuseppe Famiani'),
  // Cantante con guitarra.
  StagePhoto('photo-1763964062626-063ceec3100a', 'Amonwat Dumkrut'),
  // DJ mezclando.
  StagePhoto('photo-1547210841-2ceb0c5f0679', 'Krys Amon'),
  // Gente disfrutando en un bar de noche.
  StagePhoto('photo-1562189447-b5b4c783a8b9', 'Felipe Galvan'),
  // Cantante en tarima.
  StagePhoto('photo-1763355873453-0f5345311e8e', 'Amonwat Dumkrut'),
  // DJ en una fiesta.
  StagePhoto('photo-1670880016281-b3f74cdd7ddc', 'João Vicente Watanabe'),
];

bool get _inWidgetTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// Fondo de pantalla completa: fotos que se van cambiando con un fundido y un
/// zoom lento, con una capa oscura para que el texto encima se lea bien.
/// Si una foto no carga, queda el degradado de fondo.
class StageSlideshow extends StatefulWidget {
  const StageSlideshow({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 6),
  });

  final Widget child;
  final Duration interval;

  @override
  State<StageSlideshow> createState() => _StageSlideshowState();
}

class _StageSlideshowState extends State<StageSlideshow> {
  // Empieza en una foto distinta cada vez que se abre la app.
  static int _next = DateTime.now().second % stagePhotos.length;

  late int _index = _next;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_inWidgetTest) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % stagePhotos.length);
      _next = _index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inWidgetTest) return;
    // Descarga por adelantado todas las fotos para que el cambio sea suave.
    for (final p in stagePhotos) {
      precacheImage(NetworkImage(p.url), context, onError: (_, _) {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = stagePhotos[_index];
    final neon = isFuturista(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A0845), Color(0xFF0D0D1A), Color(0xFF4A0E4E)],
            ),
          ),
        ),
        if (!_inWidgetTest)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1400),
            child: _KenBurns(
              key: ValueKey(_index),
              duration: widget.interval + const Duration(seconds: 2),
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
          ),
        // Capa oscura: más oscura abajo, donde van los botones.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x80000000), Color(0xE6000000)],
              stops: [0, 0.4, 1],
            ),
          ),
        ),
        // En el estilo futurista, un velo cian y magenta encima de la foto.
        if (neon) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeonColors.cyan.withValues(alpha: 0.22),
                  Colors.transparent,
                  NeonColors.magenta.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          const IgnorePointer(child: CustomPaint(painter: ScanlinePainter())),
        ],
        if (!_inWidgetTest)
          Positioned(
            right: 8,
            bottom: 4,
            child: SafeArea(
              child: Text(
                'Foto: ${photo.credit} / Unsplash',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
        // El contenido usa el tema oscuro para que se lea sobre las fotos.
        Theme(
          data: neon ? futuristTheme() : classicTheme(Brightness.dark),
          child: widget.child,
        ),
      ],
    );
  }
}

/// Zoom lento sobre la foto mientras está en pantalla.
class _KenBurns extends StatefulWidget {
  const _KenBurns({super.key, required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration)
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.12,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: widget.child,
    );
  }
}

/// Panel translúcido para poner formularios y botones encima de las fotos.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neon = isFuturista(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neon ? const Color(0xB305060F) : const Color(0xB3121018),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: neon
              ? NeonColors.cyan.withValues(alpha: 0.45)
              : Colors.white12,
        ),
        boxShadow: neon
            ? [
                BoxShadow(
                  color: NeonColors.cyan.withValues(alpha: 0.18),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Líneas horizontales finas, como de pantalla holográfica.
class ScanlinePainter extends CustomPainter {
  const ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x14000000);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
