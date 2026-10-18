import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K3 (docs/design/dark_mode.md section 8): the list screens' colours for
// Dark. Light must not change by a single value in any theme.
void main() {
  group('K3: warningDeep and infoDeep (were KEEP A1 and A2)', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: light is exactly orange 900 and blue 900', () {
        final c = AppColors.fromTheme(theme);
        expect(c.warningDeep.toARGB32(), 0xFFE65100);
        expect(c.infoDeep.toARGB32(), 0xFF0D47A1);
        expect(c.warningDeep, Colors.orange.shade900);
        expect(c.infoDeep, Colors.blue.shade900);
        expect(AppColors.fromTheme(theme, brightness: Brightness.light).warningDeep, c.warningDeep);
      });

      test('${theme.id}: dark is the 4.5 lift, pinned, and passes on every dark surface', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        expect(c.warningDeep.toARGB32(), 0xFFFF5D06);
        expect(c.infoDeep.toARGB32(), 0xFF5693F1);
        for (final role in [c.warningDeep, c.infoDeep]) {
          for (final fill in [c.surface, c.surfaceMuted, c.background]) {
            expect(ColorMath.contrast(role, fill), greaterThanOrEqualTo(4.5));
          }
        }
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep them', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          final other = AppColors.fromTheme(AppColorTheme.ledger);
          for (final copy in [c.copyWith(), c.lerp(other, 0)]) {
            expect(copy.warningDeep, c.warningDeep);
            expect(copy.infoDeep, c.infoDeep);
          }
        }
      });
    }
  });
}
