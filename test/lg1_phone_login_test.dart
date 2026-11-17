import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/auth_background.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_entrance.dart';
import 'package:vetbiz_pro/widgets/auth_language_switch.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'helpers/login_harness.dart';

// LG1, written before the change: on phones the login is ONE flat page on the
// theme's background: a compact brand row (the VB mark, the app name, the
// theme toggle; no bar behind it), the form directly on the page (no card,
// no accent line), 52 px filled fields with a 14 px radius, a 52 px Sign in
// button, then the Updates as a flat section (no card) and the footer. The
// form fits without scrolling on common phones; the page enters once, as one.
// Tablets and wide windows: test/lg1_wide_login_unchanged_test.dart.
// UI8 (owner) changed three things, so these checks follow: the brand row is
// now a tinted header (AuthPhoneHeader; test/ui8_phone_login_test.dart),
// the page has no Updates and no footer, and the fields' radius is 16.
const _page = ValueKey<String>('login-phone-page');
const _brand = ValueKey<String>('login-phone-brand');
const _button = ValueKey<String>('login-sign-in-button');

final _en = lookupAppLocalizations(const Locale('en'));

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f.first);

/// Past the page's one entrance; well before the first auto-advance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A box with something drawn: a fill, a border, a shadow or a gradient.
bool _decorated(Widget w) {
  final d = switch (w) {
    Container(:final decoration) => decoration,
    DecoratedBox(:final decoration) => decoration,
    _ => null,
  };
  return d is BoxDecoration && (d.color != null || d.border != null || d.boxShadow != null || d.gradient != null);
}

/// The widgets between [f] and the page column, [f] included.
List<Widget> _upToPage(WidgetTester tester, Finder f) {
  final out = <Widget>[tester.widget(f)];
  tester.element(f).visitAncestorElements((a) {
    if (a.widget.key == _page) return false;
    out.add(a.widget);
    return true;
  });
  return out;
}

bool _inside(Element e, bool Function(Widget) test) {
  var found = false;
  e.visitAncestorElements((a) {
    if (test(a.widget)) found = true;
    return !found;
  });
  return found;
}

