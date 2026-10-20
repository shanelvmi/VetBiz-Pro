import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/widgets/password_field_guard.dart';

// P1b: the shared password-field helper used by sign-in, register (both
// fields) and the two re-authentication dialogs.
void main() {
  // A field wired the way the screens wire it, plus a second field to move
  // focus to.
  Future<PasswordFieldGuard> pumpField(WidgetTester tester) async {
    final guard = PasswordFieldGuard();
    addTearDown(guard.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const TextField(key: Key('other')),
          ListenableBuilder(
            listenable: guard,
            builder: (_, __) => TextField(
              key: const Key('pw'),
              controller: guard.controller,
              focusNode: guard.focusNode,
              obscureText: guard.obscured,
            ),
          ),
        ]),
      ),
    ));
    return guard;
  }

  testWidgets('hidden to start; the eye opens and closes it', (tester) async {
    final guard = await pumpField(tester);
    expect(guard.obscured, isTrue);
    guard.toggle();
    expect(guard.obscured, isFalse);
    guard.toggle();
    expect(guard.obscured, isTrue);
  });

  testWidgets('closes by itself after AppTimeouts.passwordReveal; reopening restarts the count', (tester) async {
    expect(AppTimeouts.passwordRevealSeconds, 10);
    final guard = await pumpField(tester);
    guard.reveal();
    await tester.pump(AppTimeouts.passwordReveal - const Duration(milliseconds: 1));
    expect(guard.obscured, isFalse);
    guard.reveal(); // opened again just before the limit: a fresh count
    await tester.pump(AppTimeouts.passwordReveal - const Duration(milliseconds: 1));
    expect(guard.obscured, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(guard.obscured, isTrue);
  });

  testWidgets('closes when the app is not in front, any state but resumed', (tester) async {
    final guard = await pumpField(tester);
    // The real order, away and back (Flutter asserts each step is valid).
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      guard.reveal();
      tester.binding.handleAppLifecycleStateChanged(state);
      expect(guard.obscured, isTrue, reason: state.name);
    }
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(guard.obscured, isTrue, reason: 'coming back does not reopen it');
  });

  testWidgets('closes when the field loses focus, and the TextField follows', (tester) async {
    final guard = await pumpField(tester);
    await tester.enterText(find.byKey(const Key('pw')), 'Secret123');
    guard.reveal();
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('pw'))).obscureText, isFalse);
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(guard.obscured, isTrue);
    expect(tester.widget<TextField>(find.byKey(const Key('pw'))).obscureText, isTrue);
    expect(guard.controller.text, 'Secret123', reason: 'hidden, not cleared');
  });

  testWidgets('the rejected codes are exactly these five', (tester) async {
    for (final code in ['invalid-credential', 'user-not-found', 'wrong-password', 'user-disabled', 'too-many-requests']) {
      expect(PasswordFieldGuard.rejectedAttempt(FirebaseAuthException(code: code)), isTrue, reason: code);
    }
    for (final code in ['invalid-email', 'network-request-failed', 'internal-error', 'email-already-in-use']) {
      expect(PasswordFieldGuard.rejectedAttempt(FirebaseAuthException(code: code)), isFalse, reason: code);
    }
    expect(PasswordFieldGuard.rejectedAttempt(Exception('wrong-password')), isFalse);
  });

  testWidgets('a rejected attempt clears and hides; any other failure only hides', (tester) async {
    final guard = await pumpField(tester);
    guard.controller.text = 'Secret123';
    guard.reveal();
    expect(guard.afterFailedAttempt(FirebaseAuthException(code: 'network-request-failed')), isFalse);
    expect(guard.controller.text, 'Secret123');
    expect(guard.obscured, isTrue);

    guard.reveal();
    expect(guard.afterFailedAttempt(FirebaseAuthException(code: 'wrong-password')), isTrue);
    expect(guard.controller.text, isEmpty);
    expect(guard.obscured, isTrue);
  });

  testWidgets('register: a failed registration clears and hides both fields, other fields keep their text', (tester) async {
    final password = PasswordFieldGuard();
    final confirm = PasswordFieldGuard();
    final email = TextEditingController(text: 'owner@example.com');
    addTearDown(() {
      password.dispose();
      confirm.dispose();
      email.dispose();
    });
    password.controller.text = 'Secret123';
    confirm.controller.text = 'Secret123';
    password.reveal();
    confirm.reveal();

    for (final guard in [password, confirm]) {
      guard.clearAndHide();
    }

    expect(password.controller.text, isEmpty);
    expect(confirm.controller.text, isEmpty);
    expect(password.obscured, isTrue);
    expect(confirm.obscured, isTrue);
    expect(email.text, 'owner@example.com');
  });
}
