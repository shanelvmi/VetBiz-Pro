import 'package:firebase_auth/firebase_auth.dart';

/// A sign-in error in words a person can act on. Shared by the login screen
/// and FriendlyError, so there is one mapping, not two.
///
/// Moved unchanged from login_screen.dart (Phase 2, step 2D-0). Some texts
/// end with a full stop or say "Please", which the feedback copy rules
/// avoid; they are listed in design-open-questions.md, not reworded here.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'invalid-email':
      return 'No account found with that email address.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'invalid-credential':
      // Recent Firebase SDKs report both "wrong password" and
      // "no such user" under this one unified code, for security
      // reasons (so a login form can't be used to check which emails
      // are registered).
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled. Contact your admin.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Network error - check your connection and try again.';
    default:
      return e.message ?? 'Login failed. Please try again.';
  }
}
