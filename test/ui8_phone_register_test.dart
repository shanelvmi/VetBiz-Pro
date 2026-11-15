// UI8, written before the change: the register wizard's frame on a phone.
// The same five steps and checks; a slim tinted strip at the top ("Step n of
// 5", a five-part bar; EN | SW, Light/Dark and Help), a round icon above each
// step's heading, Back as a square icon button beside a full-width Continue
// (steps 2 to 5, every answer kept), "Already have an account? Sign in"
// under every step, and no footer. Step 5 keeps its consent. Edit Profile
// and wide windows: test/ui8_wide_unchanged_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_icons.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/auth_help_sheet.dart';
import 'package:vetbiz_pro/widgets/auth_language_switch.dart';
import 'package:vetbiz_pro/widgets/auth_phone_header.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_nav_bar.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_intro.dart';

import 'helpers/register_harness.dart';

const _skip = false;

const _phone = Size(390, 844);
final _en = registerEn;

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f.first);

Future<void> _toStep(WidgetTester tester, {required bool assistant, required int step}) =>
    assistant ? toAssistantStep(tester, step) : toOwnerStep(tester, step);

Future<void> _tapSquareBack(WidgetTester tester) async {
  await tester.tap(find.byKey(WizardNavBar.squareBackKey));
  await tester.pumpAndSettle();
}

