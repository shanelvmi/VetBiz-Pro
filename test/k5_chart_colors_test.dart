import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K5 (2): the dashboard revenue chart, Insights (header, 14-day chart, top
// products, service donut) and the operator overview chart in Dark. Light
// must not change by a single value in any theme.
void main() {
  // fl_chart's own tooltip fill (blueGrey.darken(15)), the same in both modes.
  final tooltipFill = defaultBarTooltipColor(BarChartGroupData(x: 0));

  group('K5 charts: light is unchanged', () {
    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final c = AppColors.fromTheme(theme);
        // Tooltip text was onPrimary.
        expect(c.onChartTooltip, c.onPrimary);
        expect(c.onChartTooltip, Colors.white);
        // Insights header: the gradient, its shadow, the icon tile and ink.
        expect(c.brandSurface, c.primary);
        expect(c.brandTealOnBrand, c.brandTeal);
        expect(c.onBrandSurface, c.onPrimary);
        expect(c.onBrandSurface, c.surface);
      });
    }
  });

  group('K5 charts: dark', () {
    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final light = AppColors.fromTheme(theme);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        expect(c.onChartTooltip, Colors.white);
        expect(ColorMath.contrast(c.onChartTooltip, tooltipFill), greaterThanOrEqualTo(4.5));
        // Before K5 the tooltip text was the dark onPrimary on that fill: 3.19 to 3.29.
        expect(ColorMath.contrast(c.onPrimary, tooltipFill), lessThan(4.5));
        // Insights header text on both gradient stops, as in light.
        for (final stop in [c.brandSurface, c.brandTealOnBrand]) {
          expect(ColorMath.contrast(c.onBrandSurface, stop),
              greaterThanOrEqualTo(ColorMath.contrast(light.onBrandSurface, stop) - 0.001));
        }
        // Lines, bars, donut slices (the "Other" slice is chartService4),
        // the legend dots and fl_chart's blueGrey grid on the dark card.
        final marks = {
          'primary': c.primary, 'accent': c.accent, 'chartService1': c.chartService1,
          'chartService2': c.chartService2, 'chartService3': c.chartService3,
          'chartService4 (Other)': c.chartService4, 'chart1': c.chart1, 'grid': Colors.blueGrey,
        };
        for (final e in marks.entries) {
          expect(ColorMath.contrast(e.value, c.surface), greaterThanOrEqualTo(3.0), reason: e.key);
        }
        // Bar value labels and chart summaries are primary text on the card.
        expect(ColorMath.contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.textMuted, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep onChartTooltip', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          expect(c.copyWith().onChartTooltip, c.onChartTooltip);
          expect(c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0).onChartTooltip, c.onChartTooltip);
        }
      });
    }
  });
}
