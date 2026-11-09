// RV1 (docs/design/screen_reveal.md section 6): Home adopts ScreenReveal.
// The phone Home and the wide dashboard's group (the card grid and the lower
// panels, as dashboard_screen.dart builds them; the dashboard itself cannot
// be built in a test) at every size and look: no overflow, the skeleton has
// the content's layout (the same rects), Needs attention's late slot, and the
// loaded layout unchanged by the reveal wrappers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/sales_revenue_chart.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';
import 'helpers/wide_dashboard_group.dart';

// The phone Home and the wide group are adopted in separate commits.
const _skipPhone = false;
const _skipWide = false;

const _wideSizes = [
  MatrixSize('768x1024', Size(768, 1024)),
  MatrixSize('1024x768', Size(1024, 768)),
  MatrixSize('1200x800', Size(1200, 800)),
];

RevealGate _pendingGate(ValueNotifier<bool> answered) =>
    RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);

/// The rects of those of [types] that are built now (a lazy list builds only
/// what is near the screen), one each.
Map<Type, Rect> _rects(WidgetTester tester, List<Type> types) => {
      for (final t in types)
        if (find.byType(t).evaluate().isNotEmpty) t: tester.getRect(find.byType(t)),
    };

void main() {
  setUpAll(loadRealFont);

  group('the phone Home', () {
    for (final s in ph4PhoneSizes) {
      for (final look in MatrixLook.values) {
        final where = matrixCase(s, look);
        testWidgets('$where: the skeleton has the content\'s layout, no overflow either way', (tester) async {
          final answered = ValueNotifier(false);
          final gate = _pendingGate(answered);
          addTearDown(gate.dispose);
          await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate), size: s.size, look: look);
          expect(find.byType(SkeletonPulse), findsWidgets, reason: 'the skeleton at once');
          await checkCase(tester, phone: true, where: '$where skeleton');
          // UI5: the card and the attention strip; HUB1: the action panel (it
          // is not part of the reveal: the same in both).
          const slots = [TodayCard, AttentionStrip, HomeActionPanel];
          final skeleton = _rects(tester, slots);
          expect(skeleton.keys, contains(TodayCard));
          answered.value = true;
          await tester.pumpAndSettle();
          expect(find.byType(SkeletonPulse), findsNothing);
          expect(_rects(tester, slots), skeleton, reason: where);
          await checkCase(tester, phone: true, where: '$where content');
        }, skip: _skipPhone);
      }
    }

    testWidgets('a repeat visit (everything answered): the content at once, no skeleton', (tester) async {
      final gate = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(true), (v) => v)]);
      addTearDown(gate.dispose);
      await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate), size: const Size(390, 844));
      expect(find.byType(SkeletonPulse), findsNothing);
      expect(find.byType(TodayCard), findsOneWidget);
    }, skip: _skipPhone);

    // UI5: the strip sits under the card, its slot reserved at the strip's
    // height, so nothing moves when it fills (HUB1: the panel is docked
    // apart, over Home's bottom).
    testWidgets('Needs attention: a late slot under the card that keeps its place, then fills without moving the rest',
        (tester) async {
      final gate = RevealGate(primary: const []);
      addTearDown(gate.dispose);
      await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate, attentionReady: false), size: const Size(390, 1400));
      expect(find.byType(AttentionStrip), findsNothing);
      final slot = tester.getRect(find.byType(LateSlot));
      expect(slot.height, PhoneHomeMetrics.attentionStripHeight);
      const above = [TodayCard, HomeActionPanel];
      final before = _rects(tester, above);
      await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate), size: const Size(390, 1400));
      await tester.pumpAndSettle();
      expect(find.byType(AttentionStrip), findsOneWidget);
      expect(tester.getRect(find.byType(LateSlot)).top, slot.top);
      expect(_rects(tester, above), before);
    }, skip: _skipPhone);

    testWidgets('Needs attention answered with nothing: not drawn', (tester) async {
      final gate = RevealGate(primary: const []);
      addTearDown(gate.dispose);
      await pumpAtSize(
        tester,
        screen: phoneHomeHarness(gate: gate, attention: const []),
        size: const Size(390, 844),
      );
      expect(find.byType(LateSlot), findsNothing);
      expect(find.byType(AttentionStrip), findsNothing);
    }, skip: _skipPhone);

    testWidgets('the loaded Home lays out exactly as before RV1', (tester) async {
      final gate = RevealGate(primary: const []);
      addTearDown(gate.dispose);
      await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate), size: const Size(390, 844));
      final revealed = treeFingerprint(tester, find.byType(Scaffold), stripReveal: true);
      await pumpAtSize(tester, screen: phoneHomeHarness(), size: const Size(390, 844));
      expect(treeFingerprint(tester, find.byType(Scaffold), stripReveal: true), revealed);
    }, skip: _skipPhone);
  });

  group('the wide dashboard group', () {
    for (final s in _wideSizes) {
      for (final look in MatrixLook.values) {
        final where = matrixCase(s, look);
        testWidgets('$where: the skeleton has the content\'s layout, no overflow either way', (tester) async {
          final answered = ValueNotifier(false);
          final gate = _pendingGate(answered);
          addTearDown(gate.dispose);
          final feed = StreamController<List<LogDoc>>.broadcast();
          addTearDown(feed.close);
          await pumpAtSize(
            tester,
            screen: wideDashboardGroup(gate, wide: s.size.width >= AppBreakpoints.expanded, feed: feed.stream),
            size: s.size,
            look: look,
          );
          await checkCase(tester, phone: false, where: '$where skeleton');
          const slots = [GridView, TodayGlanceStrip, SalesRevenueChart, RecentActivityFeed, DashboardLowerPanels];
          final skeleton = _rects(tester, slots);
          answered.value = true;
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(SkeletonOf), findsNothing);
          expect(_rects(tester, slots), skeleton, reason: where);
          await checkCase(tester, phone: false, where: '$where content');
        }, skip: _skipWide);
      }
    }

    testWidgets('the skeleton never starts the feed\'s stream', (tester) async {
      var listens = 0;
      final feed = StreamController<List<LogDoc>>.broadcast(onListen: () => listens++);
      addTearDown(feed.close);
      final answered = ValueNotifier(false);
      final gate = _pendingGate(answered);
      addTearDown(gate.dispose);
      await pumpAtSize(tester, screen: wideDashboardGroup(gate, wide: true, feed: feed.stream), size: const Size(1200, 800));
      expect(listens, 1, reason: 'the content\'s own feed, built offstage, and nothing else');
      // The gate's wait and the feed's first-answer wait run out.
      await tester.pump(const Duration(seconds: 16));
    }, skip: _skipWide);

    for (final s in _wideSizes) {
      testWidgets('${s.label}: the loaded group lays out exactly as without the reveal', (tester) async {
        final gate = RevealGate(primary: const []);
        addTearDown(gate.dispose);
        final wide = s.size.width >= AppBreakpoints.expanded;
        await pumpAtSize(tester, screen: wideDashboardGroup(gate, wide: wide), size: s.size);
        final revealed = treeFingerprint(tester, find.byType(SingleChildScrollView), stripReveal: true);
        final group = tester.widget<ScreenReveal>(find.byType(ScreenReveal)).child;
        await pumpAtSize(
          tester,
          screen: withRobotoText(Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.s16), child: group))),
          size: s.size,
        );
        expect(treeFingerprint(tester, find.byType(SingleChildScrollView), stripReveal: true), revealed);
      }, skip: _skipWide);
    }
  });
}
