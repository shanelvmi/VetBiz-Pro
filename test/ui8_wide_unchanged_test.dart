// UI8: the phone sign-in and register frame changes phones only. Recorded
// from the code before UI8 (test/fixtures/ph5a_wide_fingerprints.json, the
// ui8- names), these must stay green to the end:
// - the sign-in page at 768x1024, 1024x768 and 1200x800 (Updates, Kiswahili,
//   Dark, the empty-fields error), with its Updates and AuthFooter;
// - the register wizard at the same sizes (both flows, Kiswahili, Dark);
// - Edit Profile (the same screen, isUpdating) at every size, phones too.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/login_harness.dart';
import 'helpers/register_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _wide = [Size(768, 1024), Size(1024, 768), Size(1200, 800)];
const _all = [Size(360, 640), Size(390, 844), Size(412, 915), ..._wide];

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

/// Past the page's one entrance; well before the first auto-advance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _expectAtTop(WidgetTester tester, String name, Type root) async {
  await tester.pumpAndSettle();
  // Compared from the top: the wizard scrolls to a field on an error and
  // tapText scrolls to what it taps.
  for (final s in find.byType(Scrollable).evaluate()) {
    final position = (s as StatefulElement).state as ScrollableState;
    if (position.position.pixels != 0) position.position.jumpTo(0);
  }
  await tester.pumpAndSettle();
  expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, find.byType(root))}');
}

Future<void> _pumpEditProfile(WidgetTester tester, Size size, {required bool modal, Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(AppColorTheme.pasture, brightness),
    themeAnimationDuration: Duration.zero,
    // No userData: the profile's live listener needs a signed-in Firebase
    // user; the frame and the fields are what this pins.
    home: RegisterScreen(firestore: FakeFirebaseFirestore(), isUpdating: true, isModal: modal),
  ));
  await tester.pump();
}

void main() {
  for (final size in _wide) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    final login = <String, (int, Locale, Brightness)>{
      'none': (0, const Locale('en'), Brightness.light),
      'several': (3, const Locale('en'), Brightness.light),
      'several-sw': (3, const Locale('sw'), Brightness.light),
      'several-dark': (3, const Locale('en'), Brightness.dark),
    };
    for (final MapEntry(key: name, value: (count, locale, brightness)) in login.entries) {
      testWidgets('ui8-login-$name-$at: the wide sign-in page is unchanged', (tester) async {
        final db = count == 0 ? FakeFirebaseFirestore() : await dbWithUpdates(count);
        await pumpLogin(tester, db, width: size.width, height: size.height, locale: locale, brightness: brightness);
        await _settle(tester);
        expectSameFingerprint('ui8-login-$name-$at', '${_errors(tester)}${treeFingerprint(tester, find.byType(LoginScreen))}');
      });
    }

    testWidgets('ui8-login-error-$at: the empty-fields error is unchanged', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), width: size.width, height: size.height);
      await _settle(tester);
      await tester.tap(find.text('Sign in').last);
      await _settle(tester);
      expectSameFingerprint('ui8-login-error-$at', '${_errors(tester)}${treeFingerprint(tester, find.byType(LoginScreen))}');
    });

    for (final step in [1, 2, 3, 4, 5]) {
      testWidgets('ui8-register-owner-step$step-$at: the wide wizard is unchanged', (tester) async {
        await pumpRegister(tester, size: size);
        await toOwnerStep(tester, step);
        await _expectAtTop(tester, 'ui8-register-owner-step$step-$at', RegisterScreen);
        await finishRegister(tester);
      });
    }

    for (final step in [3, 5]) {
      testWidgets('ui8-register-assistant-step$step-$at: the wide wizard is unchanged', (tester) async {
        await pumpRegister(tester, size: size);
        await toAssistantStep(tester, step);
        await _expectAtTop(tester, 'ui8-register-assistant-step$step-$at', RegisterScreen);
        await finishRegister(tester);
      });
    }

    testWidgets('ui8-register-step1-none-$at: nothing chosen yet', (tester) async {
      await pumpRegister(tester, size: size, chooseOwner: false);
      await _expectAtTop(tester, 'ui8-register-step1-none-$at', RegisterScreen);
      await finishRegister(tester);
    });

    testWidgets('ui8-register-step1-sw-$at: step 1 in Kiswahili', (tester) async {
      await pumpRegister(tester, size: size, locale: const Locale('sw'));
      await _expectAtTop(tester, 'ui8-register-step1-sw-$at', RegisterScreen);
      await finishRegister(tester);
    });

    testWidgets('ui8-register-step2-dark-$at: step 2 in Dark', (tester) async {
      await pumpRegister(tester, size: size, brightness: Brightness.dark);
      await toOwnerStep(tester, 2);
      await _expectAtTop(tester, 'ui8-register-step2-dark-$at', RegisterScreen);
      await finishRegister(tester);
    });
  }

  for (final size in _all) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    for (final modal in [false, true]) {
      final name = 'ui8-edit-profile-${modal ? 'modal' : 'page'}-$at';
      testWidgets('$name: Edit Profile is unchanged', (tester) async {
        await _pumpEditProfile(tester, size, modal: modal);
        await _expectAtTop(tester, name, RegisterScreen);
        await finishRegister(tester);
      });
    }
    final dark = 'ui8-edit-profile-dark-$at';
    testWidgets('$dark: Edit Profile in Dark is unchanged', (tester) async {
      await _pumpEditProfile(tester, size, modal: false, brightness: Brightness.dark);
      await _expectAtTop(tester, dark, RegisterScreen);
      await finishRegister(tester);
    });
  }
}
