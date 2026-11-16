// POL2 Step 2, then POL2b (owner, option 2): the phone Today card on one solid
// deep tone of the theme (brandGradientEnd): no gradient, no glow, no shadow;
// in Dark a hairline in the border role keeps it distinct from the page. The
// same content (the switch, the range, the amount, the eye, the change chip,
// the figures), the same layout and height (pol2-today-card fingerprints).
// The change chip is the one StatusPill in its onBrand variant: a soft white
// fill, the word and the arrow in onBrandSurface at 4.5 against that fill
// over the deep tone, in every theme, Light and Dark; its state is kept (up
// success, down danger, the same or new neutral). Text scale 1.3 at 360 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/status_pill.dart';

import 'pol2_fingerprints_test.dart' show pol2PhoneSizes, pumpTodayCard;

AppColors _colors(WidgetTester tester) => Theme.of(tester.element(find.byType(TodayCard))).extension<AppColors>()!;

BoxDecoration _card(WidgetTester tester) => tester
    .widget<DecoratedBox>(find.descendant(of: find.byType(TodayCard), matching: find.byType(DecoratedBox)).first)
    .decoration as BoxDecoration;

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
      testWidgets('${size.width.toInt()}x${size.height.toInt()} ${brightness.name}: the solid deep tone, the content and the eye kept',
          (tester) async {
        await pumpTodayCard(tester, size, brightness: brightness);
        expect(tester.takeException(), isNull);
        final colors = _colors(tester);
        final d = _card(tester);
        expect(d.color, colors.brandGradientEnd);
        expect(d.border == null, brightness == Brightness.light, reason: 'a hairline in Dark only');
        _noGradientOrShadow(tester);
        expect(find.byKey(const ValueKey('home-card-amount-row')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-card-stats')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-period-chip')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-delta')), findsOneWidget);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget, reason: 'the eye');
      });
    }
  }

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name}: the chip\'s word and arrow at 4.5 on its soft white over the deep tone',
          (tester) async {
        await pumpTodayCard(tester, const Size(390, 844), brightness: brightness, theme: theme);
        final colors = _colors(tester);
        final pill = tester.widget<StatusPill>(find.byType(StatusPill));
        expect(pill.onBrand, isTrue, reason: 'the one StatusPill, its onBrand variant');
        expect(pill.label, 'up 12% vs yesterday');
        final under = Color.alphaBlend(colors.onBrandSurface.withValues(alpha: PolishMetrics.onBrandPillAlpha), colors.brandGradientEnd);
        final word = tester.widget<Text>(find.descendant(of: find.byType(StatusPill), matching: find.byType(Text)));
        final arrow = tester.widget<Icon>(find.descendant(of: find.byType(StatusPill), matching: find.byType(Icon)));
        expect(ColorMath.contrast(word.style!.color!, under), greaterThanOrEqualTo(4.5), reason: 'the word');
        expect(ColorMath.contrast(arrow.color!, under), greaterThanOrEqualTo(4.5), reason: 'the arrow');
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
      expect(pill.onBrand, isTrue);
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
