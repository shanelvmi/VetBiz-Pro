import 'package:firebase_auth/firebase_auth.dart';

import 'friendly_error.dart';

/// A sign-in error in words a person can act on. Shared by the login screen
/// and FriendlyError, so there is one mapping, not two.
///
/// Worded by the feedback copy rules (PHASE2_FEEDBACK_SPEC section 6; owner
/// decision for batch D8). The texts are sentences, like FriendlyError's own,
/// because FriendlyError shows them as an error's second line.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'invalid-email':
    case 'wrong-password':
    case 'invalid-credential':
      // One message for all four, on purpose: "no account found" or
      // "incorrect password" would tell anyone typing an email whether it
      // is registered. Recent Firebase SDKs already report both cases as
      // 'invalid-credential' for the same reason.
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled. Contact your admin.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment and try again.';
    case 'network-request-failed':
      return FriendlyError.noConnection;
    default:
      return e.message ?? "Couldn't sign in. Try again.";
  }
}
