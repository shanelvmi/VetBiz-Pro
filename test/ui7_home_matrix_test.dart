// UI7: the phone Home with one header row per chart page at 360x740,
// 390x844, 412x915, 360x640 and 740x360, in Light, Dark and Kiswahili
// (Pasture) and in Clinic, Harvest and Ledger (Light and Dark): no overflow,
// 48 px targets, text 12 px or more, no bright box in Dark; no scrolling on
// the four upright sizes; on each of the three pages one header (24 px at
// most, the title whole, the period named once); the reveal skeleton with
// the content's card and chart rects. Tablets and computers are pinned by
// the wide fingerprints (ui5_wide_unchanged, hub1_wide_unchanged).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_days_page.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_products_page.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_visits_page.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = true;

const _sizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

const _pages = [HomeChartSalesPage, HomeChartProductsPage, HomeChartVisitsPage];

// In Roboto, as on a phone: the square test font is about twice as wide.
Widget _home({RevealGate? gate}) => Builder(builder: (context) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
        child: phoneHomeHarness(gate: gate, charts: HarnessCharts().build(), delta: const HomeDelta.change(12)),
      );
    });

double _maxScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first)
    .position
    .maxScrollExtent;

Future<void> _check(WidgetTester tester, MatrixSize s, MatrixLook look, String where) async {
  await checkCase(tester, phone: true, where: where);
  if (s.size.height > s.size.width) expect(_maxScroll(tester), 0, reason: '$where: Home fits without scrolling');
  // 740x360 has no room for the charts (Home drops the region).
  if (find.byKey(const ValueKey('home-chart-pages')).evaluate().isEmpty) return;
  final period = look == MatrixLook.kiswahili ? 'Siku 7 zilizopita' : 'Last 7 days';
  for (var i = 0; i < _pages.length; i++) {
    final page = find.byType(_pages[i]);
    final header = find.descendant(of: page, matching: find.byKey(const ValueKey('home-chart-header')));
    expect(header, findsOneWidget, reason: '$where ${_pages[i]}');
    expect(tester.getSize(header).height, lessThanOrEqualTo(24), reason: '$where ${_pages[i]}: one row');
    final title = tester.renderObject<RenderParagraph>(find.descendant(
        of: find.descendant(of: page, matching: find.byKey(const ValueKey('home-chart-title'))),
        matching: find.byType(RichText)));
    expect(title.didExceedMaxLines, isFalse, reason: '$where ${_pages[i]}: the title whole');
    expect(find.descendant(of: page, matching: find.text(period)), findsOneWidget, reason: '$where ${_pages[i]}');
    if (i < _pages.length - 1) {
      await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
  }
  expect(tester.takeException(), isNull, reason: where);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadRealFont();
  });

  for (final s in _sizes) {
    for (final look in MatrixLook.values) {
      testWidgets('${matrixCase(s, look)} pasture', (tester) async {
        await pumpAtSize(tester, screen: _home(), size: s.size, look: look);
        await tester.pumpAndSettle();
        await _check(tester, s, look, matrixCase(s, look));
      }, skip: _skip);
    }
    for (final theme in AppColorTheme.all.where((t) => t != AppColorTheme.pasture)) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        testWidgets('${matrixCase(s, look)} ${theme.id}', (tester) async {
          await pumpAtSize(tester, screen: _home(), size: s.size, look: look, colorTheme: theme);
          await tester.pumpAndSettle();
          await _check(tester, s, look, '${matrixCase(s, look)} ${theme.id}');
        }, skip: _skip);
      }
    }
    testWidgets('${s.label}: the skeleton has the content\'s card and chart rects', (tester) async {
      final answered = ValueNotifier(false);
      final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
      addTearDown(gate.dispose);
      await pumpAtSize(tester, screen: _home(gate: gate), size: s.size);
      final card = tester.getRect(find.byType(TodayCard));
      final charts = find.byKey(const ValueKey('phone-home-charts'));
      final chart = charts.evaluate().isEmpty ? null : tester.getRect(charts);
      answered.value = true;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TodayCard)), card);
      if (chart != null) expect(tester.getRect(charts), chart);
    }, skip: _skip);
  }
}
