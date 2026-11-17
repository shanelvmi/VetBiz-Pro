// POL3, the owner's rules on sign-in, register and Platform Admin Promotions
// (tablets and computers; the phone sign-in and register keep their UI8
// look, the Sign in button aside): no gradient, glow or decorative shadow;
// a brand surface is ONE SOLID deep tone (brandGradientEnd) with on-brand
// inks at 4.5:1; the Sign in button is the flat primary with onPrimary ink,
// its hover and pressed states at 4.5:1; the welcome panel's icons and
// circles in the on-brand ink. Every theme, Light and Dark; text scale 1.3
// and narrow widths without overflow; reduced motion.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/platform_admin/promotions_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';

import 'helpers/login_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/register_harness.dart';
import 'helpers/screen_size_matrix.dart' show MatrixLook;
import 'pol3_fingerprints_test.dart' show pumpPromotions;

AppColors _colors(WidgetTester tester, Finder within) => Theme.of(tester.element(within.first)).extension<AppColors>()!;

/// Every BoxDecoration drawn inside [within]: a Container's decoration and
/// foregroundDecoration are each a DecoratedBox, so those are counted once.
List<BoxDecoration> _decorations(WidgetTester tester, Finder within) => [
      for (final b in tester.widgetList<DecoratedBox>(find.descendant(of: within, matching: find.byType(DecoratedBox))))
        if (b.decoration is BoxDecoration) b.decoration as BoxDecoration,
    ];

/// The Containers filled with the deep tone (by color: or decoration).
Iterable<Container> _deepContainers(WidgetTester tester, Finder within, Color deep) => tester
    .widgetList<Container>(find.descendant(of: within, matching: find.byType(Container)))
    .where((w) => w.color == deep || (w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == deep));

void _flat(WidgetTester tester, Finder within) {
  for (final d in _decorations(tester, within)) {
    expect(d.gradient, isNull, reason: 'no gradient');
    expect(d.boxShadow, anyOf(isNull, isEmpty), reason: 'no glow or shadow');
  }
}

/// The Sign in button's fill (its one filled DecoratedBox).
Color _buttonFill(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.descendant(of: find.byKey(LoginScreen.signInButtonKey), matching: find.byType(DecoratedBox)))
    .map((d) => (d.decoration as BoxDecoration).color)
    .whereType<Color>()
    .first;

Color _buttonInk(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(LoginScreen.signInButtonKey), matching: find.byType(Text))).style!.color!;

