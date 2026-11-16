// POL2 Step 2: the phone Today card without its gradient. A flat surface
// with a hairline border; the same content (the switch, the range, the
// amount, the eye, the change chip, the figures), the same layout and
// height (pol2-today-card fingerprints); the change chip is the one
// StatusPill in the four states only (up success, down danger, the same or
// new neutral), its arrow and words kept. Phone sizes, Light and Dark, text
// scale 1.3, reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/status_pill.dart';

import 'pol2_fingerprints_test.dart' show pol2PhoneSizes, pumpTodayCard;

AppColors _colors(WidgetTester tester) => Theme.of(tester.element(find.byType(TodayCard))).extension<AppColors>()!;

void _noGradientOrShadow(WidgetTester tester) {
  for (final b in tester.widgetList<DecoratedBox>(find.descendant(of: find.byType(TodayCard), matching: find.byType(DecoratedBox)))) {
    final d = b.decoration;
    if (d is BoxDecoration) {
      expect(d.gradient, isNull);
      expect(d.boxShadow, anyOf(isNull, isEmpty));
    }
  }
}

void main() {
  for (final size in pol2PhoneSizes) {
    for (final brightness in Brightness.values) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} ${brightness.name}: flat, bordered, the content and the eye kept',
          (tester) async {
        await pumpTodayCard(tester, size, brightness: brightness);
        expect(tester.takeException(), isNull);
        final colors = _colors(tester);
        final card = tester.widget<DecoratedBox>(find.descendant(of: find.byType(TodayCard), matching: find.byType(DecoratedBox)).first);
        final d = card.decoration as BoxDecoration;
        expect(d.color, colors.surface);
        expect((d.border! as Border).top.color, colors.border);
        _noGradientOrShadow(tester);
        expect(find.byKey(const ValueKey('home-card-amount-row')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-card-stats')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-period-chip')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-delta')), findsOneWidget);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget, reason: 'the eye');
      });
    }
  }

  for (final (delta, status, words) in [
    (const HomeDelta.change(12), AppStatus.success, 'up 12% vs yesterday'),
    (const HomeDelta.change(-30), AppStatus.danger, 'down 30% vs yesterday'),
    (const HomeDelta.change(0), AppStatus.neutral, null),
    (const HomeDelta.fresh(), AppStatus.neutral, null),
  ]) {
    testWidgets('the change chip for ${delta.percent}: ${status.name}, its words, the chip slot\'s height kept', (tester) async {
      await pumpTodayCard(tester, const Size(390, 844), delta: delta);
      final pill = tester.widget<StatusPill>(find.byType(StatusPill));
      expect(pill.status, status);
      if (words != null) expect(pill.label, words);
      expect(find.descendant(of: find.byType(TodayCard), matching: find.byType(StatusPill)), findsOneWidget, reason: 'the one pill');
      expect(tester.getSize(find.byKey(const ValueKey('home-delta'))).height, HomeCardMetrics.deltaHeight);
    });
  }

  testWidgets('360x640 at text scale 1.3 with reduced motion: no overflow, the chip and the eye stay', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpTodayCard(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-delta')), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
