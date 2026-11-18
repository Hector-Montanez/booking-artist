import 'package:flutter/material.dart';

/// Los tres estilos visuales de la app. Cada persona escoge el suyo al crear
/// la cuenta (con miniaturas) y lo puede cambiar en "Mi cuenta"; se guarda en
/// su cuenta. En la web también se puede ver con `?estilo=claro`,
/// `?estilo=clasico` o `?estilo=futurista` al final del enlace.
enum AppStyle {
  futurista('Futurista', 'Oscuro con luces neón'),
  claro('Claro', 'Blanco con colores vivos'),
  clasico('Clásico', 'El diseño original, en morado');

  const AppStyle(this.label, this.detail);

  final String label;
  final String detail;

  /// El estilo guardado en la cuenta, o null si no hay uno válido.
  static AppStyle? fromName(String? name) {
    final n = name?.toLowerCase().replaceAll('á', 'a');
    return AppStyle.values.where((s) => s.name == n).firstOrNull;
  }
}

final appStyle = ValueNotifier<AppStyle>(_initialStyle());

AppStyle _initialStyle() =>
    AppStyle.fromName(Uri.base.queryParameters['estilo']) ?? AppStyle.futurista;

ThemeData themeFor(AppStyle style, Brightness b) => switch (style) {
  AppStyle.futurista => futuristTheme(),
  AppStyle.claro => claroTheme(),
  AppStyle.clasico => classicTheme(b),
};

bool isClaro(BuildContext context) =>
    Theme.of(context).extension<Bright>() != null;

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

/// Botón para pasar al siguiente estilo (futurista, claro, clásico).
class StyleToggleButton extends StatelessWidget {
  const StyleToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final next =
        AppStyle.values[(appStyle.value.index + 1) % AppStyle.values.length];
    return IconButton(
      tooltip: 'Ver estilo ${next.label.toLowerCase()}',
      color: Colors.white,
      icon: const Icon(Icons.palette_outlined),
      onPressed: () => appStyle.value = next,
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

/// Color de acento que se lee bien sobre el fondo blanco del estilo claro:
/// los colores muy claros se oscurecen un poco.
Color brightAccent(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness(hsl.lightness.clamp(0.3, 0.52)).toColor();
}

/// Tema de la página de un artista: usa el color que el artista escogió para
/// los botones, precios, etiquetas y la portada.
ThemeData artistPageTheme(ThemeData base, Color color) {
  final neon = base.extension<Neon>() != null;
  final bright = base.extension<Bright>() != null;
  if (!neon && !bright) {
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: color,
        brightness: base.brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    );
  }
  final accent = neon ? neonAccent(color) : brightAccent(color);
  final onAccent = accent.computeLuminance() > 0.4
      ? const Color(0xFF05060F)
      : Colors.white;
  final soft = BorderSide(color: accent.withValues(alpha: neon ? 0.35 : 0.22));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: neon
          ? Color.lerp(accent, NeonColors.bg, 0.7)
          : Color.lerp(accent, Colors.white, 0.85),
      onPrimaryContainer: neon
          ? accent
          : Color.lerp(accent, Colors.black, 0.45),
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

// ---------------------------------------------------------------------------
// Estilo claro: fondo blanco con colores vivos (coral, turquesa, mango y
// violeta), alegre y fácil de leer de día.
// ---------------------------------------------------------------------------

/// Colores del estilo claro.
abstract final class ClaroColors {
  static const bg = Color(0xFFF6F7FB);
  static const card = Colors.white;
  static const coral = Color(0xFFF2385A);
  static const orange = Color(0xFFFF7A45);
  static const turquoise = Color(0xFF00B8A9);
  static const mango = Color(0xFFFFB020);
  static const violet = Color(0xFF7C4DFF);
  static const text = Color(0xFF1B1D2A);
  static const muted = Color(0xFF6B7085);
  static const line = Color(0xFFE6E8F0);

  static const gradient = LinearGradient(
    colors: [orange, coral, violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Marca el tema claro para que las pantallas puedan cambiar su diseño.
class Bright extends ThemeExtension<Bright> {
  const Bright();

  @override
  Bright copyWith() => this;

  @override
  Bright lerp(Bright? other, double t) => this;
}

ThemeData claroTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: ClaroColors.coral,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFE1E7),
    onPrimaryContainer: Color(0xFF8C0F2C),
    secondary: ClaroColors.turquoise,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD5F6F2),
    onSecondaryContainer: Color(0xFF00524B),
    tertiary: ClaroColors.violet,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFEDE5FF),
    onTertiaryContainer: Color(0xFF3B1E8F),
    error: Color(0xFFD32F2F),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: ClaroColors.text,
    onSurfaceVariant: ClaroColors.muted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFAFBFE),
    surfaceContainer: ClaroColors.bg,
    surfaceContainerHigh: Color(0xFFEFF1F7),
    surfaceContainerHighest: Color(0xFFE8EBF3),
    outline: Color(0xFFCDD1DE),
    outlineVariant: ClaroColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _body,
    scaffoldBackgroundColor: ClaroColors.bg,
  );
  final t = base.textTheme;
  TextStyle? d(TextStyle? s) =>
      s?.copyWith(fontWeight: FontWeight.w800, color: ClaroColors.text);
  const soft = BorderSide(color: ClaroColors.line);
  final round = BorderRadius.circular(18);
  return base.copyWith(
    extensions: const [Bright()],
    textTheme: t.copyWith(
      displayLarge: d(t.displayLarge),
      displayMedium: d(t.displayMedium),
      displaySmall: d(t.displaySmall),
      headlineLarge: d(t.headlineLarge),
      headlineMedium: d(t.headlineMedium),
      headlineSmall: d(t.headlineSmall),
      titleLarge: d(t.titleLarge),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ClaroColors.text,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x22000000),
      titleTextStyle: TextStyle(
        fontFamily: _body,
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: ClaroColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: ClaroColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: round, side: soft),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: ClaroColors.coral.withValues(alpha: 0.14),
      side: soft,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: ClaroColors.text),
      iconTheme: const IconThemeData(color: ClaroColors.coral, size: 18),
      checkmarkColor: ClaroColors.coral,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      indicatorColor: ClaroColors.coral.withValues(alpha: 0.14),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? ClaroColors.coral
              : ClaroColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected)
              ? ClaroColors.coral
              : ClaroColors.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ClaroColors.coral,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: _body,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ClaroColors.coral,
        side: const BorderSide(color: ClaroColors.coral),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ClaroColors.coral),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ClaroColors.turquoise,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: soft,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: soft,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ClaroColors.coral, width: 1.6),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(1),
      side: const WidgetStatePropertyAll(soft),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      hintStyle: const WidgetStatePropertyAll(
        TextStyle(color: ClaroColors.muted),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
    dividerTheme: const DividerThemeData(color: ClaroColors.line),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ClaroColors.text,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

/// Texto con el degradado del estilo claro (naranja, coral, violeta).
class BrightText extends StatelessWidget {
  const BrightText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => ClaroColors.gradient.createShader(r),
      child: Text(text, textAlign: textAlign, style: style),
    );
  }
}
