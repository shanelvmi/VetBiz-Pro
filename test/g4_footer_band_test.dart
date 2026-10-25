import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_derivation.dart';

// G4: the full-width soft band under the signed-out cards. Light is the
// quickActionTintPrimary rule, dark the surface. The footer's text roles
// must read at 4.5 on it. textMuted, the footer's quiet text before G4,
// measured 3.94 to 4.09 on the light band (the reason for
// authFooterMutedText).
void main() {
  const pinned = {
    'pasture-light': (Color(0xFFE3F0EC), Color(0xFF6B6B6B)),
    'clinic-light': (Color(0xFFE3EFF0), Color(0xFF6B6B6B)),
    'harvest-light': (Color(0xFFF0E8E3), Color(0xFF696969)),
    'ledger-light': (Color(0xFFE3EDF0), Color(0xFF6A6A6A)),
    'pasture-dark': (Color(0xFF162325), Color(0xFF9E9E9E)),
    'clinic-dark': (Color(0xFF161E25), Color(0xFF9E9E9E)),
    'harvest-dark': (Color(0xFF251C16), Color(0xFF9E9E9E)),
    'ledger-dark': (Color(0xFF161C25), Color(0xFF9E9E9E)),
  };

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      final name = '${theme.id}-${brightness.name}';
      final c = AppColors.fromTheme(theme, brightness: brightness);

      test('$name: the band and its quiet text are pinned', () {
        expect(c.authFooterFill, pinned[name]!.$1);
        expect(c.authFooterMutedText, pinned[name]!.$2);
        if (brightness == Brightness.light) {
          expect(c.authFooterFill, c.quickActionTintPrimary);
          expect(c.authFooterFill, ThemeDerivation.quickActionTintPrimary(theme.primary));
          expect(c.authFooterMutedText, ThemeDerivation.textMuted(c.authFooterFill));
        } else {
          expect(c.authFooterFill, c.surface);
          expect(c.authFooterMutedText, c.textMuted);
        }
      });

      test('$name: every footer text role reads at 4.5 on the band', () {
        final band = c.authFooterFill;
        final roles = {
          'textPrimary (headings, the name)': c.textPrimary,
          'authFooterMutedText (tagline, copyright, version, icons)': c.authFooterMutedText,
          'primary (the links at rest)': c.primary,
        };
        roles.forEach((role, ink) {
          expect(ColorMath.contrast(ColorMath.composite(ink, band), band), greaterThanOrEqualTo(4.5), reason: role);
        });
      });
    }
  }

  test('textMuted on the light band was under 4.5 (why the new role)', () {
    for (final theme in AppColorTheme.all) {
      final c = AppColors.fromTheme(theme);
      expect(ColorMath.contrast(c.textMuted, c.authFooterFill), lessThan(4.5), reason: theme.id);
    }
  });
}
