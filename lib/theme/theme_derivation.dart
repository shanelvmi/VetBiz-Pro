import 'package:flutter/painting.dart';

import 'color_math.dart';

/// The brand-linked roles of a colour theme, derived from its primary,
/// accent and background (docs/design/themes.md sections 4 and 7, owner
/// approved option 1).
///
/// Each role is one HSL rule: a hue shift plus a saturation and lightness
/// offset (or absolute value). The numbers were taken from Pasture so that
/// Pasture reproduces today's values EXACTLY (tokens_test pins them); a new
/// theme gets every role with no extra work. Two guards keep other themes
/// sane: the warm guard and the hover visibility floor (below).
class ThemeDerivation {
  ThemeDerivation._();

  // The danger-red hue band (degrees, wrapping through 0). A primary-derived
  // role whose shifted hue lands here keeps the primary's own hue, with its
  // saturation capped: without this Harvest's hover was a dark red
  // (#571001), too close to an error.
  static const double _warmBandFrom = 330;
  static const double _warmBandTo = 40;
  static const double _warmMaxSaturation = 0.55;

  // The sidebar hover must be visibly different from the sidebar itself:
  // below this distance both hover and press get the same extra lightness,
  // in steps, until it is reached (Harvest +0.08, Ledger +0.05).
  static const double _minHoverDeltaE = 8;
  static const double _floorStep = 0.01;

  static const _Rule _sidebarHover = _Rule(hue: -12.82, sDelta: 0.648, lDelta: -0.047);
  static const _Rule _sidebarPress = _Rule(hue: -13.31, sDelta: 0.648, lDelta: -0.078);
  static const _Rule _brandTeal = _Rule(hue: -14.88, sDelta: 0.04, lDelta: 0.116);
  static const _Rule _brandTealGlow = _Rule(hue: -22.3, sAbs: 0.697, lAbs: 0.702);
  static const _Rule _quickActionTintPrimary = _Rule(hue: -24.34, sAbs: 0.302, lAbs: 0.916);
  static const _Rule _quickActionTintAccent = _Rule(hue: -4.2, sAbs: 0.85, lAbs: 0.92);

  /// The sidebar hover and press fills: (hover, press).
  static (Color, Color) sidebarFills(Color primary) {
    // Counted in whole steps so the extra lightness is exact (0.08, not a
    // sum of eight 0.01s).
    final steps = (1 / _floorStep).round();
    for (var k = 0;; k++) {
      final extra = k * _floorStep;
      final hover = _sidebarHover.apply(primary, warmGuard: true, extraL: extra);
      if (ColorMath.deltaE(hover, primary) >= _minHoverDeltaE || k >= steps) {
        return (hover, _sidebarPress.apply(primary, warmGuard: true, extraL: extra));
      }
    }
  }

  static Color brandTeal(Color primary) => _brandTeal.apply(primary, warmGuard: true);

  static Color brandTealGlow(Color primary) => _brandTealGlow.apply(primary, warmGuard: true);

  static Color quickActionTintPrimary(Color primary) => _quickActionTintPrimary.apply(primary, warmGuard: true);

  /// Accent-derived: the warm guard does not apply (accents are warm on
  /// purpose, and the tint is a pale fill, never near an error red).
  static Color quickActionTintAccent(Color accent) => _quickActionTintAccent.apply(accent, warmGuard: false);

  /// Muted text: the lightest neutral grey, starting from grey 600 (today's
  /// value), that still reaches 4.5:1 on [background]. Pasture keeps
  /// #757575; Clinic and Harvest #727272, Ledger #737373 (section 7).
  static Color textMuted(Color background) {
    for (var v = 0x75; v > 0; v--) {
      final grey = Color.fromARGB(0xFF, v, v, v);
      if (ColorMath.contrast(grey, background) >= 4.5) return grey;
    }
    return const Color(0xFF000000);
  }
}

/// One HSL rule: [hue] is added (degrees); saturation and lightness are
/// either offsets ([sDelta], [lDelta]) or absolute values ([sAbs], [lAbs]).
class _Rule {
  final double hue;
  final double? sDelta;
  final double? sAbs;
  final double? lDelta;
  final double? lAbs;

  const _Rule({required this.hue, this.sDelta, this.sAbs, this.lDelta, this.lAbs});

  static bool _inWarmBand(double h) => h >= ThemeDerivation._warmBandFrom || h <= ThemeDerivation._warmBandTo;

  Color apply(Color base, {required bool warmGuard, double extraL = 0}) {
    final hsl = HSLColor.fromColor(base);
    var h = (hsl.hue + hue) % 360;
    var s = sAbs ?? hsl.saturation + sDelta!;
    final l = (lAbs ?? hsl.lightness + lDelta!) + extraL;
    if (warmGuard && _inWarmBand(h)) {
      h = hsl.hue;
      if (s > ThemeDerivation._warmMaxSaturation) s = ThemeDerivation._warmMaxSaturation;
    }
    return HSLColor.fromAHSL(1, h, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0)).toColor();
  }
}
