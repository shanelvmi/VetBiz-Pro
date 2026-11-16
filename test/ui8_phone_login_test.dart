// UI8, written before the change: the sign-in page on a phone. A tinted
// header (the VB. mark in a tile, VetBiz Pro, the tagline; EN | SW,
// Light/Dark and Help at its right), then the form as it was (texts
// unchanged), and no Updates and no footer: the UpdatesCarousel is not
// mounted, so the page reads no Updates. Help opens AuthHelpSheet. With the
// keyboard open the header is one line and Sign in stays on screen.
// Tablets and computers: test/ui8_wide_unchanged_test.dart.
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
import 'package:vetbiz_pro/widgets/auth_entrance.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/auth_language_switch.dart';
import 'package:vetbiz_pro/widgets/auth_phone_header.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'helpers/login_harness.dart';
import 'helpers/real_font.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f.first);

/// Past the page's one entrance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _button = LoginScreen.signInButtonKey;

void main() {
  setUpAll(loadRealFont);

  testWidgets('390x844: the header, the form, and no Updates, no footer', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(3), width: 390, height: 844);
    await _settle(tester);
    final header = find.byKey(LoginScreen.phoneBrandKey);
    expect(tester.widget(header), isA<AuthPhoneHeader>());
    expect(_rect(tester, header).top, 0);
    expect(_rect(tester, header).width, 390, reason: 'edge to edge');
    for (final f in [find.text(AppInfo.logoMark), find.text(AppInfo.name), find.byKey(AuthPhoneHeader.taglineKey)]) {
      expect(find.descendant(of: header, matching: f), findsOneWidget);
    }
    expect(find.descendant(of: header, matching: find.byType(AuthLanguageSwitch)), findsOneWidget);
    expect(find.descendant(of: header, matching: find.byType(AuthThemeToggle)), findsOneWidget);
    expect(find.descendant(of: header, matching: find.byKey(AuthPhoneControls.helpKey)), findsOneWidget);
    expect(find.byType(UpdatesCarousel), findsNothing);
    expect(find.byType(UpdatesCard), findsNothing);
    expect(find.byType(UpdatesSlides), findsNothing);
    expect(find.text(_en.updates_label), findsNothing);
    expect(find.byType(AuthFooter), findsNothing);
    // The form's texts, unchanged and in order, under the header.
    final order = [
      find.text(_en.login_signInTitle),
      find.text(_en.login_signInSubtitle),
      find.text(_en.common_email),
      find.text(_en.common_password),
      find.text(_en.login_rememberMe),
      find.byKey(_button),
      find.text(_en.login_noAccount),
    ];
    var last = _rect(tester, header).bottom;
    for (final f in order) {
      expect(f, findsOneWidget);
      expect(_rect(tester, f).top, greaterThanOrEqualTo(last), reason: '$f');
      last = _rect(tester, f).top;
    }
    expect(find.text(_en.login_forgotPassword), findsOneWidget);
    expect(find.text(_en.login_register), findsOneWidget);
    // The column: 24 px in from the sides, the button its full width.
    expect(_rect(tester, find.byKey(LoginScreen.loginCardKey)).left, 24);
    expect(_rect(tester, find.byKey(_button)).width, 390 - 48);
    expect(_rect(tester, find.byKey(_button)).height, AuthPhoneMetrics.buttonHeight);
  });

  // In Roboto, as on a phone: the square test font is about twice as wide.
  for (final (width, l10n) in [(360.0, _en), (390.0, _en), (412.0, _en), (390.0, _sw), (412.0, _sw)]) {
    testWidgets('$width ${l10n.localeName}: Remember my email at the left, Forgot Password? at the right, one row', (tester) async {
      await pumpLogin(tester, FakeFirebaseFirestore(), width: width, height: 900, locale: Locale(l10n.localeName), realFont: true);
      await _settle(tester);
      final remember = _rect(tester, find.text(l10n.login_rememberMe));
      final forgot = _rect(tester, find.text(l10n.login_forgotPassword));
      expect(forgot.center.dy, closeTo(remember.center.dy, 2));
      expect(forgot.left, greaterThan(remember.right));
      expect(forgot.right, closeTo(width - 24, 1), reason: 'at the right edge of the column');
    });
  }

  // LG1's sizes without a keyboard: the form on screen without scrolling.
  for (final size in const [Size(360, 740), Size(390, 844), Size(412, 915)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('$at: the whole form on screen without scrolling', (tester) async {
      await pumpLogin(tester, FakeFirebaseFirestore(), width: size.width, height: size.height);
      await _settle(tester);
      expect(tester.widget<AuthPhoneHeader>(find.byKey(LoginScreen.phoneBrandKey)).collapsed, isFalse);
      expect(find.byKey(AuthPhoneHeader.taglineKey), findsOneWidget);
      expect(_rect(tester, find.byKey(_button)).bottom, lessThanOrEqualTo(size.height));
      expect(_rect(tester, find.text(_en.login_noAccount)).bottom, lessThanOrEqualTo(size.height));
    });
  }

  // The keyboard opens on the page (as on a phone), with either field focused.
  for (final field in ['email', 'password']) {
    for (final size in const [Size(360, 640), Size(390, 844)]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('$at, keyboard 280, $field focused: the header one line, the field and Sign in on screen', (tester) async {
        await pumpLogin(tester, FakeFirebaseFirestore(), width: size.width, height: size.height);
        await _settle(tester);
        final focused = field == 'email' ? find.byType(TextField).first : find.byType(TextField).last;
        await tester.tap(focused);
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<AuthPhoneHeader>(find.byKey(LoginScreen.phoneBrandKey)).collapsed, isTrue);
        expect(find.byKey(AuthPhoneHeader.taglineKey), findsNothing);
        final visible = Rect.fromLTRB(0, _rect(tester, find.byKey(LoginScreen.phoneBrandKey)).bottom, size.width, size.height - 280);
        final button = _rect(tester, find.byKey(_button));
        final input = _rect(tester, focused);
        expect(button.top, greaterThanOrEqualTo(visible.top), reason: 'button $button, visible $visible');
        expect(button.bottom, lessThanOrEqualTo(visible.bottom), reason: 'button $button, visible $visible');
        expect(input.top, greaterThanOrEqualTo(visible.top), reason: '$field $input, visible $visible');
        // Closed again: the full header is back.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(find.byKey(AuthPhoneHeader.taglineKey), findsOneWidget);
      });
    }
  }

  testWidgets('the fields: filled, 52 high, 16 px radius, a 1 px hairline at 3:1 on the page (LG1)', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final where = '${theme.id} ${brightness.name}';
        await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, theme: theme, brightness: brightness);
        await _settle(tester);
        final colors = tester.element(find.byType(LoginScreen)).colors;
        for (final field in find.byType(TextField).evaluate()) {
          expect(tester.getSize(find.byWidget(field.widget)).height, AuthPhoneMetrics.fieldHeight, reason: where);
          final d = (field.widget as TextField).decoration!;
          expect(d.filled, isTrue);
          expect(d.fillColor, colors.surfaceMuted);
          final border = d.enabledBorder! as OutlineInputBorder;
          expect(border.borderRadius, BorderRadius.circular(AuthPhoneMetrics.fieldRadius));
          expect(border.borderSide.width, AuthPhoneMetrics.fieldHairline);
          expect(ColorMath.contrast(border.borderSide.color, colors.background), greaterThanOrEqualTo(3), reason: '$where hairline');
          // Why the hairline stays: the soft fill alone is under 3:1.
          expect(ColorMath.contrast(colors.surfaceMuted, colors.background), lessThan(3), reason: where);
        }
        // The header's texts on its tint.
        final tint = colors.authFooterFill;
        expect(ColorMath.contrast(colors.textPrimary, tint), greaterThanOrEqualTo(4.5), reason: '$where name');
        expect(ColorMath.contrast(colors.authFooterMutedText, tint), greaterThanOrEqualTo(4.5), reason: '$where tagline');
      }
    }
  });

  testWidgets('the entrance: the header then the form, once; not again on a resize', (tester) async {
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844);
    final entrances = find.descendant(of: find.byType(LoginScreen), matching: find.byType(AuthEntrance));
    expect(entrances, findsNWidgets(2));
    expect(find.descendant(of: entrances.first, matching: find.byKey(LoginScreen.phoneBrandKey)), findsOneWidget);
    expect(find.descendant(of: entrances.last, matching: find.byKey(LoginScreen.loginCardKey)), findsOneWidget);
    double opacity(int i) =>
        tester.widget<FadeTransition>(find.descendant(of: entrances.at(i), matching: find.byType(FadeTransition)).first).opacity.value;
    expect(opacity(0), lessThan(1));
    await _settle(tester);
    expect(opacity(0), 1);
    expect(opacity(1), 1);
    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    expect(opacity(0), 1);
    expect(opacity(1), 1);
  });

  testWidgets('reduced motion: no entrance at all', (tester) async {
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, reduceMotion: true);
    for (final e in find.byType(AuthEntrance).evaluate()) {
      final fades = find.descendant(of: find.byWidget(e.widget), matching: find.byType(FadeTransition));
      for (final f in fades.evaluate()) {
        expect((f.widget as FadeTransition).opacity.value, 1);
      }
    }
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(412, 915), Size(560, 900)]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        final at = '${size.width.toInt()}x${size.height.toInt()} ${brightness.name} ${locale.languageCode}';
        testWidgets('$at: no overflow', (tester) async {
          await pumpLogin(tester, FakeFirebaseFirestore(), width: size.width, height: size.height, brightness: brightness, locale: locale);
          await _settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(AuthPhoneHeader), findsOneWidget);
        });
      }
    }
  }
}
