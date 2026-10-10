import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';

// FirebaseFunctionsException's constructor is @protected; a subclass may
// call it, which is how the plugin builds them too.
class _FunctionsError extends FirebaseFunctionsException {
  _FunctionsError(String code, String message) : super(code: code, message: message);
}

/// MembershipService.errorMessage: the server's own messages are shown as
/// they always were; everything else goes through FriendlyError, never raw.
void main() {
  group('server-provided (Functions) messages are unchanged', () {
    test("our HttpsError's own message", () {
      const text = "You've reached the facility limit for your account (6).";
      expect(MembershipService.errorMessage(_FunctionsError('failed-precondition', text)), text);
    });

    test('transport and sign-in codes keep their sentences', () {
      expect(MembershipService.errorMessage(_FunctionsError('unavailable', 'UNAVAILABLE')),
          'Could not reach the server - check your connection and try again.');
      expect(MembershipService.errorMessage(_FunctionsError('deadline-exceeded', 'DEADLINE_EXCEEDED')),
          'Could not reach the server - check your connection and try again.');
      expect(MembershipService.errorMessage(_FunctionsError('unauthenticated', 'x')), 'Please sign in again and retry.');
    });

    test("'internal' or an empty message keeps the generic sentence", () {
      expect(MembershipService.errorMessage(_FunctionsError('internal', 'INTERNAL')),
          'Something went wrong. Please try again.');
      expect(MembershipService.errorMessage(_FunctionsError('aborted', '')), 'Something went wrong. Please try again.');
    });
  });

  group('everything else goes through FriendlyError', () {
    test('a Firestore error', () {
      final e = FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied', message: '[cloud_firestore/permission-denied] raw');
      expect(MembershipService.errorMessage(e), FriendlyError.noPermission);
    });

    test('a timeout', () {
      expect(MembershipService.errorMessage(TimeoutException('x', const Duration(seconds: 1))), FriendlyError.tooSlow);
    });

    test('a plain exception never reaches the screen raw', () {
      final out = MembershipService.errorMessage(Exception('[boom] at foo.dart:12'));
      expect(out, FriendlyError.fallback);
      for (final bad in ['Exception', '[', '.dart:']) {
        expect(out.contains(bad), isFalse, reason: '"$out" contains "$bad"');
      }
    });
  });
}
