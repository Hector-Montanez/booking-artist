import 'package:booking_artist/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El color que escoge el artista cambia el tema de su página', () {
    for (final base in [
      futuristTheme(),
      claroTheme(),
      classicTheme(Brightness.light),
    ]) {
      final green = artistPageTheme(base, const Color(0xFF2E7D32));
      final orange = artistPageTheme(base, const Color(0xFFE65100));
      expect(green.colorScheme.primary, isNot(orange.colorScheme.primary));
      expect(green.colorScheme.primary, isNot(base.colorScheme.primary));
    }
  });

  test('En el estilo futurista los colores oscuros se aclaran', () {
    final accent = neonAccent(const Color(0xFF263238));
    expect(HSLColor.fromColor(accent).lightness, greaterThanOrEqualTo(0.54));
  });

  test('Hay tres estilos y el guardado en la cuenta se reconoce', () {
    expect(AppStyle.values, hasLength(3));
    expect(AppStyle.fromName('claro'), AppStyle.claro);
    expect(AppStyle.fromName('Clásico'), AppStyle.clasico);
    expect(AppStyle.fromName(null), isNull);
    expect(AppStyle.fromName('otro'), isNull);
    expect(
      themeFor(AppStyle.claro, Brightness.dark).brightness,
      Brightness.light,
    );
    expect(claroTheme().scaffoldBackgroundColor, ClaroColors.bg);
  });

  test('En el estilo claro el color del artista se lee sobre blanco', () {
    final accent = brightAccent(const Color(0xFFFFF59D));
    expect(HSLColor.fromColor(accent).lightness, lessThanOrEqualTo(0.53));
  });
}
