import 'package:flutter/material.dart';

/// Los dos estilos visuales de la app. Se cambian desde "Mi cuenta" o desde
/// el botón de la pantalla de bienvenida, y en la web también con
/// `?estilo=clasico` o `?estilo=futurista` al final del enlace.
enum AppStyle { clasico, futurista }

final appStyle = ValueNotifier<AppStyle>(_initialStyle());

AppStyle _initialStyle() {
  final q = Uri.base.queryParameters['estilo']?.toLowerCase();
  if (q == 'clasico' || q == 'clásico') return AppStyle.clasico;
  return AppStyle.futurista;
}

bool isFuturista(BuildContext context) =>
    Theme.of(context).extension<Neon>() != null;

/// Colores del estilo futurista.
abstract final class NeonColors {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0B0E1F);
  static const card = Color(0xFF10142A);
  static const cyan = Color(0xFF00F0FF);
  static const magenta = Color(0xFFFF2BD6);
  static const violet = Color(0xFF8B5CF6);
  static const text = Color(0xFFE8ECFF);
  static const muted = Color(0xFF8C93B8);

  static const gradient = LinearGradient(
    colors: [cyan, violet, magenta],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Marca el tema futurista para que las pantallas puedan cambiar su diseño.
class Neon extends ThemeExtension<Neon> {
  const Neon();

  @override
  Neon copyWith() => this;

  @override
  Neon lerp(Neon? other, double t) => this;
}

const _display = 'Orbitron';
const _body = 'Exo2';

ThemeData classicTheme(Brightness b) => ThemeData(
  colorSchemeSeed: const Color(0xFF6A1B9A),
  brightness: b,
  useMaterial3: true,
);

ThemeData futuristTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: NeonColors.cyan,
    onPrimary: Color(0xFF001518),
    primaryContainer: Color(0xFF0B3A44),
    onPrimaryContainer: NeonColors.cyan,
    secondary: NeonColors.magenta,
    onSecondary: Color(0xFF1A0016),
    secondaryContainer: Color(0xFF3A0E36),
    onSecondaryContainer: Color(0xFFFFC7F3),
    tertiary: NeonColors.violet,
    onTertiary: Colors.white,
    error: Color(0xFFFF4D6D),
    onError: Colors.black,
    surface: NeonColors.surface,
    onSurface: NeonColors.text,
    onSurfaceVariant: NeonColors.muted,
    surfaceContainerLowest: NeonColors.bg,
    surfaceContainerLow: Color(0xFF0D1124),
    surfaceContainer: NeonColors.card,
    surfaceContainerHigh: Color(0xFF151A35),
    surfaceContainerHighest: Color(0xFF1B2142),
    outline: Color(0xFF2A3363),
    outlineVariant: Color(0xFF1E2548),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _body,
    scaffoldBackgroundColor: NeonColors.bg,
  );
  final t = base.textTheme;
  TextStyle? d(TextStyle? s, {double spacing = 1.2}) => s?.copyWith(
    fontFamily: _display,
    fontWeight: FontWeight.w700,
    letterSpacing: spacing,
  );
  final neonBorder = BorderSide(color: NeonColors.cyan.withValues(alpha: 0.22));
  return base.copyWith(
    extensions: const [Neon()],
    textTheme: t.copyWith(
      displayLarge: d(t.displayLarge),
      displayMedium: d(t.displayMedium),
      displaySmall: d(t.displaySmall),
      headlineLarge: d(t.headlineLarge),
      headlineMedium: d(t.headlineMedium),
      headlineSmall: d(t.headlineSmall, spacing: 0.8),
      titleLarge: d(t.titleLarge, spacing: 0.6)?.copyWith(fontSize: 19),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: NeonColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NeonColors.text,
      titleTextStyle: TextStyle(
        fontFamily: _display,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: 1.4,
        color: NeonColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: NeonColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: neonBorder,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NeonColors.card,
      selectedColor: NeonColors.cyan.withValues(alpha: 0.18),
      side: neonBorder,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: NeonColors.text),
      iconTheme: const IconThemeData(color: NeonColors.cyan, size: 18),
      checkmarkColor: NeonColors.cyan,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF080A18),
      surfaceTintColor: Colors.transparent,
      indicatorColor: NeonColors.cyan.withValues(alpha: 0.16),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NeonColors.cyan.withValues(alpha: 0.6)),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? NeonColors.cyan
              : NeonColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: s.contains(WidgetState.selected)
              ? NeonColors.cyan
              : NeonColors.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NeonColors.cyan,
        foregroundColor: const Color(0xFF001518),
        textStyle: const TextStyle(
          fontFamily: _display,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NeonColors.cyan,
        side: BorderSide(color: NeonColors.cyan.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: NeonColors.cyan),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NeonColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: neonBorder,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: neonBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NeonColors.cyan, width: 1.6),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(NeonColors.card),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: WidgetStatePropertyAll(neonBorder),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      hintStyle: const WidgetStatePropertyAll(
        TextStyle(color: NeonColors.muted),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: NeonColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NeonColors.surface,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF1E2548)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NeonColors.card,
      contentTextStyle: TextStyle(color: NeonColors.text),
    ),
  );
}