void main() {
  for (final assistant in [false, true]) {
    final flow = assistant ? 'assistant' : 'owner';
    final icons = [
      AppIcons.stepRole,
      AppIcons.stepAboutYou,
      assistant ? AppIcons.stepInvite : AppIcons.stepFacility,
      AppIcons.stepSignIn,
      AppIcons.stepReview,
    ];
    for (final step in [1, 2, 3, 4, 5]) {
      testWidgets('$flow step $step: the strip, the icon, Back, Sign in; no footer', (tester) async {
        await pumpRegister(tester, size: _phone);
        await _toStep(tester, assistant: assistant, step: step);
        final strip = find.byKey(RegisterScreen.phoneBrandKey);
        expect(tester.widget(strip), isA<AuthPhoneTint>());
        expect(_rect(tester, strip).top, 0);
        expect(_rect(tester, strip).width, _phone.width, reason: 'edge to edge');
        expect(find.descendant(of: strip, matching: find.text(_en.wizard_stepOf(step, 5))), findsOneWidget);
        expect(find.descendant(of: strip, matching: find.byType(AuthLanguageSwitch)), findsOneWidget);
        expect(find.descendant(of: strip, matching: find.byType(AuthThemeToggle)), findsOneWidget);
        expect(find.descendant(of: strip, matching: find.byKey(AuthPhoneControls.helpKey)), findsOneWidget);
        // The bar in five parts, the first [step] filled.
        final colors = tester.element(find.byType(RegisterScreen)).colors;
        for (var i = 0; i < 5; i++) {
          final part = tester.widget<AnimatedContainer>(find.byKey(WizardStepHeader.segmentKey(i)));
          expect((part.decoration! as BoxDecoration).color, i < step ? colors.primary : colors.divider, reason: 'part $i');
        }
        // The round icon above the heading.
        final icon = find.byKey(WizardStepIntro.iconKey);
        expect(find.descendant(of: icon, matching: find.byIcon(icons[step - 1].outlined)), findsOneWidget);
        expect(tester.getSize(icon), const Size.square(AuthPhoneMetrics.stepIcon));
        // Back: a square beside a full-width Continue, from step 2.
        final back = find.byKey(WizardNavBar.squareBackKey);
        expect(back, step == 1 ? findsNothing : findsOneWidget);
        expect(find.text(_en.wizard_back), findsNothing, reason: 'the icon, not the word');
        final bar = _rect(tester, find.byType(WizardNavBar));
        final next = _rect(tester, find.descendant(of: find.byType(WizardNavBar), matching: find.byType(FilledButton)));
        expect(next.height, AuthPhoneMetrics.buttonHeight);
        if (step > 1) {
          expect(tester.getSize(back), const Size.square(AuthPhoneMetrics.buttonHeight));
          expect(next.left, greaterThan(_rect(tester, back).right));
          expect(find.byTooltip(_en.wizard_back), findsOneWidget);
        }
        expect(next.right, closeTo(bar.right - WizardMetrics.pinnedPaddingH, 1), reason: 'Continue to the right edge');
        // Sign in under the step; no footer.
        expect(find.text(_en.register_alreadyHaveAccount), findsOneWidget);
        expect(find.text(_en.common_logIn), findsOneWidget);
        expect(find.byType(AuthFooter), findsNothing);
        await finishRegister(tester);
      }, skip: _skip);
    }
  }

  testWidgets('Back keeps every answer, on every step', (tester) async {
    await pumpRegister(tester, size: _phone);
    await fillOwnerSteps(tester);
    expect(find.text(_en.wizard_stepOf(5, 5)), findsOneWidget);
    await _tapSquareBack(tester);
    expect(textOf(tester, 'email'), OwnerInputs.email);
    expect(textOf(tester, 'password'), OwnerInputs.password);
    await _tapSquareBack(tester);
    expect(find.text(OwnerInputs.facilityName), findsWidgets);
    await _tapSquareBack(tester);
    expect(textOf(tester, 'name'), OwnerInputs.name);
    expect(textOf(tester, 'phone'), OwnerInputs.phone);
    await _tapSquareBack(tester);
    expect(find.text(_en.wizard_stepOf(1, 5)), findsOneWidget);
    expect(find.byKey(WizardNavBar.squareBackKey), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 5: Create still needs the consent box', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, size: _phone, auth: auth);
    await fillOwnerSteps(tester);
    await tapText(tester, _en.register_createAccount);
    expect(auth.ownerCalls, isEmpty);
    expect(find.text(_en.register_consentRequired), findsOneWidget);
    await tickConsent(tester);
    await tapText(tester, _en.register_createAccount);
    expect(auth.ownerCalls, hasLength(1));
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Sign in under a later step opens the sign-in page', (tester) async {
    await pumpRegister(tester, size: _phone);
    await toOwnerStep(tester, 3);
    await tapText(tester, _en.common_logIn);
    expect(find.byKey(loginStandInKey), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Help opens the help sheet', (tester) async {
    await pumpRegister(tester, size: _phone);
    await tester.tap(find.byKey(AuthPhoneControls.helpKey));
    await tester.pumpAndSettle();
    expect(find.byType(AuthHelpSheet), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the strip and the step icon: contrast in all four themes, Light and Dark', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final where = '${theme.id} ${brightness.name}';
        await pumpRegister(tester, size: _phone, theme: theme, brightness: brightness);
        final c = tester.element(find.byType(RegisterScreen)).colors;
        final count = tester.widget<Text>(find.text(_en.wizard_stepOf(1, 5)));
        expect(ColorMath.contrast(count.style!.color!, c.authFooterFill), greaterThanOrEqualTo(4.5), reason: '$where count');
        expect(ColorMath.contrast(c.primary, c.authFooterFill), greaterThanOrEqualTo(3), reason: '$where bar');
        final glyph = tester.widget<Icon>(find.descendant(of: find.byKey(WizardStepIntro.iconKey), matching: find.byType(Icon)));
        expect(ColorMath.contrast(glyph.color!, c.authFooterFill), greaterThanOrEqualTo(3), reason: '$where icon');
        await finishRegister(tester);
      }
    }
  }, skip: _skip);

  for (final size in const [Size(360, 640), Size(390, 844), Size(412, 915), Size(740, 360)]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        final at = '${size.width.toInt()}x${size.height.toInt()} ${brightness.name} ${locale.languageCode}';
        testWidgets('$at: no overflow on any owner step', (tester) async {
          final l10n = locale.languageCode == 'sw' ? registerSw : registerEn;
          for (final step in [1, 2, 3, 4, 5]) {
            await pumpRegister(tester, size: size, brightness: brightness, locale: locale);
            await toOwnerStep(tester, step, l10n);
            expect(tester.takeException(), isNull, reason: 'step $step');
            await finishRegister(tester);
          }
        }, skip: _skip);
      }
    }
  }

  testWidgets('a keyboard of 300 on step 2: the pinned bar above it, the strip kept', (tester) async {
    await pumpRegister(tester, size: const Size(360, 640), keyboard: 300);
    await toOwnerStep(tester, 2);
    expect(tester.takeException(), isNull);
    final next = find.descendant(of: find.byType(WizardNavBar), matching: find.byType(FilledButton));
    expect(_rect(tester, next).bottom, lessThanOrEqualTo(640 - 300));
    expect(_rect(tester, find.byKey(WizardNavBar.squareBackKey)).bottom, lessThanOrEqualTo(640 - 300));
    expect(_rect(tester, find.byKey(RegisterScreen.phoneBrandKey)).top, 0);
    await finishRegister(tester);
  }, skip: _skip);
}
