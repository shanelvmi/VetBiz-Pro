// HUB3 (5): the action panel joins Home's reveal. While the skeleton shows,
// the panel is not drawn (its room stays reserved: Home's content and the
// skeleton keep the same rects); when the gate opens it rises 12 px and fades
// in together with the content (AppMotion.revealDuration and revealCurve),
// and can be used at once; when Home is already held (a return) it is there
// from the first frame with no animation; under reduced motion it is
// instant. (6): a little more room under its second row when the phone has a
// bottom inset, and Home still fits without scrolling.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _panel = ValueKey('hub-panel');

RevealGate _gate(ValueNotifier<bool> answered) => RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);

Future<void> _pump(WidgetTester tester, Widget home, {bool still = false, Size size = const Size(390, 844)}) => pumpAtSize(
      tester,
      size: size,
      screen: home,
      wrap: still ? (app) => MediaQuery(data: const MediaQueryData(disableAnimations: true), child: app) : null,
    );

void main() {
  testWidgets('during the skeleton the panel is not drawn; its room is kept', (tester) async {
    final answered = ValueNotifier(false);
    await _pump(tester, phoneHomeHarness(gate: _gate(answered)));
    expect(find.byKey(_panel), findsNothing, reason: 'not drawn (offstage)');
    expect(find.byKey(_panel, skipOffstage: false), findsOneWidget, reason: 'built, so it is ready');
    // Home pads its end for the folded panel all the same.
    final list = find.byKey(const ValueKey('phone-home-list'), skipOffstage: false);
    expect(list, findsWidgets);
    answered.value = true;
    await tester.pumpAndSettle();
  }, skip: _skip);

  testWidgets('it rises and fades in together with the content, then sits where it always does', (tester) async {
    await _pump(tester, phoneHomeHarness());
    await tester.pumpAndSettle();
    final settled = hubPanelTop(tester);

    final answered = ValueNotifier(false);
    await _pump(tester, phoneHomeHarness(gate: _gate(answered)));
    answered.value = true;
    await tester.pump();
    await tester.pump(AppMotion.revealDuration ~/ 2);
    final top = hubPanelTop(tester);
    expect(top, greaterThan(settled), reason: 'still rising');
    expect(top - settled, lessThanOrEqualTo(AppMotion.revealRise));
    final fades = tester.widgetList<FadeTransition>(find.ancestor(of: find.byKey(_panel), matching: find.byType(FadeTransition)));
    expect(fades.map((f) => f.opacity.value).any((o) => o > 0 && o < 1), isTrue);
    // The card is at the same point of its own rise.
    final cardFade = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.byKey(const ValueKey('phone-home-today-card')), matching: find.byType(FadeTransition)));
    expect(cardFade.map((f) => f.opacity.value), contains(fades.map((f) => f.opacity.value).firstWhere((o) => o > 0 && o < 1)));
    await tester.pumpAndSettle();
    expect(hubPanelTop(tester), settled);
  }, skip: _skip);

  testWidgets('it can be used as soon as it shows', (tester) async {
    final tapped = <HubTile>[];
    final answered = ValueNotifier(false);
    await _pump(tester, phoneHomeHarness(gate: _gate(answered), onTile: (_, t) async => tapped.add(t)));
    answered.value = true;
    await tester.pump();
    await tester.pump(AppMotion.revealDuration ~/ 3);
    await tester.tap(find.byKey(const ValueKey('hub-tile-recordSale')), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isNotEmpty);
    await tester.pumpAndSettle();
  }, skip: _skip);

  testWidgets('held (a return to Home): there at the first frame, no animation', (tester) async {
    await _pump(tester, phoneHomeHarness(gate: _gate(ValueNotifier(true))));
    expect(find.byKey(_panel), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  }, skip: _skip);

  testWidgets('reduced motion: instant', (tester) async {
    final answered = ValueNotifier(false);
    await _pump(tester, phoneHomeHarness(gate: _gate(answered)), still: true);
    answered.value = true;
    await tester.pump();
    expect(find.byKey(_panel), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  }, skip: _skip);

  group('(6) the room under the second row', () {
    testWidgets('with a bottom inset: more padding than without; Home still fits', (tester) async {
      Future<double> panelBottomRoom(EdgeInsets inset) async {
        await pumpAtSize(tester,
            size: const Size(390, 844),
            screen: phoneHomeHarness(charts: HarnessCharts().build()),
            wrap: (app) => MediaQuery(data: MediaQueryData(size: const Size(390, 844), padding: inset, viewPadding: inset), child: app));
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(_panel));
        return HomeActionPanel.collapsedHeightOf(context);
      }

      final without = await panelBottomRoom(EdgeInsets.zero);
      final withInset = await panelBottomRoom(const EdgeInsets.only(bottom: 24));
      expect(withInset - without, 24 + HomePanelMetrics.insetExtraPadding);
      expect(HomePanelMetrics.insetExtraPadding, inInclusiveRange(4, 8));
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first);
      expect(scroll.position.maxScrollExtent, 0);
    }, skip: _skip);
  });
}
