import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/ui/feedback/auth_error_messages.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';

// FirebaseFunctionsException's constructor is @protected; a subclass may
// call it, which is how the plugin builds them too.
class _FunctionsError extends FirebaseFunctionsException {
  _FunctionsError(String code, String message) : super(code: code, message: message);
}

FirebaseException _firestore(String code) => FirebaseException(
      plugin: 'cloud_firestore',
      code: code,
      message: '[cloud_firestore/$code] The caller does not have permission (raw)',
    );

/// PHASE2_FEEDBACK_SPEC section 5: one test per row.
void main() {
  test('permission-denied', () {
    expect(FriendlyError.messageFor(_firestore('permission-denied')), "You don't have permission to do that.");
  });

  test('unavailable and network failures', () {
    expect(FriendlyError.messageFor(_firestore('unavailable')), 'No connection. Check your internet and try again.');
    expect(FriendlyError.messageFor(_firestore('network-request-failed')),
        'No connection. Check your internet and try again.');
  });

  test('deadline-exceeded and TimeoutException', () {
    expect(FriendlyError.messageFor(_firestore('deadline-exceeded')), 'That took too long. Try again.');
    expect(FriendlyError.messageFor(TimeoutException('read', const Duration(seconds: 1))),
        'That took too long. Try again.');
  });

  test('not-found, already-exists, resource-exhausted', () {
    expect(FriendlyError.messageFor(_firestore('not-found')), 'That item no longer exists.');
    expect(FriendlyError.messageFor(_firestore('already-exists')), 'That already exists.');
    expect(FriendlyError.messageFor(_firestore('resource-exhausted')),
        'Too many requests. Wait a moment and try again.');
  });

  test("our server's own message is shown unchanged", () {
    const serverText = "You've reached the facility limit for your account (6).";
    expect(FriendlyError.messageFor(_FunctionsError('failed-precondition', serverText)), serverText);
  });

  test("functions 'internal' and transport codes use the code's sentence, not the text", () {
    expect(FriendlyError.messageFor(_FunctionsError('internal', 'INTERNAL')), 'Something went wrong. Try again.');
    expect(FriendlyError.messageFor(_FunctionsError('unavailable', 'UNAVAILABLE')),
        'No connection. Check your internet and try again.');
    expect(FriendlyError.messageFor(_FunctionsError('deadline-exceeded', 'DEADLINE_EXCEEDED')),
        'That took too long. Try again.');
  });

  test('auth errors reuse the login mapping, identically', () {
    for (final code in [
      'user-not-found', 'invalid-email', 'wrong-password', 'invalid-credential',
      'user-disabled', 'too-many-requests', 'network-request-failed',
    ]) {
      final e = FirebaseAuthException(code: code, message: 'raw $code');
      expect(FriendlyError.messageFor(e), authErrorMessage(e), reason: code);
    }
    expect(FriendlyError.messageFor(FirebaseAuthException(code: 'wrong-password')),
        'Incorrect password. Please try again.');
  });

  test('anything else gets the fallback', () {
    expect(FriendlyError.messageFor(StateError('bad state')), 'Something went wrong. Try again.');
    expect(FriendlyError.messageFor(Exception('boom')), 'Something went wrong. Try again.');
    expect(FriendlyError.messageFor(_firestore('aborted')), 'Something went wrong. Try again.');
  });

  test('no output ever contains exception text, plugin tags, brackets or a stack trace', () {
    final errors = <Object>[
      _firestore('permission-denied'),
      _firestore('some-new-code'),
      Exception('[cloud_firestore/permission-denied] x'),
      _FunctionsError('failed-precondition', 'Exception: [boom] at foo.dart:12'),
      _FunctionsError('not-found', '#0 main (file.dart:3:1)'),
      FirebaseAuthException(code: 'some-new-auth-code', message: '[firebase_auth/x] raw'),
      FirebaseAuthException(code: 'some-new-auth-code'),
      ArgumentError('x'),
    ];
    for (final e in errors) {
      final out = FriendlyError.messageFor(e);
      for (final bad in ['Exception', 'cloud_firestore', '[', '.dart:', '#0']) {
        expect(out.contains(bad), isFalse, reason: '"$out" (from $e) contains "$bad"');
      }
      expect(out.trim(), isNotEmpty);
    }
  });

  test('details give the code and message, for the Details action', () {
    expect(FriendlyError.detailsFor(_firestore('permission-denied')),
        'permission-denied: [cloud_firestore/permission-denied] The caller does not have permission (raw)');
    expect(FriendlyError.detailsFor(FirebaseException(plugin: 'p', code: 'x')), 'x');
    expect(FriendlyError.detailsFor(StateError('bad')), 'Bad state: bad');
  });
}
