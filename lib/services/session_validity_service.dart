import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/force_logout.dart';

/// Detects when this device's session has been remotely revoked (via
/// "Log Out of All Devices", triggered from a different session) and
/// forces a clean local logout here too.
///
/// Firebase Auth's revokeRefreshTokens() only blocks *future* token
/// refreshes - it doesn't retroactively invalidate an ID token that's
/// already valid, and those stay valid on their own for up to an hour.
/// Without an explicit check like this, "logout everywhere" only
/// actually signs out the device it was triggered from; every other
/// already-signed-in device keeps working normally until its current
/// token happens to expire naturally, up to an hour later.
class SessionValidityService {
  static bool _checking = false;

  /// Force-refreshes the current ID token. If Firebase reports it's
  /// been revoked (or the account was disabled/deleted in the
  /// meantime), signs out locally with a clear explanation. Safe to
  /// call repeatedly - a check already in flight is skipped rather
  /// than stacking up duplicate concurrent calls.
  static Future<void> checkAndHandleRevocation() async {
    if (_checking) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _checking = true;
    try {
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      // 'user-token-expired' is Firebase's documented code for exactly
      // this scenario (a revoked refresh token). 'user-disabled' and
      // 'user-not-found' are handled the same way as a reasonable
      // safety net for the related case of an account being
      // deactivated or removed while this session was still active.
      if (e.code == 'user-token-expired' ||
          e.code == 'user-disabled' ||
          e.code == 'user-not-found') {
        await forceLogoutAndShowLogin(
          message: 'You were signed out because your account was signed out from another device.',
        );
      } else {
        debugPrint('SessionValidityService: unexpected auth error during check: ${e.code}');
      }
    } catch (e) {
      // A plain network hiccup shouldn't force a logout - only a
      // confirmed FirebaseAuthException above does that.
      debugPrint('SessionValidityService: token refresh check failed: $e');
    } finally {
      _checking = false;
    }
  }
}
