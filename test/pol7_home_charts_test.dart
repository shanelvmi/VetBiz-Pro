// POL7: Home's Visit activity donut on the one chart palette. The slices
// are drawn as the top three by visits, largest first (the deepest tone),
// then one Other in grey; the breakdown itself is unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_visits_page.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/chart_palette.dart';

void main() {
  test('top three by visits, largest first, the rest and Other summed into one Other', () {
    final given = [
      const ServiceSlice('Vaccination', 3, 9000),
      const ServiceSlice('Deworming', 7, 4000),
      const ServiceSlice('Castration', 1, 8000),
      const ServiceSlice('Dipping', 5, 1000),
      const ServiceSlice('AI', 2, 500),
      const ServiceSlice(ServiceSlice.otherKey, 4, 700, tail: true),
    ];
    expect(homeDrawnSlices(given), [
      const ServiceSlice('Deworming', 7, 4000),
      const ServiceSlice('Dipping', 5, 1000),
      const ServiceSlice('Vaccination', 3, 9000),
      const ServiceSlice(ServiceSlice.otherKey, 7, 9200, tail: true),
    ]);
    // Totals are kept: the donut's centre and shares are unchanged.
    int visits(List<ServiceSlice> s) => s.fold(0, (n, x) => n + x.count);
    expect(visits(homeDrawnSlices(given)), visits(given));
  });

  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      test('${theme.name} ${b.name}: slices take the ramp in order, Other grey, no chart roles', () {
        final c = AppColors.fromTheme(theme, brightness: b);
        final p = ChartPalette(c);
        for (var i = 0; i < 3; i++) {
          expect(homeSliceColor(c, ServiceSlice('x$i', 1, 0), i), p.steps[i]);
        }
        expect(homeSliceColor(c, const ServiceSlice(ServiceSlice.otherKey, 1, 0, tail: true), 3), p.other);
        for (final role in [c.chart1, c.chart2, c.chart3, c.chart4, c.chart5]) {
          expect(p.steps.contains(role), isFalse);
        }
      });
    }
  }
}
