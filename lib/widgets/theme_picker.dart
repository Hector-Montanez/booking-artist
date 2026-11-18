import 'package:flutter/material.dart';

import '../theme.dart';

/// Las tres miniaturas para escoger el estilo de la app. Al tocar una, la app
/// cambia en el momento para que la persona vea cómo queda.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.onChanged,
    this.title,
    this.hint,
  });

  final ValueChanged<AppStyle> onChanged;
  final String? title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appStyle,
      builder: (context, selected, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[const SizedBox(height: 4), Text(hint!)],
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in AppStyle.values) ...[
                if (s.index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Option(
                    style: s,
                    selected: s == selected,
                    onTap: () => onChanged(s),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Estilo ${style.label}: ${style.detail}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 0.56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: ThemeThumbnail(style: style),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.check,
                          size: 15,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              style.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.primary : null,
              ),
            ),
            Text(
              style.detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colores de cada miniatura.
class _Palette {
  const _Palette({
    required this.bg,
    required this.bar,
    required this.card,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.title,
    required this.avatars,
    this.glow = false,
  });

  final Color bg, bar, card, line, text, muted, accent;
  final Gradient title;
  final List<Color> avatars;
  final bool glow;

  static _Palette of(AppStyle s) => switch (s) {
    AppStyle.futurista => const _Palette(
      bg: NeonColors.bg,
      bar: Color(0xFF080A18),
      card: NeonColors.card,
      line: Color(0x5500F0FF),
      text: NeonColors.text,
      muted: NeonColors.muted,
      accent: NeonColors.cyan,
      title: NeonColors.gradient,
      avatars: [NeonColors.cyan, NeonColors.magenta, NeonColors.violet],
      glow: true,
    ),
    AppStyle.claro => const _Palette(
      bg: ClaroColors.bg,
      bar: Colors.white,
      card: Colors.white,
      line: ClaroColors.line,
      text: ClaroColors.text,
      muted: ClaroColors.muted,
      accent: ClaroColors.coral,
      title: ClaroColors.gradient,
      avatars: [ClaroColors.turquoise, ClaroColors.mango, ClaroColors.violet],
    ),
    AppStyle.clasico => const _Palette(
      bg: Color(0xFFFEF7FF),
      bar: Color(0xFFF3EDF7),
      card: Color(0xFFF7F2FA),
      line: Color(0xFFE7E0EC),
      text: Color(0xFF1D1B20),
      muted: Color(0xFF79747E),
      accent: Color(0xFF6A1B9A),
      title: LinearGradient(colors: [Color(0xFF1D1B20), Color(0xFF1D1B20)]),
      avatars: [Color(0xFF6A1B9A), Color(0xFF9C4DCC), Color(0xFF4A148C)],
    ),
  };
}

/// Dibujo pequeño de la pantalla de artistas con los colores de un estilo.
class ThemeThumbnail extends StatelessWidget {
  const ThemeThumbnail({super.key, required this.style});

  final AppStyle style;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(style);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final u = w / 100; // unidad relativa al ancho
        Widget bar(double width, Color color, {double h = 1}) => Container(
          width: width * u,
          height: 3.2 * u * h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2 * u),
          ),
        );
        Widget card(Color avatar) => Container(
          margin: EdgeInsets.only(bottom: 5 * u),
          padding: EdgeInsets.all(5 * u),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(6 * u),
            border: Border.all(color: p.line),
            boxShadow: p.glow
                ? [
                    BoxShadow(
                      color: NeonColors.cyan.withValues(alpha: 0.15),
                      blurRadius: 6 * u,
                    ),
                  ]
                : style == AppStyle.claro
                ? const [BoxShadow(color: Color(0x12000000), blurRadius: 4)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 14 * u,
                height: 14 * u,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatar,
                  border: p.glow ? Border.all(color: NeonColors.cyan) : null,
                ),
              ),
              SizedBox(width: 4 * u),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(34, p.text),
                    SizedBox(height: 2.5 * u),
                    bar(24, p.muted, h: 0.8),
                  ],
                ),
              ),
              bar(14, p.accent, h: 1.2),
            ],
          ),
        );
        return Container(
          color: p.bg,
          child: Stack(
            children: [
              if (p.glow) ...[
                Positioned(
                  top: -30 * u,
                  left: -30 * u,
                  child: _blob(80 * u, NeonColors.cyan, 0.25),
                ),
                Positioned(
                  bottom: 10 * u,
                  right: -40 * u,
                  child: _blob(90 * u, NeonColors.magenta, 0.2),
                ),
              ],
              if (style == AppStyle.claro) ...[
                Positioned(
                  top: -24 * u,
                  right: -24 * u,
                  child: _blob(70 * u, ClaroColors.mango, 0.28),
                ),
                Positioned(
                  bottom: 18 * u,
                  left: -30 * u,
                  child: _blob(70 * u, ClaroColors.turquoise, 0.18),
                ),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 10 * u,
                    color: p.bar.withValues(alpha: p.glow ? 0.6 : 1),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(7 * u, 7 * u, 7 * u, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62 * u,
                          height: 7 * u,
                          decoration: BoxDecoration(
                            gradient: p.title,
                            borderRadius: BorderRadius.circular(3 * u),
                          ),
                        ),
                        SizedBox(height: 6 * u),
                        Container(
                          height: 11 * u,
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(6 * u),
                            border: Border.all(color: p.line),
                          ),
                        ),
                        SizedBox(height: 6 * u),
                        for (final a in p.avatars) card(a),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 13 * u,
                    color: p.bar,
                    padding: EdgeInsets.symmetric(horizontal: 10 * u),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Container(
                            width: 7 * u,
                            height: 7 * u,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0 ? p.accent : p.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}
