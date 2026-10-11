import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/l10n.dart';
import 'friendly_error.dart';

/// A sign-in error in words a person can act on. Shared by the login screen
/// and FriendlyError, so there is one mapping, not two.
///
/// Worded by the feedback copy rules (PHASE2_FEEDBACK_SPEC section 6; owner
/// decision for batch D8). The texts are sentences, like FriendlyError's own,
/// because FriendlyError shows them as an error's second line. In the current
/// language (L10n.current): the login screen reads them after an await.
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
      return L10n.current.login_wrongCredentials;
    case 'user-disabled':
      return L10n.current.login_accountDisabled;
    case 'too-many-requests':
      return L10n.current.login_tooManyAttempts;
    case 'network-request-failed':
      return FriendlyError.noConnection;
    default:
      return e.message ?? L10n.current.login_signInFailed;
  }
}