void main() {
  testWidgets('390: one flat page: no frame, no header bar, no cards, no accent line', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(3), width: 390, height: 844);
    await _settle(tester);
    expect(find.byKey(_page), findsOneWidget);
    expect(find.byType(AuthCard), findsNothing);
    expect(find.byType(UpdatesCard), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(UpdatesCard.welcomeKey), findsNothing);
    final form = find.byKey(LoginScreen.loginCardKey);
    expect(_upToPage(tester, form).where(_decorated), isEmpty, reason: 'nothing drawn around the form');
    // UI8: no Updates on a phone.
    expect(find.byType(UpdatesCarousel), findsNothing);
    expect(find.text(_en.updates_label), findsNothing);
    // POL3: no gradient at all (the Sign in button's own was the last).
    final gradients = find.byWidgetPredicate((w) {
      final d = w is Container ? w.decoration : (w is DecoratedBox ? w.decoration : null);
      return d is BoxDecoration && d.gradient != null;
    });
    expect(gradients, findsNothing);
    // The brand (UI8: the tinted header): the mark, the name and the toggle,
    // at the page's top.
    final brand = find.byKey(_brand);
    expect(find.descendant(of: brand, matching: find.text(AppInfo.logoMark)), findsOneWidget);
    expect(find.descendant(of: brand, matching: find.text(AppInfo.name)), findsOneWidget);
    expect(find.descendant(of: brand, matching: find.byType(AuthThemeToggle)), findsOneWidget);
    expect(_rect(tester, find.byType(AuthThemeToggle)).height, greaterThanOrEqualTo(48));
    expect(_rect(tester, brand).top, lessThan(32));
    // The column: at most 420 wide, 24 px in from the sides.
    expect(_rect(tester, form).left, 24);
    expect(_rect(tester, form).width, 390 - 48);
  });

  testWidgets('560 wide (still a phone): the column keeps 420 at most', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 560, height: 900);
    await _settle(tester);
    expect(_rect(tester, find.byKey(LoginScreen.loginCardKey)).width, lessThanOrEqualTo(420 - 48));
  });

  testWidgets('the fields: filled, 52 high, a 1 px border, 16 px radius (UI8; was 14), leading icons; the button 52 high', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 390, height: 844);
    await _settle(tester);
    final colors = tester.element(find.byType(LoginScreen)).colors;
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(_rect(tester, fields.at(i)).height, 52);
      final d = tester.widget<TextField>(fields.at(i)).decoration!;
      expect(d.filled, isTrue);
      expect(d.fillColor, colors.surfaceMuted);
      final border = d.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.width, 1);
      expect(border.borderRadius, BorderRadius.circular(16));
      expect(d.prefixIcon, isNotNull);
    }
    expect(tester.widget<TextField>(fields.at(1)).decoration!.suffixIcon, isNotNull, reason: 'the eye');
    expect(_rect(tester, find.byKey(_button)).height, 52);
    expect(_rect(tester, find.byKey(_button)).width, 390 - 48);
  });

  for (final size in const [Size(390, 844), Size(412, 915), Size(360, 740)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('$at: the form is on screen without scrolling', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(3), width: size.width, height: size.height);
      await _settle(tester);
      final screen = Offset.zero & size;
      bool shown(Finder f) => screen.contains(_rect(tester, f).topLeft) && _rect(tester, f).bottom <= size.height;
      expect(shown(find.byKey(_button)), isTrue, reason: 'the Sign in button');
      if (size.width > 360) {
        expect(shown(find.text(_en.login_signInTitle)), isTrue);
        expect(shown(find.byType(TextField).first), isTrue);
        expect(shown(find.byType(TextField).last), isTrue);
        expect(shown(find.text(_en.login_rememberMe)), isTrue);
        expect(shown(find.text(_en.login_forgotPassword)), isTrue);
      }
    });
  }

  testWidgets('the background, the fields and the texts: contrast in all four themes, Light and Dark', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final where = '${theme.id} ${brightness.name}';
        await pumpLogin(tester, await dbWithUpdates(1), width: 390, height: 844, theme: theme, brightness: brightness);
        await _settle(tester);
        final colors = tester.element(find.byType(LoginScreen)).colors;
        final page = find.descendant(of: find.byType(AuthBackground), matching: find.byType(ColoredBox));
        expect(tester.widget<ColoredBox>(page).color, colors.background, reason: where);
        final field = tester.widget<TextField>(find.byType(TextField).first).decoration!;
        final border = (field.enabledBorder! as OutlineInputBorder).borderSide.color;
        expect(ColorMath.contrast(border, colors.background), greaterThanOrEqualTo(3), reason: '$where field border');
        final areas = [find.byKey(_brand), find.byKey(LoginScreen.loginCardKey)];
        for (final area in areas) {
          // UI8: the brand is on the header's tint (authFooterFill).
          final page = area == areas.first ? colors.authFooterFill : colors.background;
          for (final e in find.descendant(of: area, matching: find.byType(RichText)).evaluate()) {
            if (_inside(e, (w) => w.key == _button || w is Icon)) continue;
            // EN | SW on their pill: test/ui8_header_test.dart.
            if (_inside(e, (w) => w is AuthLanguageSwitch)) continue;
            final color = (e.widget as RichText).text.style?.color;
            if (color == null) continue;
            final behind = _inside(e, (w) => w is TextField) ? colors.surfaceMuted : page;
            final text = (e.widget as RichText).text.toPlainText();
            if (text == AppInfo.logoMark) continue; // on its own mark, checked below
            expect(ColorMath.contrast(color, behind), greaterThanOrEqualTo(4.5), reason: '$where "$text"');
          }
          for (final e in find.descendant(of: area, matching: find.byType(Icon)).evaluate()) {
            if (_inside(e, (w) => w.key == _button)) continue;
            final color = IconTheme.of(e).color ?? (e.widget as Icon).color;
            final behind = _inside(e, (w) => w is TextField || w is IconButton) ? colors.surfaceMuted : page;
            expect(ColorMath.contrast(color!, behind), greaterThanOrEqualTo(3), reason: '$where icon ${(e.widget as Icon).icon}');
          }
        }
      }
    }
  });

  // UI8: no Updates on a phone, so what the store holds never moves the page.
  testWidgets('none, one, several and loading Updates: no Updates frame, and the page does not move', (tester) async {
    final buttons = <String, Rect>{};
    await pumpLogin(tester, await dbWithUpdates(3), width: 390, height: 844, settle: false, reduceMotion: true);
    buttons['loading'] = _rect(tester, find.byKey(_button));
    await tester.pump();
    await tester.pump();
    buttons['several, after the answer'] = _rect(tester, find.byKey(_button));
    for (final n in [0, 1, 3]) {
      await pumpLogin(tester, n == 0 ? FakeFirebaseFirestore() : await dbWithUpdates(n), width: 390, height: 844, reduceMotion: true);
      expect(find.byType(UpdatesCarousel), findsNothing, reason: '$n');
      buttons['$n'] = _rect(tester, find.byKey(_button));
    }
    for (final MapEntry(:key, :value) in buttons.entries) {
      expect(value, buttons.values.first, reason: key);
    }
  });

  testWidgets('the entrance: the header, then the form, once', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 390, height: 844);
    // UI8: two entrances (the header, then the form, staggered); the page
    // column itself stays put.
    final entrances = find.descendant(of: find.byType(LoginScreen), matching: find.byType(AuthEntrance));
    expect(entrances, findsNWidgets(2));
    expect(find.descendant(of: entrances.last, matching: find.byKey(LoginScreen.loginCardKey)), findsOneWidget);
    double opacity() => tester.widget<FadeTransition>(find.descendant(of: entrances.first, matching: find.byType(FadeTransition)).first).opacity.value;
    expect(opacity(), lessThan(1));
    await _settle(tester);
    expect(opacity(), 1);
    // Not again on a rebuild or a resize.
    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    expect(opacity(), 1);
  });

  testWidgets('the error and the red borders on the phone, as on wide windows', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 390, height: 844);
    await _settle(tester);
    await tester.tap(find.byKey(_button));
    await _settle(tester);
    expect(find.text(_en.login_credentialsTooShort), findsOneWidget);
    final colors = tester.element(find.byType(LoginScreen)).colors;
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      final side = (f.decoration!.enabledBorder! as OutlineInputBorder).borderSide;
      expect(side.color, colors.dangerAccent.withValues(alpha: AppAlpha.a70));
    }
  });

  testWidgets('landscape 740x360: the page scrolls to the button', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(3), width: 740, height: 360);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(_button), 100, scrollable: find.byType(Scrollable).first);
    expect(_rect(tester, find.byKey(_button)).bottom, lessThanOrEqualTo(360));
  });
}
