// UI6: the phone Home after the three corrections at 360x740, 390x844,
// 412x915, 360x640 and 740x360, in Light, Dark and Kiswahili (Pasture) and
// in Clinic, Harvest and Ledger (Light and Dark): no overflow, 48 px
// targets, text 12 px or more, no bright box in Dark; no scrolling on the
// four upright sizes; no live line; the amount row followed by the figures
// with the eye's whole target on it; the panel's icons in their two tones;
// the legend's dashed swatch wherever the legend shows; the reveal skeleton
// with the content's card and chart rects. Tablets and computers are pinned
// by the wide fingerprints (ui5_wide_unchanged, hub1_wide_unchanged).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/hub1_hub.dart';
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

Widget _home({RevealGate? gate}) =>
    phoneHomeHarness(gate: gate, charts: HarnessCharts().build(), delta: const HomeDelta.change(12));

double _maxScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first)
    .position
    .maxScrollExtent;

Future<void> _check(WidgetTester tester, MatrixSize s, String where) async {
  await checkCase(tester, phone: true, where: where);
  if (s.size.height > s.size.width) expect(_maxScroll(tester), 0, reason: '$where: Home fits without scrolling');
  for (final key in ['home-live-line', 'home-live-dot', 'home-live-ring', 'home-live-text']) {
    expect(find.byKey(ValueKey(key)), findsNothing, reason: '$where $key');
  }
  final amount = tester.getRect(find.byKey(const ValueKey('home-card-amount-row')));
  final stats = tester.getRect(find.byKey(const ValueKey('home-card-stats')));
  expect(stats.top - amount.bottom, PhoneHomeMetrics.cardRowGap, reason: '$where: the figures follow the amount');
  final eye = tester.getRect(find.ancestor(of: find.byIcon(Icons.visibility_outlined), matching: find.byType(IconButton)));
  expect(eye.size, const Size(48, 48), reason: where);
  expect(eye.center.dy, closeTo(amount.center.dy, 0.5), reason: '$where: the eye on the amount\'s line');
  final c = tester.element(find.byKey(hubPanel)).colors;
  for (final t in hubCollapsedTilesFor(isAdmin: true)) {
    final icon = tester.widget<Icon>(find.descendant(of: hubTile(t), matching: find.byType(Icon)));
    expect(icon.color, hubTileAction(t) != null ? c.homeTileIconRecord : c.homeTileIconPlace, reason: '$where ${t.name}');
  }
  if (find.byKey(const ValueKey('home-chart-legend')).evaluate().isNotEmpty) {
    expect(find.byKey(const ValueKey('home-chart-legend-dashed')), findsOneWidget, reason: where);
    expect(tester.getSize(find.byKey(const ValueKey('home-chart-legend-dash-0'))).height, 2, reason: where);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting());

  for (final s in _sizes) {
    for (final look in MatrixLook.values) {
      testWidgets('${matrixCase(s, look)} pasture', (tester) async {
        await pumpAtSize(tester, screen: _home(), size: s.size, look: look);
        await tester.pumpAndSettle();
        await _check(tester, s, matrixCase(s, look));
      }, skip: _skip);
    }
    for (final theme in AppColorTheme.all.where((t) => t != AppColorTheme.pasture)) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        testWidgets('${matrixCase(s, look)} ${theme.id}', (tester) async {
          await pumpAtSize(tester, screen: _home(), size: s.size, look: look, colorTheme: theme);
          await tester.pumpAndSettle();
          await _check(tester, s, '${matrixCase(s, look)} ${theme.id}');
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
