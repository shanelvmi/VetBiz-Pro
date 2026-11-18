// POL7: the one chart palette. Every theme, Light and Dark: the main
// series, the comparison, Other and each ramp step reach 3:1 on the chart
// surface; three steps, deep to light, in a fixed order; the slices fold
// into the top three by value plus Other.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/ui/polish/chart_palette.dart';

void main() {
  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      final p = ChartPalette(AppColors.fromTheme(theme, brightness: b));
      final where = '${theme.name} ${b.name}';

      test('$where: every mark reaches 3:1 on the chart surface', () {
        for (final c in [p.series, p.comparison, p.other, ...p.steps]) {
          expect(ColorMath.contrast(c, p.surface), greaterThanOrEqualTo(ChartPalette.minContrast), reason: where);
        }
      });

      test('$where: three steps, deep to light, the first the primary, the same every time', () {
        final s = p.steps;
        expect(s, hasLength(ChartPalette.maxSteps));
        expect(s.first, p.series);
        for (var i = 1; i < s.length; i++) {
          expect(ColorMath.contrast(s[i], p.surface), lessThan(ColorMath.contrast(s[i - 1], p.surface)), reason: where);
          // Adjacent steps are told apart (measured lowest about 1.2).
          expect(ColorMath.contrast(s[i - 1], s[i]), greaterThan(1.15), reason: where);
        }
        expect(p.steps, s);
        expect(p.ramp(2), s.take(2).toList());
        expect(p.ramp(9), s);
        expect(p.step(3), p.other);
      });
    }
  }

  test('slices: top three by value, largest first, the rest and any Other in one Other last', () {
    final given = [('a', 5), ('Other', 1), ('b', 9), ('c', 2), ('d', 9), ('e', 1)];
    final out = chartSlicesByValue<(String, int)>(
      given,
      value: (s) => s.$2,
      isOther: (s) => s.$1 == 'Other',
      keep: 3,
      fold: (rest) => ('Other', rest.fold(0, (n, s) => n + s.$2)),
    );
    expect(out, [('b', 9), ('d', 9), ('a', 5), ('Other', 4)]);
    final few = chartSlicesByValue<(String, int)>(
      [('a', 1), ('b', 2)],
      value: (s) => s.$2,
      isOther: (s) => s.$1 == 'Other',
      keep: 3,
      fold: (rest) => ('Other', 0),
    );
    expect(few, [('b', 2), ('a', 1)]);
  });
}
