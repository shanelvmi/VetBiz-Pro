// HUB2 (3) and (4): Home's chart region fills the free height between the
// strip (or the card) and the action panel: at 360x740, 390x844 and 412x915
// its bottom meets the panel's top less the page padding and Home does not
// scroll; on 360x640 there is less than the minimum, so it is not drawn and
// the card and the strip are intact; the minimum and maximum rule; the
// reveal skeleton has the content's rects; and the size matrix (four themes,
// Light and Dark, Kiswahili, text 1.3, 8-digit amounts, a very long product
// name) with no overflow and 48 px targets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/screens/dashboard/home_fill_layout.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _region = ValueKey('phone-home-charts');

Future<void> _pump(WidgetTester tester, Size size,
    {List<AttentionItem> attention = ph4SomeAttention, MatrixLook look = MatrixLook.light}) async {
  await pumpAtSize(tester,
      screen: phoneHomeHarness(charts: HarnessCharts().build(), attention: attention), size: size, look: look);
  await tester.pumpAndSettle();
}

double _maxScroll(WidgetTester tester) =>
    tester
        .state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first)
        .position
        .maxScrollExtent;

void main() {
  group('the region fills the free height', () {
    for (final s in const [Size(360, 740), Size(390, 844), Size(412, 915)]) {
      testWidgets('${s.width.toInt()}x${s.height.toInt()}: down to the panel, no scrolling', (tester) async {
        await _pump(tester, s);
        final region = tester.getRect(find.byType(HomeChartCarousel));
        expect(region.bottom, closeTo(hubPanelTop(tester) - PhoneHomeMetrics.pagePadding, 0.5));
        expect(region.height, inInclusiveRange(HomeChartMetrics.minHeight, HomeChartMetrics.maxHeight));
        expect(region.top, closeTo(tester.getRect(find.byType(AttentionStrip)).bottom + HomeChartMetrics.gap, 0.5));
        expect(_maxScroll(tester), 0);
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }

    testWidgets('without the strip it starts under the card; taller than the maximum it stops there',
        (tester) async {
      await _pump(tester, const Size(390, 844), attention: const []);
      var region = tester.getRect(find.byType(HomeChartCarousel));
      expect(region.top, closeTo(tester.getRect(find.byType(TodayCard)).bottom + HomeChartMetrics.gap, 0.5));
      expect(region.bottom, closeTo(hubPanelTop(tester) - PhoneHomeMetrics.pagePadding, 0.5));
      await _pump(tester, const Size(412, 915), attention: const []);
      region = tester.getRect(find.byType(HomeChartCarousel));
      expect(region.height, HomeChartMetrics.maxHeight);
      expect(_maxScroll(tester), 0);
    }, skip: _skip);

    testWidgets('360x640: no room for the minimum, so no carousel; the card and the strip intact', (tester) async {
      await _pump(tester, const Size(360, 640));
      expect(find.byType(HomeChartCarousel), findsNothing);
      final panelTop = hubPanelTop(tester);
      expect(tester.getRect(find.byType(AttentionStrip)).bottom, lessThanOrEqualTo(panelTop));
      await _pump(tester, const Size(390, 844));
      final card = tester.getSize(find.byType(TodayCard));
      await _pump(tester, const Size(360, 640));
      expect(tester.getSize(find.byType(TodayCard)).height, card.height, reason: 'the card never shrinks');
    }, skip: _skip);
  });

  group('the minimum and maximum rule', () {
    Future<double?> region(WidgetTester tester, double viewport) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: HomeFillLayout(
            viewportHeight: viewport,
            minHeight: HomeChartMetrics.minHeight,
            maxHeight: HomeChartMetrics.maxHeight,
            gap: HomeChartMetrics.gap,
            top: const SizedBox(height: 100),
            fill: LayoutBuilder(
              builder: (context, box) => box.maxHeight < HomeChartMetrics.minHeight
                  ? const SizedBox.shrink()
                  : const SizedBox.expand(key: _region),
            ),
          ),
        ),
      ));
      return find.byKey(_region).evaluate().isEmpty ? null : tester.getSize(find.byKey(_region)).height;
    }

    testWidgets('under the minimum: none; at it: the minimum; above the maximum: the maximum', (tester) async {
      const above = 100 + HomeChartMetrics.gap;
      expect(await region(tester, above + HomeChartMetrics.minHeight - 1), isNull);
      expect(await region(tester, above + HomeChartMetrics.minHeight), HomeChartMetrics.minHeight);
      expect(await region(tester, above + 200), 200);
      expect(await region(tester, above + HomeChartMetrics.maxHeight + 100), HomeChartMetrics.maxHeight);
    }, skip: _skip);
  });

  testWidgets('the reveal skeleton has the content\'s rects (card, strip, chart region)', (tester) async {
    for (final s in const [Size(360, 740), Size(390, 844), Size(412, 915)]) {
      final answered = ValueNotifier(false);
      final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
      await pumpAtSize(tester, screen: phoneHomeHarness(gate: gate, charts: HarnessCharts().build()), size: s);
      List<Rect> rects() => [
            tester.getRect(find.byType(TodayCard)),
            tester.getRect(find.byType(AttentionStrip)),
            tester.getRect(find.byKey(_region)),
          ];
      final skeleton = rects();
      answered.value = true;
      await tester.pumpAndSettle();
      expect(rects(), skeleton, reason: '$s');
      gate.dispose();
    }
  }, skip: _skip);

  group('size matrix', () {
    for (final s in const [Size(360, 740), Size(390, 844), Size(412, 915), Size(360, 640)]) {
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          final where = '${s.width.toInt()}x${s.height.toInt()} ${theme.id} ${look.name}';
          testWidgets(where, (tester) async {
            await pumpAtSize(tester,
                screen: phoneHomeHarness(charts: HarnessCharts().build()), size: s, look: look, colorTheme: theme);
            await tester.pumpAndSettle();
            await checkCase(tester, phone: true, where: where);
          }, skip: _skip);
        }
      }
    }
    testWidgets('360x740 Kiswahili, every page', (tester) async {
      await _pump(tester, const Size(360, 740), look: MatrixLook.kiswahili);
      for (var i = 0; i < 2; i++) {
        await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }
      await checkCase(tester, phone: true, where: '360x740 kiswahili');
    }, skip: _skip);
    testWidgets(matrixTextScaleCase, (tester) async {
      await pumpAtSize(tester,
          screen: phoneHomeHarness(charts: HarnessCharts().build()),
          size: const Size(360, 740),
          textScale: matrixLargeTextScale);
      await tester.pumpAndSettle();
      await checkCase(tester, phone: true, where: matrixTextScaleCase);
    }, skip: _skip);
  });
}
