import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/updates_last_known.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';
import 'package:vetbiz_pro/widgets/updates_parts.dart';

import 'helpers/login_harness.dart';

// AN4, written before the page changed: on wide windows the Updates are a
// card of their own (welcome note, label, the 16:9 frame, the controls at its
// bottom) beside the login card, both the same height with their headings on
// one line; on phones the welcome note is not shown and the cards stack; with
// nothing to show the login card stands centred alone; no grey panel behind
// the login card; a softer page frame shadow.
const _skip = true;
// Unskipped with its commit.
const _skipShadow = false;

final _en = lookupAppLocalizations(const Locale('en'));

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  for (final width in [1200.0, 1024.0]) {
    testWidgets('$width: two cards side by side, the same height, the headings on one line', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: width);
      final left = _rect(tester, UpdatesCard.surfaceKey);
      final login = _rect(tester, LoginScreen.loginCardKey);
      expect(left.right, lessThan(login.left), reason: 'side by side');
      expect(left.height, closeTo(login.height, 1));
      expect(left.top, closeTo(login.top, 1));
      expect(find.text(_en.updates_welcomeTitle(AppInfo.name)), findsOneWidget);
      expect(find.text(_en.updates_welcomeLine), findsOneWidget);
      expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
      expect(
        _rect(tester, UpdatesCard.welcomeHeadingKey).top,
        closeTo(_rect(tester, LoginScreen.welcomeBackRowKey).top, 1),
      );
      // The controls at the card's bottom, the frame inset in it.
      final frame = _rect(tester, UpdatesSlides.frameKey);
      final dots = tester.getRect(find.byType(UpdatesDots));
      expect(frame.left, greaterThan(left.left));
      expect(frame.right, lessThan(left.right));
      expect(left.bottom - dots.bottom, lessThan(40), reason: 'pinned at the bottom');
    }, skip: _skip);
  }

  testWidgets('the left card has the login card\'s surface, radius, border and shadow, but no accent line', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1));
    final left = tester.widget<Container>(find.byKey(UpdatesCard.surfaceKey)).decoration! as BoxDecoration;
    final login = tester.widget<Container>(find.byKey(LoginScreen.loginCardKey)).decoration! as BoxDecoration;
    expect(left.color, login.color);
    expect(left.borderRadius, login.borderRadius);
    expect(left.border, login.border);
    expect(left.boxShadow, login.boxShadow);
    final gradients = tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byKey(UpdatesCard.surfaceKey), matching: find.byType(DecoratedBox)))
        .where((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).gradient != null);
    expect(gradients, isEmpty, reason: 'the login card keeps the only accent line');
  }, skip: _skip);

  for (final width in [768.0, 390.0]) {
    testWidgets('$width: no welcome note, the Updates card below the login card', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: width, height: 2400);
      expect(find.byKey(UpdatesCard.welcomeKey), findsNothing);
      expect(find.text(_en.updates_welcomeLine), findsNothing);
      expect(_rect(tester, UpdatesCard.surfaceKey).top, greaterThan(_rect(tester, LoginScreen.loginCardKey).bottom));
      expect(find.text(_en.updates_label), findsOneWidget);
      expect(find.byType(UpdatesDots), findsOneWidget);
    }, skip: _skip);
  }

  for (final width in [1200.0, 1024.0, 768.0, 390.0]) {
    testWidgets('$width: no updates, no Updates card; the login card centred alone', (tester) async {
      await pumpLogin(tester, FakeFirebaseFirestore(), width: width, height: 2400);
      expect(find.byKey(UpdatesCard.surfaceKey), findsNothing);
      expect(find.byKey(UpdatesCard.welcomeKey), findsNothing);
      expect(_rect(tester, LoginScreen.loginCardKey).center.dx, closeTo(_rect(tester, AuthCard.surfaceKey).center.dx, 1));
    }, skip: _skip);
  }

  for (final width in [360.0, 390.0, 768.0, 1024.0, 1200.0]) {
    testWidgets('$width: the slide frame stays 16:9', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: width, height: 2400);
      final size = _rect(tester, UpdatesSlides.frameKey).size;
      expect(size.width / size.height, closeTo(AppLimits.posterAspectRatio, 0.01));
    }, skip: _skip);
  }

  testWidgets('no grey panel: no ancestor of the login card is tinted surfaceMuted or divider, or a gradient', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpLogin(tester, await dbWithUpdates(1), brightness: brightness);
      final c = AppColors.fromTheme(AppColorTheme.pasture, brightness: brightness);
      final cardContext = tester.element(find.byKey(LoginScreen.loginCardKey));
      cardContext.visitAncestorElements((e) {
        final w = e.widget;
        final decoration = w is DecoratedBox ? w.decoration : (w is Container ? w.decoration : null);
        if (decoration is BoxDecoration) {
          expect(decoration.gradient, isNull, reason: '$brightness ${w.runtimeType}');
          expect(decoration.color, isNot(anyOf(c.surfaceMuted, c.divider)), reason: '$brightness ${w.runtimeType}');
        }
        if (w is ColoredBox) expect(w.color, isNot(anyOf(c.surfaceMuted, c.divider)));
        return w.key != AuthCard.surfaceKey;
      });
    }
  }, skip: _skip);

  testWidgets('the page frame\'s shadow is about half as strong (blur 20, a fifth of the shadow role)', (tester) async {
    await pumpLogin(tester, FakeFirebaseFirestore());
    final c = AppColors.fromTheme(AppColorTheme.pasture);
    final shadow = (tester.widget<Container>(find.byKey(AuthCard.surfaceKey)).decoration! as BoxDecoration).boxShadow!.single;
    expect(shadow.blurRadius, lessThanOrEqualTo(20));
    expect(shadow.color.a, closeTo(c.shadow.a * 0.2, 0.01));
  }, skip: _skipShadow);

  testWidgets('wide, the last-known state had Updates: the whole left card is kept from the first frame, nothing moves', (tester) async {
    UpdatesLastKnown.instance.record(true);
    await pumpLogin(tester, await dbWithUpdates(1), settle: false);
    expect(find.byKey(UpdatesCarousel.skeletonKey), findsOneWidget);
    expect(find.byKey(UpdatesCard.welcomeKey), findsOneWidget);
    final card = _rect(tester, UpdatesCard.surfaceKey);
    final login = _rect(tester, LoginScreen.loginCardKey);
    await tester.pump();
    await tester.pump();
    expect(find.byType(UpdatesSlides), findsOneWidget);
    expect(_rect(tester, UpdatesCard.surfaceKey), card);
    expect(_rect(tester, LoginScreen.loginCardKey), login);
  }, skip: _skip);

  testWidgets('no overflow at 360, 390, 768, 1024 and 1200: Light, Dark, Kiswahili; none, one, several; a very long welcome line', (tester) async {
    final dbs = [for (final n in [0, 1, 3]) await dbWithUpdates(n)];
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1200.0]) {
      for (final db in dbs) {
        for (final (brightness, locale) in const [
          (Brightness.light, Locale('en')),
          (Brightness.dark, Locale('en')),
          (Brightness.light, Locale('sw')),
        ]) {
          await pumpLogin(tester, db, width: width, brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width $brightness $locale');
        }
      }
      await pumpLogin(tester, dbs.last, width: width, longWelcome: true);
      expect(tester.takeException(), isNull, reason: '$width long welcome');
      if (width >= 1024) {
        expect(_rect(tester, UpdatesCard.surfaceKey).height, closeTo(_rect(tester, LoginScreen.loginCardKey).height, 1));
      }
    }
  }, skip: _skip);
}
