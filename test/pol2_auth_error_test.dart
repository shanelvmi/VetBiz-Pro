// POL2 Step 2: the sign-in and register error boxes keep their message, their
// soft danger fill and their danger border, with no red glow under them
// (owner rule 4). Phone and wide, Light and Dark; the wide pages' fingerprints
// (lg1-login-error, fin1-register-owner-step2-errors) still match: the glow was never
// part of the layout.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';

import 'helpers/login_harness.dart';
import 'helpers/register_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// The error box: the one container on the danger surface.
BoxDecoration _box(WidgetTester tester, Type screen) {
  final colors = Theme.of(tester.element(find.byType(screen))).extension<AppColors>()!;
  final boxes = [
    for (final c in tester.widgetList<Container>(find.descendant(of: find.byType(screen), matching: find.byType(Container))))
      if (c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color == colors.dangerSurface) c.decoration as BoxDecoration,
  ];
  expect(boxes, hasLength(1), reason: 'the error box is shown');
  return boxes.single;
}

void _flatWithDangerBorder(WidgetTester tester, Type screen) {
  final colors = Theme.of(tester.element(find.byType(screen))).extension<AppColors>()!;
  final d = _box(tester, screen);
  expect(d.boxShadow, anyOf(isNull, isEmpty), reason: 'no glow');
  expect(d.gradient, isNull);
  expect((d.border as Border).top.color, colors.dangerAccent.withValues(alpha: (d.border as Border).top.color.a));
}

void main() {
  for (final (where, width, height) in [('phone', 390.0, 844.0), ('wide', 1200.0, 1000.0)]) {
    for (final brightness in Brightness.values) {
      testWidgets('sign-in $where ${brightness.name}: the error box has its message and danger border, no glow', (tester) async {
        await pumpLogin(tester, FakeFirebaseFirestore(), width: width, height: height, brightness: brightness);
        await tester.tap(find.text('Sign in').last);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(_en.login_credentialsTooShort), findsOneWidget);
        _flatWithDangerBorder(tester, LoginScreen);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('register $where: the error box has its message and danger border, no glow', (tester) async {
      // A failed sign-up (as rw2b_register_wizard_test.dart drives it) shows the error box.
      final auth = FakeRegisterAuth(failWith: FirebaseAuthException(code: 'network-request-failed'));
      await pumpRegister(tester, auth: auth, size: Size(width, height));
      await fillOwnerSteps(tester);
      await tickConsent(tester);
      await tapText(tester, registerEn.register_createAccount);
      _flatWithDangerBorder(tester, RegisterScreen);
      await finishRegister(tester);
    });
  }
}
