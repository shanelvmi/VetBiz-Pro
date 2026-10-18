import 'package:flutter/painting.dart';

import 'app_palette.dart';
import 'color_math.dart';

/// The rules that turn a colour theme into its Dark Mode roles
/// (docs/design/dark_mode.md section 3, owner approved option 1).
///
/// H, S, L are the theme primary's HSL. "Lift to X on Y" keeps H and S and
/// raises L in 0.01 steps until the contrast on Y reaches X. The values these
/// rules give are pinned in dark_mode_test.dart; where they differ from the
/// design table by rounding, the rule's value is kept (owner decision).
class DarkDerivation {
  DarkDerivation._();

  static const double _step = 0.01;

  static const double _neutralMaxSaturation = 0.25;
  static const double _backgroundL = 0.075;
  static const double _surfaceL = 0.115;
  static const double _surfaceMutedL = 0.155;

  static const double _primaryMinSaturation = 0.35;
  static const double _primaryMaxSaturation = 0.6;

  static const double _tintPrimarySaturation = 0.30;
  static const double _tintPrimaryStartL = 0.17;
  static const double _tintAccentSaturation = 0.45;
  static const double _tintAccentL = 0.16;

  static Color _neutral(Color primary, double l) {
    final hsl = HSLColor.fromColor(primary);
    final s = hsl.saturation < _neutralMaxSaturation ? hsl.saturation : _neutralMaxSaturation;
    return HSLColor.fromAHSL(1, hsl.hue, s, l).toColor();
  }

  /// The page, card and muted-card fills: a hint of the theme's hue, so the
  /// dark themes stay distinguishable.
  static Color background(Color primary) => _neutral(primary, _backgroundL);
  static Color surface(Color primary) => _neutral(primary, _surfaceL);
  static Color surfaceMuted(Color primary) => _neutral(primary, _surfaceMutedL);

  /// [c] itself when it already reaches [target] on [on]; otherwise its
  /// lightness raised in steps until it does (white at the end).
  static Color lift(Color c, double target, Color on) {
    if (ColorMath.contrast(c, on) >= target) return c;
    final hsl = HSLColor.fromColor(c);
    for (var k = 1;; k++) {
      final l = hsl.lightness + k * _step;
      if (l >= 1) return HSLColor.fromAHSL(1, hsl.hue, hsl.saturation, 1).toColor();
      final lifted = hsl.withLightness(l).toColor();
      if (ColorMath.contrast(lifted, on) >= target) return lifted;
    }
  }

  /// The dark `primary`: a light tone of the theme's hue, used as ink and as
  /// the fill of buttons and chips (with dark `onPrimary` ink).
  static Color primary(Color lightPrimary) {
    final hsl = HSLColor.fromColor(lightPrimary);
    final s = hsl.saturation.clamp(_primaryMinSaturation, _primaryMaxSaturation);
    final start = HSLColor.fromAHSL(1, hsl.hue, s, hsl.lightness).toColor();
    return lift(start, 4.5, surfaceMuted(lightPrimary));
  }

  /// Record Visit's tint: lowered from L 0.17 until the dark primary reaches
  /// 4.5 on it (0.17 itself gave 4.14 to 4.38).
  static Color quickActionTintPrimary(Color lightPrimary) {
    final hue = HSLColor.fromColor(lightPrimary).hue;
    final ink = primary(lightPrimary);
    final steps = (_tintPrimaryStartL / _step).round();
    for (var k = 0; k < steps; k++) {
      final tint = HSLColor.fromAHSL(1, hue, _tintPrimarySaturation, _tintPrimaryStartL - k * _step).toColor();
      if (ColorMath.contrast(ink, tint) >= 4.5) return tint;
    }
    return HSLColor.fromAHSL(1, hue, _tintPrimarySaturation, 0).toColor();
  }

  /// Add Product's tint, of the accent.
  static Color quickActionTintAccent(Color accent) =>
      HSLColor.fromAHSL(1, HSLColor.fromColor(accent).hue, _tintAccentSaturation, _tintAccentL).toColor();

  /// The semantic, chart and team-role colours are the same in every theme,
  /// so they are lifted on the lightest dark `surfaceMuted` of all themes:
  /// one value then passes on every theme's surfaces.
  static final Color lightestSurfaceMuted = AppColorTheme.all
      .map((t) => surfaceMuted(t.primary))
      .reduce((a, b) => ColorMath.luminance(a) >= ColorMath.luminance(b) ? a : b);

  /// Icons, dots, chips and chart marks: 3.0.
  static Color liftMark(Color c) => lift(c, 3.0, lightestSurfaceMuted);

  /// Text (the Strong, Deep and Text roles): 4.5.
  static Color liftText(Color c) => lift(c, 4.5, lightestSurfaceMuted);
}
