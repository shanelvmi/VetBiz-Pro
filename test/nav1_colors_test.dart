import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_derivation.dart';

/// NAV1: the bottom bar's fill and inks, and the Today card's gradient, in
/// all four themes, Light and Dark.
void main() {
  double on(Color fg, Color bg) => ColorMath.contrast(Color.alphaBlend(fg, bg), bg);

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      final c = AppColors.fromTheme(theme, brightness: brightness);
      final name = '${theme.id} ${brightness.name}';

      test('$name: the bar is the surface with a faint primary tint', () {
        final tint = brightness == Brightness.light ? ThemeDerivation.navBarTintLight : ThemeDerivation.navBarTintDark;
        final tintFrom = brightness == Brightness.light ? theme.primary : c.primary;
        expect(c.navBarFill, Color.alphaBlend(tintFrom.withValues(alpha: tint), c.surface));
        expect(c.navBarFill, isNot(c.surface));
        // Faint: still close to the surface.
        expect(ColorMath.deltaE(c.navBarFill, c.surface), lessThan(8));
      });

      test('$name: the bar\'s inks reach 4.5 (labels) and so 3 (icons) on its fill', () {
        expect(on(c.primary, c.navBarFill), greaterThanOrEqualTo(4.5), reason: 'active');
        expect(on(c.navBarInactive, c.navBarFill), greaterThanOrEqualTo(4.5), reason: 'inactive');
        expect(on(c.onAccent, c.accent), greaterThanOrEqualTo(4.5), reason: 'the + on its squircle');
      });

      test('$name: the Today card gradient runs from the primary to a deeper tone', () {
        expect(c.brandGradientStart, theme.primary);
        expect(c.brandGradientEnd, ThemeDerivation.brandGradientEnd(theme.primary));
        expect(ColorMath.luminance(c.brandGradientEnd), lessThan(ColorMath.luminance(c.brandGradientStart) + 0.01));
      });

      test('$name: the on-brand inks reach 4.5 at BOTH ends of the gradient', () {
        for (final end in [c.brandGradientStart, c.brandGradientEnd]) {
          expect(on(c.onBrandSurface, end), greaterThanOrEqualTo(4.5));
          expect(on(c.onBrandSurfaceMuted, end), greaterThanOrEqualTo(4.5));
        }
      });
    }
  }

  test('Pasture: teal to deep green, light and dark alike', () {
    final light = AppColors.fromTheme(AppColorTheme.pasture);
    final dark = AppColors.fromTheme(AppColorTheme.pasture, brightness: Brightness.dark);
    expect(light.brandGradientStart, const Color(0xFF2F5D62));
    final end = HSLColor.fromColor(light.brandGradientEnd);
    expect(end.hue, closeTo(HSLColor.fromColor(light.brandGradientStart).hue - 15, 1.5));
    expect(end.lightness, lessThan(HSLColor.fromColor(light.brandGradientStart).lightness));
    expect(dark.brandGradientStart, light.brandGradientStart);
    expect(dark.brandGradientEnd, light.brandGradientEnd);
  });

  test('each theme has its own pair', () {
    final ends = {for (final t in AppColorTheme.all) AppColors.fromTheme(t).brandGradientEnd};
    expect(ends, hasLength(AppColorTheme.all.length));
  });
}
