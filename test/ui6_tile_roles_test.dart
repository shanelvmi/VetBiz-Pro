// UI6 (2): the action panel's two icon tones, per theme and brightness:
// homeTileIconRecord (the record tiles) and homeTileIconPlace (the place
// tiles), derived from the theme's own primary. Both reach 3:1 or more on
// the tile's fill (the surface the tile paints; the brief's homeTileFill),
// in all four themes, Light and Dark. Values pinned.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/dark_derivation.dart';
import 'package:vetbiz_pro/theme/theme_derivation.dart';

const _skip = false;

// Contrast on the tile, for the record: record / place.
// Light: Pasture 7.34 / 10.39, Clinic 8.86 / 9.65, Harvest 11.60 / 15.54,
// Ledger 14.63 / 17.64. Dark: Pasture 5.22 / 3.50, Clinic 5.07 / 3.52,
// Harvest 5.13 / 3.62, Ledger 5.06 / 3.59.
const _pinned = {
  'pasture light': (record: Color(0xFF2F5D62), place: Color(0xFF224641)),
  'pasture dark': (record: Color(0xFF509EA7), place: Color(0xFF3E8077)),
  'clinic light': (record: Color(0xFF0F4C81), place: Color(0xFF0B4B5C)),
  'clinic dark': (record: Color(0xFF4992D1), place: Color(0xFF267C93)),
  'harvest light': (record: Color(0xFF4A3426), place: Color(0xFF2F2118)),
  'harvest dark': (record: Color(0xFFB58463), place: Color(0xFF9B6A4A)),
  'ledger light': (record: Color(0xFF1E293B), place: Color(0xFF101A20)),
  'ledger dark': (record: Color(0xFF708DBA), place: Color(0xFF4A7894)),
};

void main() {
  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      final where = '${theme.id} ${brightness.name}';
      test('$where: the pinned pair, both 3:1 or more on the tile', () {
        final c = AppColors.fromTheme(theme, brightness: brightness);
        final pinned = _pinned[where]!;
        expect(c.homeTileIconRecord, pinned.record, reason: '$where record');
        expect(c.homeTileIconPlace, pinned.place, reason: '$where place');
        // The tile paints the surface (homeTileFill in the brief).
        for (final icon in [c.homeTileIconRecord, c.homeTileIconPlace]) {
          expect(ColorMath.contrast(icon, c.surface), greaterThanOrEqualTo(3), reason: where);
        }
        expect(c.homeTileIconPlace, isNot(c.homeTileIconRecord), reason: 'two tones');
      }, skip: _skip);
    }
  }

  test('the rules: light = the primary and the gradient\'s deep end; dark = the dark primary and a softer lift', () {
    for (final theme in AppColorTheme.all) {
      final light = AppColors.fromTheme(theme);
      final dark = AppColors.fromTheme(theme, brightness: Brightness.dark);
      expect(light.homeTileIconRecord, theme.primary);
      expect(light.homeTileIconPlace, ThemeDerivation.brandGradientEnd(theme.primary));
      expect(ColorMath.luminance(light.homeTileIconPlace), lessThan(ColorMath.luminance(light.homeTileIconRecord)),
          reason: '${theme.id}: deeper in Light');
      expect(dark.homeTileIconRecord, DarkDerivation.primary(theme.primary));
      expect(dark.homeTileIconPlace, DarkDerivation.tileIconPlace(theme.primary));
      expect(ColorMath.luminance(dark.homeTileIconPlace), lessThan(ColorMath.luminance(dark.homeTileIconRecord)),
          reason: '${theme.id}: softer in Dark');
      expect(ColorMath.contrast(dark.homeTileIconPlace, dark.surface), greaterThanOrEqualTo(3.5));
    }
  }, skip: _skip);
}
