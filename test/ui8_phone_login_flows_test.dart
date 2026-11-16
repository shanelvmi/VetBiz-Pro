// UI8, written before the change: what the phone sign-in page does. It reads
// no Updates (the carousel is not mounted on a phone; the wide page keeps
// its own); Sign in, Remember my email, Forgot Password?, Help and EN | SW
// work as before. The layout: test/ui8_phone_login_test.dart.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/widgets/auth_help_sheet.dart';
import 'package:vetbiz_pro/widgets/auth_language_switch.dart';
import 'package:vetbiz_pro/widgets/auth_phone_header.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/login_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

/// Records what the page asks of the account service; a sign-in is refused
/// as a wrong password (the page's own error path), so the test stays here.
class _RecordingAuth implements AuthService {
  final logins = <(String, String)>[];
  final resets = <String>[];

  @override
  Future<UserCredential> login(String email, String password) async {
    logins.add((email, password));
    throw FirebaseAuthException(code: 'wrong-password');
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


/// Past the page's one entrance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _button = LoginScreen.signInButtonKey;

void main() {

  testWidgets('the phone page reads no Updates; the wide page still does', (tester) async {
    final phone = CountingFirestore(await dbWithUpdates(3));
    await pumpLogin(tester, phone, width: 390, height: 844);
    await _settle(tester);
    expect(phone.listens, 0, reason: 'no Updates listener on a phone');
    final wide = CountingFirestore(await dbWithUpdates(3));
    await pumpLogin(tester, wide, width: 1200, height: 800);
    await _settle(tester);
    expect(wide.listens, greaterThan(0), reason: 'the wide page keeps its Updates');
  });

  testWidgets('Sign in sends the typed email and password', (tester) async {
    final auth = _RecordingAuth();
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, auth: auth);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, ' amina@example.com ');
    await tester.enterText(find.byType(TextField).last, 'Secret123');
    await tester.tap(find.byKey(_button));
    await _settle(tester);
    expect(auth.logins, [('amina@example.com', 'Secret123')]);
  });

  testWidgets('Remember my email stores the email only; unticked, it is removed', (tester) async {
    final auth = _RecordingAuth();
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, auth: auth);
    await _settle(tester);
    await tester.tap(find.text(_en.login_rememberMe));
    await tester.enterText(find.byType(TextField).first, 'amina@example.com');
    await tester.enterText(find.byType(TextField).last, 'Secret123');
    await tester.tap(find.byKey(_button));
    await _settle(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('remembered_email'), 'amina@example.com');
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('Secret123')), reason: key);
    }
    await tester.tap(find.text(_en.login_rememberMe));
    // P1b: a refused sign-in empties the password.
    await tester.enterText(find.byType(TextField).last, 'Secret123');
    await tester.tap(find.byKey(_button));
    await _settle(tester);
    expect(prefs.getString('remembered_email'), isNull);
  });

  testWidgets('Forgot Password? asks for the email, then sends the reset', (tester) async {
    final auth = _RecordingAuth();
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, auth: auth);
    await _settle(tester);
    await tester.tap(find.text(_en.login_forgotPassword));
    await _settle(tester);
    expect(find.text(_en.login_resetNeedsEmail), findsOneWidget);
    expect(auth.resets, isEmpty);
    await tester.enterText(find.byType(TextField).first, 'amina@example.com');
    await tester.tap(find.text(_en.login_forgotPassword));
    await _settle(tester);
    expect(auth.resets, ['amina@example.com']);
  });

  testWidgets('Help opens the help sheet', (tester) async {
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844);
    await _settle(tester);
    await tester.tap(find.byKey(AuthPhoneControls.helpKey));
    await tester.pumpAndSettle();
    expect(find.byType(AuthHelpSheet), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('EN | SW switches the page to Kiswahili and back', (tester) async {
    await pumpLogin(tester, FakeFirebaseFirestore(), width: 390, height: 844, followLanguage: true);
    await _settle(tester);
    await tester.tap(find.byKey(AuthLanguageSwitch.segmentKey('sw')));
    await tester.pumpAndSettle();
    expect(find.text(_sw.login_signInTitle), findsOneWidget);
    await tester.tap(find.byKey(AuthLanguageSwitch.segmentKey('en')));
    await tester.pumpAndSettle();
    expect(find.text(_en.login_signInTitle), findsOneWidget);
  });

}
