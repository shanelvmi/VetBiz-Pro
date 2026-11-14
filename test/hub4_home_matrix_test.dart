// HUB4: the phone Home with the new chart pages (a very long product name,
// 8-digit amounts) at 360x740, 390x844, 412x915, 360x640 and 740x360, in
// Light, Dark and Kiswahili and in the four themes (Light and Dark), on each
// of the three pages and in 7d and 30d: no overflow, 48 px targets, text 12
// px or more, no bright box in Dark, and no scrolling on the four upright
// sizes. The skeleton keeps the chart region's rect. Tablets and computers
// are pinned by the wide fingerprints (ui5_wide_unchanged,
// hub1_wide_unchanged).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _sizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

double _maxScroll(WidgetTester tester) =>
    tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first,
        )
        .position
        .maxScrollExtent;

/// Each page in turn (when the region is drawn), checked as a whole Home.
Future<void> _everyPage(WidgetTester tester, MatrixSize s, String where) async {
  for (var page = 0; page < 3; page++) {
    await checkCase(tester, phone: true, where: '$where page ${page + 1}');
    if (s.size.height > s.size.width) expect(_maxScroll(tester), 0, reason: '$where: Home fits without scrolling');
    final pages = find.byKey(const ValueKey('home-chart-pages'));
    if (pages.evaluate().isEmpty) return;
    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting());

  for (final s in _sizes) {
    for (final look in MatrixLook.values) {
      for (final range in HomeChartRange.values) {
        testWidgets('${matrixCase(s, look)} ${range.key}: every page fits', (tester) async {
          await pumpAtSize(
            tester,
            screen: phoneHomeHarness(charts: HarnessCharts().build(range: range)),
            size: s.size,
            look: look,
          );
          await tester.pumpAndSettle();
          await _everyPage(tester, s, '${matrixCase(s, look)} ${range.key}');
        }, skip: _skip);
      }
    }
    for (final theme in AppColorTheme.all) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        testWidgets('${matrixCase(s, look)} ${theme.id}: every page fits', (tester) async {
          await pumpAtSize(
            tester,
            screen: phoneHomeHarness(charts: HarnessCharts().build()),
            size: s.size,
            look: look,
            colorTheme: theme,
          );
          await tester.pumpAndSettle();
          await _everyPage(tester, s, '${matrixCase(s, look)} ${theme.id}');
        }, skip: _skip);
      }
    }
  }

  testWidgets('the reveal: the skeleton keeps the chart region\'s rect', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await pumpAtSize(
      tester,
      screen: phoneHomeHarness(gate: gate, charts: HarnessCharts().build()),
      size: const Size(390, 844),
    );
    final skeleton = tester.getRect(find.byKey(const ValueKey('phone-home-charts')));
    answered.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('phone-home-charts'))), skeleton);
  }, skip: _skip);
}
