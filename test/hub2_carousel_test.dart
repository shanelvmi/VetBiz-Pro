// HUB2 (3), updated for HUB4: Home's chart carousel: the three pages in
// order with their titles (Vet services is now Visit activity), the dots
// (the shown one longer), lazy loading (each page's data asked once, when
// first shown), the empty lines, the eye (no guide labels while hidden;
// quantities and visit counts stay), the short guide labels, and the
// colours' contrast in the four themes, Light and Dark. HUB4: a tap no
// longer opens Insights (hub4_carousel_test: the tooltip, the rows, the
// slices).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/home_movement.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

import 'helpers/screen_size_matrix.dart';

final _today = DateTime(2026, 11, 10);

HomeChartDays _days({bool empty = false}) => HomeChartDays(
      firstDay: _today.subtract(const Duration(days: 13)),
      sales: [for (var i = 0; i < 14; i++) empty ? 0 : 10000.0 * (i + 1)],
      services: [for (var i = 0; i < 14; i++) empty ? 0 : (i.isEven ? 5000.0 : 0)],
    );

const _top = HomeMovement(top: [
  TopSeller(matrixLongProductName, 12, null),
  TopSeller('Dewormer', 8, null),
  TopSeller(ProductMovement.unknownName, 2, null),
], slow: []);

const _visits = [ServiceSlice('Vaccination', 3, 15000)];

class _Calls {
  int days = 0, products = 0, visits = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  bool hidden = false,
  HomeChartDays? days,
  HomeMovement top = _top,
  List<ServiceSlice> visits = _visits,
  double height = 252,
  MatrixLook look = MatrixLook.light,
}) async {
  final calls = _Calls();
  await pumpAtSize(
    tester,
    size: const Size(360, 740),
    look: look,
    screen: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: HomeChartCarousel(
            days: (_) {
              calls.days++;
              return Future.value(days ?? _days());
            },
            movement: (_) {
              calls.products++;
              return Future.value(top);
            },
            visits: (_) {
              calls.visits++;
              return Future.value(visits);
            },
            range: HomeChartRange.week,
            onRangeChanged: (_) {},
            amountsHidden: hidden,
            onOpenProduct: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _next(WidgetTester tester) async {
  await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Sales first, then Product movement, then Visit activity; the dots follow', (tester) async {
    await _pump(tester);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Last 7 days'), findsWidgets);
    expect(find.text('Previous 7 days'), findsOneWidget);
    double dot(int i) => tester.getSize(find.byKey(ValueKey('home-chart-dot-$i'))).width;
    expect(dot(0), greaterThan(dot(1)));
    await _next(tester);
    expect(find.text('Product movement'), findsOneWidget);
    expect(dot(1), greaterThan(dot(0)));
    await _next(tester);
    expect(find.text('Visit activity'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-chart-donut-count')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lazy: each page asks once, when first shown', (tester) async {
    final calls = await _pump(tester);
    expect((calls.days, calls.products, calls.visits), (1, 0, 0));
    await _next(tester);
    expect(calls.products, 1);
    await _next(tester);
    expect((calls.days, calls.products, calls.visits), (1, 1, 1));
    await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();
    expect((calls.days, calls.products, calls.visits), (1, 1, 1));
  });

  testWidgets('the products: names (a long one ends in an ellipsis), quantities, Unknown shown in words',
      (tester) async {
    await _pump(tester);
    await _next(tester);
    expect(find.text(matrixLongProductName), findsOneWidget);
    expect(find.text('Dewormer'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing in the period: one muted line on each page', (tester) async {
    await _pump(tester, days: _days(empty: true), top: const HomeMovement(top: [], slow: []), visits: const []);
    expect(find.text('No sales in the last 7 days'), findsOneWidget);
    await _next(tester);
    expect(find.text('Nothing sold in the last 7 days'), findsWidgets);
    await _next(tester);
    expect(find.text('No visits in the last 7 days'), findsOneWidget);
  });

  testWidgets('hidden amounts: no guide labels; quantities and visit counts stay', (tester) async {
    await _pump(tester);
    expect(find.text('200k'), findsOneWidget, reason: 'the top guide label, shown');
    await _pump(tester, hidden: true);
    expect(find.text('200k'), findsNothing);
    expect(find.text('100k'), findsNothing);
    await _next(tester);
    expect(find.text('12'), findsOneWidget);
    await _next(tester);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the smallest region in Kiswahili and Dark: no overflow', (tester) async {
    for (final look in [MatrixLook.kiswahili, MatrixLook.dark]) {
      await _pump(tester, height: 120, look: look);
      await _next(tester);
      await _next(tester);
      expect(tester.takeException(), isNull, reason: look.name);
    }
  });

  test('guide labels: short, no currency', () {
    expect(Money.axis(800), '800');
    expect(Money.axis(50000), '50k');
    expect(Money.axis(2500), '2.5k');
    expect(Money.axis(1200000), '1.2M');
    expect(Money.axis(10000000), '10M');
    expect(homeChartNiceMax(70000), 100000);
    expect(homeChartNiceMax(140000), 200000);
    expect(homeChartNiceMax(22000), 50000, reason: 'HUB4: 1, 2 or 5 times a power of ten');
    expect(homeChartNiceMax(0), 1);
  });

  test('colours: the lines 3:1 and the texts 4.5:1 on the page, four themes, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final b in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: b);
        final where = '${theme.id} ${b.name}';
        expect(ColorMath.contrast(c.primary, c.surface), greaterThanOrEqualTo(3), reason: '$where current');
        expect(ColorMath.contrast(c.textMuted, c.surface), greaterThanOrEqualTo(3), reason: '$where previous');
        expect(ColorMath.contrast(c.textMuted, c.surface), greaterThanOrEqualTo(4.5), reason: '$where labels');
        expect(ColorMath.contrast(c.textPrimary, c.surface), greaterThanOrEqualTo(4.5), reason: '$where titles');
      }
    }
  });
}
