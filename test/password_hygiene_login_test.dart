import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// P1b: password hygiene on the sign-in screen. The owner found that after a
// failed sign-in the password stayed in the field, readable if the eye had
// been opened, for anyone walking up to an unattended screen.
// Written before the fix and run against the old code (1f02ccc): 17 of 18
// failed for the right reason, the password still there or still readable.

class _FakeCredential implements UserCredential {
  @override
  User? get user => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthService {
  Object? error;
  int calls = 0;
  String? passwordWhenCalled;

  @override
  Future<UserCredential> login(String email, String password) async {
    calls++;
    passwordWhenCalled = password;
    if (error != null) throw error!;
    return _FakeCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const email = 'owner@example.com';
  const password = 'Secret123';

  Finder emailField() => find.byType(TextField).at(0);
  Finder passwordField() => find.byType(TextField).at(1);
  TextField pw(WidgetTester tester) => tester.widget<TextField>(passwordField());
  TextField em(WidgetTester tester) => tester.widget<TextField>(emailField());

  Future<_FakeAuth> pumpLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _FakeAuth();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(authService: auth, firestore: FakeFirebaseFirestore()),
    ));
    await tester.pump();
    return auth;
  }

  // Ends with every timer the screen started (the alert, the safety net)
  // run out, so the test does not finish with one still pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  Future<void> typeBoth(WidgetTester tester, {String typedEmail = email}) async {
    await tester.enterText(emailField(), typedEmail);
    await tester.enterText(passwordField(), password);
    await tester.pump();
  }

  Future<void> openEye(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(pw(tester).obscureText, isFalse, reason: 'the eye shows the password');
  }

  // Enter in the password field: focus stays where it was.
  Future<void> submitWithEnter(WidgetTester tester) async {
    await tester.showKeyboard(passwordField());
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
  }

  Future<void> submitWithButton(WidgetTester tester) async {
    final button = find.text('Sign in').last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
  }

  group('a failed attempt that Firebase rejects', () {
    for (final code in ['invalid-credential', 'user-not-found', 'wrong-password', 'user-disabled', 'too-many-requests']) {
      testWidgets('$code: the password is cleared and hidden, the email stays', (tester) async {
        final auth = await pumpLogin(tester);
        auth.error = FirebaseAuthException(code: code);
        await typeBoth(tester);
        await openEye(tester);
        await submitWithEnter(tester);

        expect(auth.calls, 1);
        expect(pw(tester).controller!.text, isEmpty);
        expect(pw(tester).obscureText, isTrue);
        expect(em(tester).controller!.text, email);
        expect(pw(tester).focusNode!.hasFocus, isTrue);
        await finish(tester);
      });
    }

    testWidgets('focus returns to the password field after the button was used', (tester) async {
      final auth = await pumpLogin(tester);
      auth.error = FirebaseAuthException(code: 'invalid-credential');
      await typeBoth(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await submitWithButton(tester);

      expect(auth.calls, 1);
      expect(pw(tester).controller!.text, isEmpty);
      expect(pw(tester).focusNode!.hasFocus, isTrue);
      await finish(tester);
    });
  });

  group('a failure that made no attempt keeps the password', () {
    testWidgets('an empty email (checked by the app)', (tester) async {
      final auth = await pumpLogin(tester);
      await typeBoth(tester, typedEmail: '');
      await submitWithEnter(tester);

      expect(auth.calls, 0);
      expect(pw(tester).controller!.text, password);
      await finish(tester);
    });

    testWidgets('a malformed email (invalid-email): kept, and hidden again', (tester) async {
      final auth = await pumpLogin(tester);
      auth.error = FirebaseAuthException(code: 'invalid-email');
      await typeBoth(tester, typedEmail: 'not-an-email');
      await openEye(tester);
      await submitWithEnter(tester);

      expect(pw(tester).controller!.text, password);
      expect(pw(tester).obscureText, isTrue);
      await finish(tester);
    });
  });

  group('a network or unknown error hides the password but keeps it', () {
    final errors = <String, Object>{
      'network-request-failed': FirebaseAuthException(code: 'network-request-failed'),
      'an unknown Firebase code': FirebaseAuthException(code: 'internal-error'),
      'not a Firebase error': Exception('boom'),
    };
    errors.forEach((name, error) {
      testWidgets(name, (tester) async {
        final auth = await pumpLogin(tester);
        auth.error = error;
        await typeBoth(tester);
        await openEye(tester);
        await submitWithEnter(tester);

        expect(auth.calls, 1);
        expect(pw(tester).controller!.text, password);
        expect(pw(tester).obscureText, isTrue);
        expect(em(tester).controller!.text, email);
        await finish(tester);
      });
    });
  });

  testWidgets('a successful sign-in clears the password before moving on', (tester) async {
    final auth = await pumpLogin(tester);
    await typeBoth(tester);
    await submitWithEnter(tester);

    expect(auth.calls, 1);
    expect(auth.passwordWhenCalled, password);
    expect(pw(tester).controller!.text, isEmpty);
    await finish(tester);
  });

  group('the eye closes by itself', () {
    // The real order, away and back (Flutter asserts each step is valid).
    const away = [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused];
    for (final state in away) {
      testWidgets('when the app goes ${state.name}', (tester) async {
        await pumpLogin(tester);
        await typeBoth(tester);
        await openEye(tester);
        final steps = away.sublist(0, away.indexOf(state) + 1);
        for (final step in steps) {
          tester.binding.handleAppLifecycleStateChanged(step);
        }
        await tester.pump();
        expect(pw(tester).obscureText, isTrue);
        expect(pw(tester).controller!.text, password, reason: 'only hidden, not cleared');
        for (final step in [...steps.reversed.skip(1), AppLifecycleState.resumed]) {
          tester.binding.handleAppLifecycleStateChanged(step);
        }
        await finish(tester);
      });
    }

    testWidgets('when the password field loses focus', (tester) async {
      await pumpLogin(tester);
      await typeBoth(tester);
      await openEye(tester);
      expect(pw(tester).focusNode!.hasFocus, isTrue);
      await tester.tap(emailField());
      await tester.pump();
      expect(pw(tester).focusNode!.hasFocus, isFalse);
      expect(pw(tester).obscureText, isTrue);
      await finish(tester);
    });

    testWidgets('after AppTimeouts.passwordReveal, and opening it again restarts the count', (tester) async {
      expect(AppTimeouts.passwordReveal, const Duration(seconds: AppTimeouts.passwordRevealSeconds));
      await pumpLogin(tester);
      await typeBoth(tester);
      await openEye(tester);
      await tester.pump(AppTimeouts.passwordReveal - const Duration(seconds: 1));
      expect(pw(tester).obscureText, isFalse, reason: 'still inside the time limit');
      await tester.pump(const Duration(seconds: 1));
      expect(pw(tester).obscureText, isTrue);

      await openEye(tester);
      await tester.pump(AppTimeouts.passwordReveal - const Duration(seconds: 1));
      expect(pw(tester).obscureText, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(pw(tester).obscureText, isTrue);
      await finish(tester);
    });
  });

  testWidgets('the password field: no autocorrect, no suggestions', (tester) async {
    await pumpLogin(tester);
    expect(pw(tester).autocorrect, isFalse);
    expect(pw(tester).enableSuggestions, isFalse);
    await finish(tester);
  });
}
