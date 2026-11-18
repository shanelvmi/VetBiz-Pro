// POL7 (owner): the Sales revenue chart's three live series in one hue,
// told apart by line style: Sales the primary solid, Collections ramp step
// 2 dashed, Services ramp step 3 dotted. The legend names all three with
// swatches in the same styles; every line reaches 3:1 on the chart surface
// in every theme, Light and Dark; the data is unchanged.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/sales_revenue_chart.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/ui/polish/chart_palette.dart';

const _sales = <double>[100.0, 200, 0, 50, 300, 10, 70];
const _collections = <double>[20.0, 0, 40, 10, 0, 90, 5];
const _services = <double>[0.0, 30, 30, 0, 60, 0, 15];

Future<void> _pump(WidgetTester tester, AppColorTheme theme, Brightness b, {double width = 1200, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.build(theme, b),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SalesRevenueChart(
            salesByDay: _sales,
            collectionsByDay: _collections,
            servicesByDay: _services,
            otherIncomeTotal: 0,
            previousTotal: 500,
            isLoading: false,
            period: 'Last 7 days',
            periodLabel: (p) => p,
            onPeriodChanged: (_) {},
            start: DateTime(2026, 11, 1),
            days: 7,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      testWidgets('${theme.name} ${b.name}: one hue, three line styles, each 3:1, data unchanged', (tester) async {
        await _pump(tester, theme, b);
        final c = AppColors.fromTheme(theme, brightness: b);
        final p = ChartPalette(c);
        final lines = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;
        expect(lines, hasLength(3));
        expect([for (final l in lines) l.color], [p.steps[0], p.steps[1], p.steps[2]]);
        expect([for (final l in lines) l.dashArray], [null, PolishMetrics.chartDash, PolishMetrics.chartDot]);
        for (final l in lines) {
          expect(ColorMath.contrast(l.color!, p.surface), greaterThanOrEqualTo(3.0));
        }
        expect([for (final s in lines[0].spots) s.y], _sales);
        expect([for (final s in lines[1].spots) s.y], _collections);
        expect([for (final s in lines[2].spots) s.y], _services);
        final swatches = tester.widgetList<ChartLineSwatch>(find.byType(ChartLineSwatch)).toList();
        expect([for (final s in swatches) s.dash], [null, PolishMetrics.chartDash, PolishMetrics.chartDot]);
        expect([for (final s in swatches) s.color], [p.steps[0], p.steps[1], p.steps[2]]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final w in [390.0, 360.0]) {
    testWidgets('phone $w wide, text 1.3: the legend wraps inside the screen; no new overflow', (tester) async {
      await _pump(tester, AppColorTheme.pasture, Brightness.light, width: w, scale: 1.3);
      // The header and totals rows overflowed at this size before POL7
      // (docs/LAYOUT_DEFECTS.md, entry 18): two, and no more.
      final e = tester.takeException();
      expect(e.toString(), contains('Multiple exceptions (2)'));
      expect(find.byType(ChartLineSwatch), findsNWidgets(3));
      for (final s in find.byType(ChartLineSwatch).evaluate()) {
        expect(tester.getRect(find.byWidget(s.widget)).right, lessThanOrEqualTo(w));
      }
      final legend = find.ancestor(of: find.byType(ChartLineSwatch).first, matching: find.byType(Wrap));
      expect(tester.getRect(legend).right, lessThanOrEqualTo(w));
    });
  }
}