Future<void> _pause(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // The roles, computed: every theme, Light and Dark.
  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      test('${theme.id} ${brightness.name}: the deep tone\'s inks, the button\'s states, the outlines', () {
        final c = AppColors.fromTheme(theme, brightness: brightness);
        final deep = c.brandGradientEnd;
        double on(Color ink, Color bg) => ColorMath.contrast(ink, bg);
        expect(on(c.onBrandSurface, deep), greaterThanOrEqualTo(4.5), reason: 'the ink');
        expect(on(c.onBrandSurfaceMuted, deep), greaterThanOrEqualTo(4.5), reason: 'the muted ink');
        expect(on(c.onBrandSurface.withValues(alpha: AppAlpha.a85), deep), greaterThanOrEqualTo(4.5), reason: 'the 85% ink');
        // The welcome panel's rocket on its white circle over the deep tone.
        final circle = Color.alphaBlend(c.onBrandSurface.withValues(alpha: AppAlpha.a20), deep);
        expect(on(c.onBrandSurface, circle), greaterThanOrEqualTo(3), reason: 'the icon on its circle');
        // The Log in outline on the panel (interactive: 3:1).
        expect(on(c.onBrandSurface.withValues(alpha: 0.6), deep), greaterThanOrEqualTo(3), reason: 'the Log in outline');
        // The Sign in button: rest, hover, pressed.
        final hover = Color.alphaBlend(c.onPrimary.withValues(alpha: PolishMetrics.buttonHoverAlpha), c.primary);
        final pressed = Color.alphaBlend(c.onPrimary.withValues(alpha: PolishMetrics.buttonPressedAlpha), c.primary);
        for (final (name, fill) in [('rest', c.primary), ('hover', hover), ('pressed', pressed)]) {
          expect(on(c.onPrimary, fill), greaterThanOrEqualTo(4.5), reason: 'the button $name');
          final arrow = Color.alphaBlend(c.onPrimary.withValues(alpha: AppAlpha.a20), fill);
          expect(on(c.onPrimary, arrow), greaterThanOrEqualTo(3), reason: 'the arrow $name');
        }
        // The step line beside the wizard ("Step N of M") on the card.
        expect(on(c.textMuted, c.surface), greaterThanOrEqualTo(4.5), reason: 'the step text');
      });
    }
  }

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      final look = '${theme.id} ${brightness.name}';

      testWidgets('$look: sign-in on a computer is flat, the header the deep tone, the button primary and its states', (tester) async {
        await pumpLogin(tester, await dbWithUpdates(1), width: 1200, height: 800, theme: theme, brightness: brightness);
        await _pause(tester);
        final screen = find.byType(LoginScreen);
        final c = _colors(tester, screen);
        _flat(tester, screen);
        expect(tester.widgetList<ColoredBox>(find.descendant(of: screen, matching: find.byType(ColoredBox))).where((b) => b.color == c.brandGradientEnd),
            isNotEmpty, reason: 'the header bar');
        expect(_buttonFill(tester), c.primary);
        expect(_buttonInk(tester), c.onPrimary);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byKey(LoginScreen.signInButtonKey)));
        await tester.pumpAndSettle();
        final hover = Color.alphaBlend(c.onPrimary.withValues(alpha: PolishMetrics.buttonHoverAlpha), c.primary);
        expect(_buttonFill(tester), hover);
        expect(ColorMath.contrast(_buttonInk(tester), _buttonFill(tester)), greaterThanOrEqualTo(4.5));

        final press = await tester.startGesture(tester.getCenter(find.byKey(LoginScreen.signInButtonKey)));
        // A tap-down is reported once the press timeout has passed.
        await tester.pump(kPressTimeout);
        final pressed = Color.alphaBlend(c.onPrimary.withValues(alpha: PolishMetrics.buttonPressedAlpha), c.primary);
        expect(_buttonFill(tester), pressed);
        expect(ColorMath.contrast(_buttonInk(tester), _buttonFill(tester)), greaterThanOrEqualTo(4.5));
        await press.cancel();
        await tester.pump();
        expect(_buttonFill(tester), hover, reason: 'released: back to hover');
        _flat(tester, screen);
      });

      testWidgets('$look: register on a computer, the welcome panel the deep tone with white icons', (tester) async {
        await pumpRegister(tester, size: const Size(1200, 800), theme: theme, brightness: brightness);
        final screen = find.byType(RegisterScreen);
        final c = _colors(tester, screen);
        _flat(tester, screen);
        final deep = _decorations(tester, screen).where((d) => d.color == c.brandGradientEnd).toList();
        expect(deep, isNotEmpty, reason: 'the welcome panel');
        expect(tester.widgetList<ColoredBox>(find.descendant(of: screen, matching: find.byType(ColoredBox))).where((b) => b.color == c.brandGradientEnd),
            isNotEmpty, reason: 'the header bar');
        // The header and the panel: a hairline in the border role in Dark only.
        final deepBoxes = _deepContainers(tester, screen, c.brandGradientEnd).toList();
        expect(deepBoxes, hasLength(2), reason: 'the header bar and the welcome panel');
        for (final box in deepBoxes) {
          final edge = box.foregroundDecoration as BoxDecoration?;
          expect(edge != null, brightness == Brightness.dark);
          if (edge != null) expect((edge.border! as Border).bottom.color, c.border);
        }
        for (final icon in [Icons.check_circle_outline, Icons.rocket_launch_outlined]) {
          for (final i in tester.widgetList<Icon>(find.descendant(of: screen, matching: find.byIcon(icon)))) {
            expect(i.color, c.onBrandSurface, reason: '$icon');
          }
        }
        await finishRegister(tester);
      });

      testWidgets('$look: register on a tablet, the welcome strip the deep tone with a white circle', (tester) async {
        await pumpRegister(tester, size: const Size(768, 1024), theme: theme, brightness: brightness);
        final screen = find.byType(RegisterScreen);
        final c = _colors(tester, screen);
        _flat(tester, screen);
        expect(_decorations(tester, screen).where((d) => d.color == c.brandGradientEnd), isNotEmpty, reason: 'the strip');
        expect(_decorations(tester, screen).where((d) => d.shape == BoxShape.circle && d.color == c.onBrandSurface.withValues(alpha: AppAlpha.a20)),
            isNotEmpty, reason: 'the white circle');
        await finishRegister(tester);
      });
    }
  }

  for (final look in [MatrixLook.light, MatrixLook.dark]) {
    ph5TestWidgets('Promotions ${look.name}: the "% OFF" badges the deep tone with the on-brand ink, no gradient', (tester) async {
      await pumpPromotions(tester, const Size(1200, 800), look: look);
      final screen = find.byType(PromotionsScreen);
      final c = _colors(tester, screen);
      final badges = _decorations(tester, screen).where((d) => d.color == c.brandGradientEnd).toList();
      expect(badges, hasLength(3), reason: 'one per promotion');
      for (final d in _decorations(tester, screen)) {
        expect(d.gradient, isNull);
      }
      final text = tester.widget<Text>(find.textContaining('OFF').first);
      expect(text.style!.color, c.onBrandSurface);
      expect(ColorMath.contrast(text.style!.color!, c.brandGradientEnd), greaterThanOrEqualTo(4.5));
    });
  }

  group('text scale 1.3, narrow widths', () {
    for (final size in [const Size(768, 1024), const Size(800, 600), const Size(1024, 768)]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('sign-in at $at, Dark: no overflow', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpLogin(tester, await dbWithUpdates(1), width: size.width, height: size.height, brightness: Brightness.dark);
        await _pause(tester);
        expect(tester.takeException(), isNull);
        _flat(tester, find.byType(LoginScreen));
      });

      testWidgets('register at $at: no overflow', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpRegister(tester, size: size);
        expect(tester.takeException(), isNull);
        await finishRegister(tester);
      });
    }
  });

  testWidgets('reduced motion: sign-in on a computer settles with the flat button', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 1200, height: 800, reduceMotion: true);
    await _pause(tester);
    expect(tester.takeException(), isNull);
    final c = _colors(tester, find.byType(LoginScreen));
    expect(_buttonFill(tester), c.primary);
    _flat(tester, find.byType(LoginScreen));
  });

  // The phone sign-in keeps its UI8 look; its button is the same widget,
  // so it is the flat primary too (in Dark the one visible phone change).
  for (final brightness in Brightness.values) {
    testWidgets('phone ${brightness.name}: sign-in flat, the button primary with onPrimary ink', (tester) async {
      await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, brightness: brightness);
      await _pause(tester);
      final screen = find.byType(LoginScreen);
      final c = _colors(tester, screen);
      _flat(tester, screen);
      expect(_buttonFill(tester), c.primary);
      expect(_buttonInk(tester), c.onPrimary);
    });
  }
}
