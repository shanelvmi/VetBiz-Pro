import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/auth_panel.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';

import 'helpers/login_harness.dart';

// AN5, written before the change (the owner's review of the AN4 login page):
// the right card's heading "Sign in to your account" with a subtext line,
// both cards' sentences drawn by AuthPanelHeading on one horizontal line;
// the circle icons crisp in Dark (at least 4.5:1 on the circle's effective
// fill, the glow weaker than Light's), Light exactly as before.
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

const _title = 'Sign in to your account';
const _subtitle = 'Use your email and password.';

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

Finder _inHeading(Finder text) => find.ancestor(of: text, matching: find.byType(AuthPanelHeading));

BoxDecoration _circle(WidgetTester tester, Key heading) => tester
    .widgetList<Container>(find.descendant(of: find.byKey(heading), matching: find.byType(Container)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.shape == BoxShape.circle);

Color _icon(WidgetTester tester, Key heading) => tester.widget<Icon>(find.descendant(of: find.byKey(heading), matching: find.byType(Icon))).color!;

void main() {
  for (final width in [1200.0, 1024.0]) {
    testWidgets('$width: "Sign in to your account" on one line, its subtext on the welcome sentence\'s line', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: width);
      final row = find.byKey(LoginScreen.welcomeBackRowKey);
      final title = find.descendant(of: row, matching: find.text(_title));
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(find.text('Welcome back'), findsNothing);
      final sub = find.text(_subtitle);
      final line = find.text(_en.updates_welcomeLine);
      expect(_inHeading(sub), findsOneWidget, reason: 'the subtext is the heading widget\'s');
      expect(_inHeading(line), findsOneWidget, reason: 'and so is the welcome sentence');
      expect(_rect(tester, sub).top, closeTo(_rect(tester, line).top, 1));
      expect(_rect(tester, sub).top, greaterThan(_rect(tester, title).bottom));
      for (final f in [sub, line]) {
        final style = tester.widget<Text>(f).style!;
        expect(style.fontSize, AppFontSize.f14);
        expect(style.color, AppColors.fromTheme(AppColorTheme.pasture).textSecondary);
      }
      // AN4's: the same height, the headings on one line.
      expect(_rect(tester, find.byKey(UpdatesCard.surfaceKey)).height, closeTo(_rect(tester, find.byKey(LoginScreen.loginCardKey)).height, 1));
      expect(_rect(tester, find.byKey(UpdatesCard.welcomeHeadingKey)).top, closeTo(_rect(tester, row).top, 1));
      expect(tester.takeException(), isNull);
    }, skip: _skip);
  }

  testWidgets('Kiswahili, 1200: the heading and its subtext, on the welcome sentence\'s line', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(3), locale: const Locale('sw'));
    expect(find.text('Ingia kwenye akaunti yako'), findsOneWidget);
    final sub = find.text('Tumia barua pepe na nenosiri lako.');
    expect(_rect(tester, sub).top, closeTo(_rect(tester, find.text(_sw.updates_welcomeLine)).top, 1));
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  testWidgets('390: the heading and its subtext on the phone too', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 390, height: 2400);
    expect(find.descendant(of: find.byKey(LoginScreen.welcomeBackRowKey), matching: find.text(_title)), findsOneWidget);
    expect(find.descendant(of: find.byKey(LoginScreen.welcomeBackRowKey), matching: find.text(_subtitle)), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name}: both circle icons at 4.5:1 or more on the circle\'s effective fill', (tester) async {
        await pumpLogin(tester, await dbWithUpdates(1), theme: theme, brightness: brightness);
        final c = AppColors.fromTheme(theme, brightness: brightness);
        for (final key in [LoginScreen.welcomeBackRowKey, UpdatesCard.welcomeHeadingKey]) {
          final fill = ColorMath.composite(_circle(tester, key).color!, c.surface);
          expect(ColorMath.contrast(_icon(tester, key), fill), greaterThanOrEqualTo(4.5), reason: '$key');
          // Light does not change by one value.
          if (brightness == Brightness.light) expect(_icon(tester, key), c.primary);
        }
      }, skip: _skip);
    }
  }

  for (final theme in [AppColorTheme.pasture, AppColorTheme.ledger]) {
    testWidgets('${theme.id}: the Dark glow is weaker than the Light glow; Light\'s exactly as before', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), theme: theme);
      final light = _circle(tester, LoginScreen.welcomeBackRowKey).boxShadow!;
      final glow = AppColors.fromTheme(theme).brandTealGlow;
      expect(light, [BoxShadow(color: glow.withValues(alpha: 0.5), blurRadius: 14)]);
      await pumpLogin(tester, await dbWithUpdates(1), theme: theme, brightness: Brightness.dark);
      final dark = _circle(tester, LoginScreen.welcomeBackRowKey).boxShadow ?? const <BoxShadow>[];
      if (dark.isNotEmpty) {
        expect(dark.single.blurRadius, lessThan(light.single.blurRadius));
        expect(dark.single.color.a, lessThan(light.single.color.a));
      }
    }, skip: _skip);
  }
}
