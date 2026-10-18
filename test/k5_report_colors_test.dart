import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K5 (1): the daily report screens and tabs, the review and the past
// reports list in Dark. Light must not change by a single value.
void main() {
  Color tint(Color c, double a, Color over) => ColorMath.composite(c.withValues(alpha: a), over);

  group('K5 reports: light is unchanged', () {
    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final c = AppColors.fromTheme(theme);
        expect(c.primaryNote, c.primary);
        expect(c.primaryNote, theme.primary);
      });
    }
  });

  group('K5 reports: dark', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: the review intro and Add Client tip read on their tint', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        for (final page in [c.background, c.surface, c.surfaceMuted]) {
          final box = tint(c.primary, AppAlpha.a05, page);
          expect(ColorMath.contrast(c.primaryNote.withValues(alpha: AppAlpha.a85), box), greaterThanOrEqualTo(4.5));
          // Before K5 (primary at 85%): 3.83 to 4.37.
          expect(ColorMath.contrast(c.primary.withValues(alpha: AppAlpha.a85), box), lessThan(4.5));
        }
        // Still the theme's hue, and still readable as plain ink.
        expect(HSLColor.fromColor(c.primaryNote).hue, closeTo(HSLColor.fromColor(c.primary).hue, 1.0));
        expect(ColorMath.contrast(c.primaryNote, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('${theme.id}: the rest of the reports read at least as in light (no change needed)', () {
        final light = AppColors.fromTheme(theme);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        double pill(AppColors r, Color ink, Color fill) => ColorMath.contrast(ink, tint(fill, AppAlpha.a10, r.surface));
        // Past reports: the Draft and Completed pills.
        expect(pill(c, c.warningStrong, c.warning), greaterThan(pill(light, light.warningStrong, light.warning)));
        expect(pill(c, c.successStrong, c.success), greaterThan(pill(light, light.successStrong, light.success)));
        // Empty messages, times and units in textHint (light 2.68 on white).
        expect(ColorMath.contrast(c.textHint, c.surface), greaterThan(ColorMath.contrast(light.textHint, light.surface)));
        // Summary tiles: the icon colour on its own 5% tint over the card.
        for (final mark in [c.info, c.success, c.chart4, c.danger, c.primary, c.warning, c.chart5, c.chart6, c.accent]) {
          expect(ColorMath.contrast(mark, tint(mark, AppAlpha.a05, c.surface)), greaterThanOrEqualTo(3.0));
        }
        // Variance, expense and income amounts, section titles, the tab label.
        for (final ink in [c.dangerStrong, c.successStrong, c.warningStrong, c.primary, c.textSoft, c.textMuted]) {
          expect(ColorMath.contrast(ink, c.surface), greaterThanOrEqualTo(4.5));
        }
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep primaryNote', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          expect(c.copyWith().primaryNote, c.primaryNote);
          expect(c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0).primaryNote, c.primaryNote);
        }
      });
    }
  });
}
