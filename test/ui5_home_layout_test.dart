// UI5 (1), (2), (6), (8): the calm phone Home. The top bar (the facility
// name over the greeting, no Help), the Today card's three rows (the period
// line, the amount with the eye at its right end, the figures), one tap
// target with the chip and the eye apart, one size whatever it shows; the
// whole Home fits above the folded action panel without scrolling (HUB1: the
// panel never covers the card or the strip; its last row is on screen); the
// skeleton has the loaded layout.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

/// The phone sizes that must not scroll (HUB1: no bottom bar any more; the
/// harness is the hub, Home under the action panel).
const _noScroll = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
];

const _noSales = PhoneHomeFigures(sales: 0, collected: 0, owed: 0, netProfit: 0);

double _maxScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent;

Rect _card(WidgetTester tester) => tester.getRect(find.byType(TodayCard));

/// The folded panel's top edge (its handle is its first row).
double _panelTop(WidgetTester tester) => tester.getTopLeft(find.byKey(const ValueKey('hub-handle'))).dy;

void main() {
  group('no scroll above the action panel', () {
    for (final s in _noScroll) {
      for (final look in MatrixLook.values) {
        for (final admin in [true, false]) {
          for (final attention in [ph4SomeAttention, const <AttentionItem>[]]) {
            final where = '${matrixCase(s, look)} ${admin ? 'admin' : 'assistant'} '
                '${attention.isEmpty ? 'no strip' : 'strip'}';
            testWidgets('$where: fits above the panel, nothing under it, its last row on screen', (tester) async {
              await pumpAtSize(
                tester,
                screen: phoneHomeHarness(isAdmin: admin, attention: attention),
                size: s.size,
                look: look,
              );
              expect(tester.takeException(), isNull);
              expect(_maxScroll(tester), 0, reason: where);
              final card = _card(tester);
              final panelTop = _panelTop(tester);
              final lastTile = tester.getRect(find.byKey(const ValueKey('hub-tile-debtors')));
              expect(lastTile.bottom, lessThanOrEqualTo(s.size.height), reason: '$where: the last tile is cut');
              expect(card.bottom, lessThanOrEqualTo(panelTop), reason: '$where: the panel covers the card');
              if (attention.isNotEmpty) {
                final strip = tester.getRect(find.byType(AttentionStrip));
                expect(strip.top, greaterThanOrEqualTo(card.bottom));
                expect(strip.bottom, lessThanOrEqualTo(panelTop), reason: '$where: the panel covers the strip');
              }
            }, skip: _skip);
          }
        }
      }
    }
  });

  group('the top bar', () {
    testWidgets('the facility name over the greeting, a long name one line; no Help', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness());
      final name = find.byKey(const ValueKey('phone-home-facility-name'));
      expect(tester.widget<Text>(name).data, matrixLongFacilityName);
      expect(tester.widget<Text>(name).maxLines, 1);
      expect(tester.getTopLeft(name).dy, lessThan(tester.getTopLeft(find.text(ph4Greeting)).dy));
      expect(find.byTooltip('Help'), findsNothing);
      expect(tester.takeException(), isNull);
    }, skip: _skip);

    testWidgets('the facility name is drawn once, not inside the card', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(facilityName: 'Kilimo Agrovet'));
      expect(find.text('Kilimo Agrovet'), findsOneWidget);
      expect(find.descendant(of: find.byType(TodayCard), matching: find.text('Kilimo Agrovet')), findsNothing);
    }, skip: _skip);
  });

  group('the Today card', () {
    testWidgets('row 1 says Sales and the exact range; no "All details" line; a chevron', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(periodLabel: '3–9 Nov', period: 'This Week'));
      // HUB2: the switch's Sales, the exact range under it.
      expect(find.descendant(of: find.byType(TodayCard), matching: find.text('Sales')), findsOneWidget);
      expect(find.text('3–9 Nov'), findsOneWidget);
      expect(find.descendant(of: find.byType(TodayCard), matching: find.text('All details')), findsNothing);
      expect(find.descendant(of: find.byType(TodayCard), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
    }, skip: _skip);

    testWidgets('the eye is at the right end of the amount\'s row', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness());
      final eye = tester.getRect(find.byTooltip('Hide amounts'));
      final amount = tester.getRect(find.textContaining('12,345,678').first);
      final card = _card(tester);
      expect(eye.right, closeTo(card.right - 4, 1), reason: 'at the card\'s right end');
      expect(eye.center.dy, inInclusiveRange(amount.top - 12, amount.bottom + 12), reason: 'on the amount\'s row');
      expect(eye.top, greaterThanOrEqualTo(tester.getRect(find.byTooltip('Change period')).bottom - 1));
    }, skip: _skip);

    testWidgets('one tap target: the card opens All details; the chip and the eye do not', (tester) async {
      var details = 0, toggles = 0;
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(onAllDetails: () => details++, onToggleAmounts: () => toggles++),
      );
      // HUB2: the range line (the switch is its own button).
      await tester.tap(find.text('Mon 9 Nov'));
      expect(details, 1);
      await tester.tap(find.byTooltip('Hide amounts'));
      expect((details, toggles), (1, 1));
      await tester.tap(find.byTooltip('Change period'));
      await tester.pumpAndSettle();
      expect(details, 1);
      expect(find.text('This Month'), findsOneWidget, reason: 'the period menu opened');
    }, skip: _skip);

    testWidgets('"No sales yet" only without sales; one card size hidden, shown, every period', (tester) async {
      Future<Rect> size(PhoneHomeFigures f, {bool hidden = false, String period = 'Today', String label = 'Mon 9 Nov'}) async {
        await pumpPhoneHome(
          tester,
          phoneHomeHarness(figures: f, amountsHidden: hidden, period: period, periodLabel: label, attention: const []),
        );
        return _card(tester);
      }

      // The line always keeps its room; Visibility shows it only without sales.
      bool noSalesShown() => tester
          .widget<Visibility>(find.ancestor(of: find.text('No sales yet'), matching: find.byType(Visibility)))
          .visible;
      final shown = await size(ph4BigFigures);
      expect(noSalesShown(), isFalse);
      final none = await size(_noSales);
      expect(noSalesShown(), isTrue);
      expect(none, shown);
      expect(await size(ph4BigFigures, hidden: true), shown);
      expect(await size(_noSales, hidden: true), shown);
      for (final (p, l) in [('This Week', '28 Dec 2026–1 Jan 2027'), ('This Month', 'Nov 2026'), ('This Year', '2026')]) {
        expect(await size(ph4BigFigures, period: p, label: l), shown, reason: p);
      }
    }, skip: _skip);

    testWidgets('an assistant sees two figures, no Net profit', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(isAdmin: false));
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Owed'), findsOneWidget);
      expect(find.text('Net profit'), findsNothing);
    }, skip: _skip);

    testWidgets('the card is a button named All details for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPhoneHome(tester, phoneHomeHarness());
      final card = tester.getSemantics(find.bySemanticsLabel('All details'));
      expect(card.label, 'All details');
      // The chip and the eye are their own nodes inside the card's.
      final inside = <String>[];
      bool collect(SemanticsNode n) {
        inside.add(n.tooltip);
        n.visitChildren(collect);
        return true;
      }

      card.visitChildren(collect);
      expect(inside, containsAll(['Change period', 'Hide amounts']));
      handle.dispose();
    }, skip: _skip);
  });

  group('the reveal skeleton (RV1) has the loaded layout', () {
    for (final s in _noScroll) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        testWidgets('${matrixCase(s, look)}: card, strip and panel rects identical before and after', (tester) async {
          final answered = ValueNotifier(false);
          final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
          addTearDown(gate.dispose);
          await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate), size: s.size, look: look);
          expect(find.byType(SkeletonPulse), findsWidgets);
          Map<Type, Rect> rects() => {
                for (final t in [TodayCard, AttentionStrip, HomeActionPanel])
                  // The content is built offstage meanwhile; finders skip it.
                  t: tester.getRect(find.byType(t)),
              };
          final before = rects();
          answered.value = true;
          await tester.pumpAndSettle();
          expect(find.byType(SkeletonPulse), findsNothing);
          expect(rects(), before);
          expect(tester.takeException(), isNull);
        }, skip: _skip);
      }
    }

    testWidgets('the strip\'s slot is reserved until its first answer, then the strip in place', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(attentionReady: false));
      final card = _card(tester);
      await pumpPhoneHome(tester, phoneHomeHarness());
      await tester.pumpAndSettle();
      expect(_card(tester), card);
      expect(tester.getSize(find.byType(AttentionStrip)).height, PhoneHomeMetrics.attentionStripHeight);
    }, skip: _skip);
  });
}
