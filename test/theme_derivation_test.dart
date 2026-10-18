import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_derivation.dart';

/// T1 (docs/design/themes.md sections 4, 7 and 10.3): the derived roles are
/// exactly the approved table, and the warm guard and the hover visibility
/// floor hold. Contrast and the full role set: theme_contrast_test.dart.
void main() {
  Map<String, Color> derived(AppColors c) => {
        'sidebarHover': c.sidebarHover, 'sidebarPress': c.sidebarPress, 'brandTeal': c.brandTeal,
        'brandTealGlow': c.brandTealGlow, 'quickActionTintPrimary': c.quickActionTintPrimary,
        'quickActionTintAccent': c.quickActionTintAccent, 'textMuted': c.textMuted,
      };

  group('the derived roles (section 4 table and section 7 greys, exact)', () {
    const table = <String, Map<String, int>>{
      'pasture': {
        'sidebarHover': 0xFF00796B, 'sidebarPress': 0xFF00695C, 'brandTeal': 0xFF3E8E82,
        'brandTealGlow': 0xFF7EE8CB, 'quickActionTintPrimary': 0xFFE3F0EC,
        'quickActionTintAccent': 0xFFFCEFD9, 'textMuted': 0xFF757575,
      },
      'clinic': {
        'sidebarHover': 0xFF005A78, 'sidebarPress': 0xFF004F68, 'brandTeal': 0xFF1195BA,
        'brandTealGlow': 0xFF7EDEE8, 'quickActionTintPrimary': 0xFFE3EFF0,
        'quickActionTintAccent': 0xFFD9F4FC, 'textMuted': 0xFF727272,
      },
      'harvest': {
        'sidebarHover': 0xFF64391D, 'sidebarPress': 0xFF583219, 'brandTeal': 0xFF754F37,
        'brandTealGlow': 0xFFDDAA89, 'quickActionTintPrimary': 0xFFF0E8E3,
        'quickActionTintAccent': 0xFFFCEED9, 'textMuted': 0xFF727272,
      },
      'ledger': {
        'sidebarHover': 0xFF013559, 'sidebarPress': 0xFF012D4A, 'brandTeal': 0xFF2F5165,
        'brandTealGlow': 0xFF7ECEE8, 'quickActionTintPrimary': 0xFFE3EDF0,
        'quickActionTintAccent': 0xFFD9E1FC, 'textMuted': 0xFF737373,
      },
    };

    test('the table covers every theme', () {
      expect(table.keys, AppColorTheme.all.map((t) => t.id));
    });

    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final roles = derived(AppColors.fromTheme(theme));
        for (final e in table[theme.id]!.entries) {
          expect(roles[e.key]!.toARGB32(), e.value, reason: '${theme.id} ${e.key}');
        }
      });
    }

    test('Pasture textMuted is still grey 600', () {
      expect(AppColors.fromTheme(AppColorTheme.pasture).textMuted.toARGB32(), Colors.grey.shade600.toARGB32());
    });
  });

  group('the guards', () {
    bool inRedBand(double h) => h >= 330 || h <= 40;
    double hueDistance(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    test('warm guard: a red-hued primary keeps its own hue and S <= 0.55', () {
      // Made up: a deep brick red (hue about 0). Every shifted hue lands in
      // the red band, so each role must fall back to the primary's own hue.
      const primary = Color(0xFF8B1A1A);
      final base = HSLColor.fromColor(primary);
      final (hover, press) = ThemeDerivation.sidebarFills(primary);
      final derived = {
        'sidebarHover': hover,
        'sidebarPress': press,
        'brandTeal': ThemeDerivation.brandTeal(primary),
        'brandTealGlow': ThemeDerivation.brandTealGlow(primary),
      };
      for (final e in derived.entries) {
        final hsl = HSLColor.fromColor(e.value);
        // 8-bit channels move the hue and saturation a little.
        expect(hueDistance(hsl.hue, base.hue), lessThan(2), reason: e.key);
        expect(hsl.saturation, lessThanOrEqualTo(0.56), reason: e.key);
      }
    });

    test('warm guard: in the four themes no derived role is pulled into the red band', () {
      for (final theme in AppColorTheme.all) {
        final c = AppColors.fromTheme(theme);
        final ownHue = HSLColor.fromColor(theme.primary).hue;
        for (final role in [c.sidebarHover, c.sidebarPress, c.brandTeal, c.brandTealGlow, c.quickActionTintPrimary]) {
          final h = HSLColor.fromColor(role).hue;
          if (inRedBand(h)) expect(hueDistance(h, ownHue), lessThan(3), reason: theme.id);
        }
      }
    });

    test('visibility floor: the hover is at least dE 8 from the primary', () {
      final primaries = [
        for (final t in AppColorTheme.all) t.primary,
        // Made up: black, a near-black slate and a dark navy, where the hover
        // rule alone would land on (almost) the same colour.
        const Color(0xFF000000), const Color(0xFF101418), const Color(0xFF0B1630),
      ];
      for (final p in primaries) {
        final (hover, press) = ThemeDerivation.sidebarFills(p);
        expect(ColorMath.deltaE(hover, p), greaterThanOrEqualTo(8), reason: '$p');
        // The press stays the darker of the two, as in Pasture.
        expect(ColorMath.luminance(press), lessThanOrEqualTo(ColorMath.luminance(hover)), reason: '$p');
      }
    });

    test('visibility floor: Pasture and Clinic need none (their values are the rule alone)', () {
      expect(ColorMath.deltaE(const Color(0xFF00796B), AppColorTheme.pasture.primary), closeTo(14.0, 0.05));
      expect(ColorMath.deltaE(const Color(0xFF005A78), AppColorTheme.clinic.primary), closeTo(9.6, 0.05));
    });
  });
}
