// HUB3: the phone Home with everything HUB3 adds (the compact header, the
// live line with a very long client name and an 8-digit amount, the delta,
// the panel in the reveal) at 360x740, 390x844, 412x915, 360x640 and
// 740x360, in Light, Dark and Kiswahili: no overflow, 48 px targets, text
// 12 px or more, no bright box in Dark (but the owner's white pill), and no
// scrolling on the four upright sizes (HUB2's rule). Tablets and computers
// are pinned by the wide fingerprints (ui5_wide_unchanged, hub1_wide_unchanged).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/dashboard/home_live_line.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';

const _skip = false;

const _sizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

final _event = HomeLiveEvent.fromEntry('sale_1', {
  'actionType': 'Sales',
  'description': 'Recorded sale to $matrixLongClientName - ${Money.saved(matrixBigAmount)}',
  'timestamp': Timestamp.fromDate(testAt(10, 15)),
});

Widget _home({RevealGate? gate, bool online = true}) => phoneHomeHarness(
      gate: gate,
      charts: HarnessCharts().build(),
      delta: const HomeDelta.change(-67),
      live: HomeLiveLine(event: _event, online: online, amountsHidden: false, showAmounts: true, now: () => testNow),
    );

double _maxScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first)
    .position
    .maxScrollExtent;

void main() {
  setUpAll(() => initializeDateFormatting());

  for (final s in _sizes) {
    for (final look in MatrixLook.values) {
      testWidgets('${matrixCase(s, look)}: no overflow, targets, text, surfaces; no scrolling upright', (tester) async {
        for (final online in [true, false]) {
          await pumpAtSize(tester, screen: _home(online: online), size: s.size, look: look);
          await tester.pumpAndSettle();
          await checkCase(tester, phone: true, where: '${matrixCase(s, look)} online $online');
          if (s.size.height > s.size.width) expect(_maxScroll(tester), 0, reason: 'Home fits without scrolling');
        }
      }, skip: _skip);
    }
  }

  testWidgets('the reveal: the skeleton has the content\'s card rect with the live line and the delta', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await pumpAtSize(tester, screen: _home(gate: gate), size: const Size(390, 844));
    final skeleton = tester.getRect(find.byType(TodayCard));
    answered.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(TodayCard)), skeleton);
    expect(_maxScroll(tester), 0);
  }, skip: _skip);
}