/// Texto con el degradado neón (cian, violeta, magenta).
class NeonText extends StatelessWidget {
  const NeonText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => NeonColors.gradient.createShader(r),
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(
          shadows: [
            Shadow(
              color: NeonColors.cyan.withValues(alpha: 0.6),
              blurRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondo oscuro con resplandores y una cuadrícula tenue, como de pantalla
/// de ciencia ficción.
class NeonBackdrop extends StatelessWidget {
  const NeonBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: NeonColors.bg),
        const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Positioned(
          top: -140,
          left: -120,
          child: _Glow(color: NeonColors.cyan.withValues(alpha: 0.20)),
        ),
        Positioned(
          top: 200,
          right: -160,
          child: _Glow(color: NeonColors.magenta.withValues(alpha: 0.16)),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 380,
      height: 380,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = NeonColors.cyan.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Botón para cambiar entre el estilo clásico y el futurista.
class StyleToggleButton extends StatelessWidget {
  const StyleToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final fut = appStyle.value == AppStyle.futurista;
    return IconButton(
      tooltip: fut ? 'Ver estilo clásico' : 'Ver estilo futurista',
      icon: Icon(fut ? Icons.palette_outlined : Icons.auto_awesome),
      onPressed: () =>
          appStyle.value = fut ? AppStyle.clasico : AppStyle.futurista,
    );
  }
}

/// Color de acento que se ve bien sobre el fondo oscuro del estilo futurista:
/// los colores muy oscuros se aclaran para que brillen como neón.
Color neonAccent(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness(hsl.lightness.clamp(0.55, 0.75))
      .withSaturation(
        hsl.saturation.clamp(0.0, 1.0) < 0.15 ? 0.15 : hsl.saturation,
      )
      .toColor();
}

/// Tema de la página de un artista: usa el color que el artista escogió para
/// los botones, precios, etiquetas y la portada.
ThemeData artistPageTheme(ThemeData base, Color color) {
  if (base.extension<Neon>() == null) {
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: color,
        brightness: base.brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    );
  }
  final accent = neonAccent(color);
  final onAccent = accent.computeLuminance() > 0.4
      ? const Color(0xFF05060F)
      : Colors.white;
  final soft = BorderSide(color: accent.withValues(alpha: 0.35));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: Color.lerp(accent, NeonColors.bg, 0.7),
      onPrimaryContainer: accent,
    ),
    cardTheme: base.cardTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: soft,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: soft,
      selectedColor: accent.withValues(alpha: 0.22),
      checkmarkColor: accent,
      iconTheme: IconThemeData(color: accent, size: 18),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStatePropertyAll(accent),
        foregroundColor: WidgetStatePropertyAll(onAccent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(accent),
        side: WidgetStatePropertyAll(
          BorderSide(color: accent.withValues(alpha: 0.6)),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: accent),
    ),
  );
}
