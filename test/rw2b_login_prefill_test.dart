import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// RW2b (owner answer 7): after AccountCreatedException (the account was
// made, the sign-in after it failed) the person lands on Sign in with the
// email filled in and the existing message. LoginScreen takes the email;
// the '/login' route takes both as a LoginPrefill.

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpLogin(WidgetTester tester, LoginScreen screen, Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  String emailText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text;

  testWidgets('the email given is filled in, over a remembered one, with the message', (tester) async {
    await pumpLogin(
      tester,
      LoginScreen(
        authService: _NoAuth(),
        firestore: FakeFirebaseFirestore(),
        initialEmail: 'amina@example.com',
        errorMessage: en.register_accountCreatedSignIn,
      ),
      {'remembered_email': 'someone.else@example.com'},
    );
    expect(emailText(tester), 'amina@example.com');
    expect(find.text(en.register_accountCreatedSignIn), findsOneWidget);
    await finish(tester);
  });

  testWidgets('none given: the remembered email, as before', (tester) async {
    await pumpLogin(tester, LoginScreen(authService: _NoAuth(), firestore: FakeFirebaseFirestore()),
        {'remembered_email': 'someone.else@example.com'});
    expect(emailText(tester), 'someone.else@example.com');
    await finish(tester);
  });

  test("the app's '/login' route passes a LoginPrefill on", () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('is LoginPrefill'));
    expect(main, contains('initialEmail: prefill.email'));
    expect(main, contains('errorMessage: prefill.message'));
  });
}
