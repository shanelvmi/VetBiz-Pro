// UI6 (1): the live line is gone from the phone Today card: no line, no dot,
// no Offline ring or text. The amount row is followed directly by the three
// figures, so the card is one line shorter and the chart region (which fills
// the free space) is taller by the same amount. The delta chip, the eye (its
// place and its 48 px target, which now reaches into the gaps around the
// amount's line instead of setting its height), the period label, the switch
// and the chip are as they were. The reveal skeleton has the content's rects.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/home_card_mode.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

// Before UI6 at 390x844 (HUB4b, the harness with charts): the card was 187
// high and the chart region 255, its line under the amount 17 (the 12 px
// label in the test font).
const _cardBefore = 187.0;
const _chartBefore = 255.0;
const _lineBefore = 17.0;

const _card = ValueKey('phone-home-today-card');
const _charts = ValueKey('phone-home-charts');
const _amountRow = ValueKey('home-card-amount-row');
const _stats = ValueKey('home-card-stats');
const _delta = ValueKey('home-delta');

Future<int Function()> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  MatrixLook look = MatrixLook.light,
  HomeDelta? delta = const HomeDelta.change(12),
  bool hidden = false,
  RevealGate? gate,
}) async {
  var toggles = 0;
  await pumpAtSize(
    tester,
    size: size,
    look: look,
    screen: phoneHomeHarness(
      gate: gate,
      charts: HarnessCharts().build(),
      delta: delta,
      amountsHidden: hidden,
      onToggleAmounts: () => toggles++,
    ),
  );
  await tester.pumpAndSettle();
  return () => toggles;
}

void main() {
  group('no live line', () {
    testWidgets('no line, no dot, no Offline ring or text, in English and Kiswahili', (tester) async {
      for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
        await _pump(tester, look: look);
        for (final key in ['home-live-line', 'home-live-dot', 'home-live-ring', 'home-live-text', 'home-live-arrive']) {
          expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
        }
        expect(find.text('Offline'), findsNothing);
        expect(find.textContaining('Offline'), findsNothing);
        expect(find.textContaining('Nje ya mtandao'), findsNothing);
      }
    });
  });

  group('one line shorter', () {
    testWidgets('390x844: the card is shorter and the chart taller by the removed line', (tester) async {
      await _pump(tester);
      final card = tester.getSize(find.byKey(_card)).height;
      final chart = tester.getSize(find.byKey(_charts)).height;
      expect(card, closeTo(_cardBefore - _lineBefore, 0.5));
      expect(chart, closeTo(_chartBefore + _lineBefore, 0.5));
      // ignore: avoid_print
      print('UI6 390x844: card $_cardBefore -> $card, chart region $_chartBefore -> $chart');
    });

    testWidgets('the amount row is followed directly by the three figures', (tester) async {
      await _pump(tester);
      final amount = tester.getRect(find.byKey(_amountRow));
      final stats = tester.getRect(find.byKey(_stats));
      expect(stats.top - amount.bottom, PhoneHomeMetrics.cardRowGap);
      // The amount's own line sets the row's height now, not the eye.
      expect(amount.height, lessThan(PhoneHomeMetrics.linkHeight));
    });

    testWidgets('the same height hidden or shown, Sales or Visits, with or without the delta', (tester) async {
      await _pump(tester);
      final base = tester.getSize(find.byKey(_card));
      await _pump(tester, hidden: true);
      expect(tester.getSize(find.byKey(_card)), base);
      await _pump(tester, delta: null);
      expect(tester.getSize(find.byKey(_card)), base);
      await _pump(tester, delta: const HomeDelta.fresh());
      expect(tester.getSize(find.byKey(_card)), base);
    });
  });

  group('kept as they were', () {
    testWidgets('the delta chip beside the amount, "up 12%" and "New"', (tester) async {
      await _pump(tester);
      expect(find.descendant(of: find.byKey(_delta), matching: find.text('up 12% vs yesterday')), findsOneWidget);
      final row = tester.getRect(find.byKey(_amountRow));
      final chip = tester.getRect(find.byKey(_delta));
      expect(chip.top, greaterThanOrEqualTo(row.top));
      expect(chip.bottom, lessThanOrEqualTo(row.bottom));
      await _pump(tester, delta: const HomeDelta.fresh());
      expect(find.descendant(of: find.byKey(_delta), matching: find.text('New')), findsOneWidget);
      await _pump(tester, hidden: true);
      expect(find.byKey(_delta), findsNothing, reason: 'the eye hides it, as before');
    });

    testWidgets('the eye: 48 x 48, centred on the amount\'s line at the row\'s end, tappable to its edges', (tester) async {
      final toggles = await _pump(tester);
      final eye = tester.getRect(find.byTooltip('Hide amounts'));
      expect(eye.size, const Size(48, 48));
      final row = tester.getRect(find.byKey(_amountRow));
      expect(eye.center.dy, closeTo(row.center.dy, 0.5));
      expect(eye.right, closeTo(tester.getRect(find.byKey(_card)).right - 4, 0.5), reason: 'the card\'s right padding');
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      // The whole 48 px target answers, above and below the amount's line.
      for (final dy in [eye.top + 2, eye.center.dy, eye.bottom - 2]) {
        await tester.tapAt(Offset(eye.center.dx, dy));
        await tester.pump();
      }
      expect(toggles(), 3);
    });

    testWidgets('the switch, the chip and the period label are unchanged', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('home-card-range')), findsOneWidget);
      expect(find.text('Mon 9 Nov'), findsOneWidget);
      for (final mode in HomeCardMode.values) {
        expect(find.byKey(ValueKey('home-card-mode-${mode.key}')), findsOneWidget, reason: mode.key);
      }
      final range = tester.getRect(find.byKey(const ValueKey('home-card-range')));
      expect(range.top - tester.getRect(find.byKey(_card)).top, 4 + PhoneHomeMetrics.linkHeight,
          reason: 'under the 48 px switch row, as before');
    });
  });

  testWidgets('the reveal: the skeleton\'s card and chart rects are the content\'s', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      screen: phoneHomeHarness(gate: gate, charts: HarnessCharts().build(), delta: const HomeDelta.change(12)),
    );
    final card = tester.getRect(find.byType(TodayCard));
    final chart = tester.getRect(find.byKey(_charts));
    expect(card.height, closeTo(_cardBefore - _lineBefore, 0.5), reason: 'the skeleton is the shorter card');
    answered.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(TodayCard)), card);
    expect(tester.getRect(find.byKey(_charts)), chart);
  });
}
