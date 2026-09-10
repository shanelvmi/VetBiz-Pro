import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'navigator_key.dart';
import 'provider_reset.dart';

/// Signs the current user out, resets every provider, and gets back to
/// a real, visible login screen - used anywhere an account needs to be
/// signed out right now, from either a widget (self-deactivation) or
/// non-widget code (a background listener noticing the account was
/// deactivated remotely).
///
/// IMPORTANT: this pops back to the app's own base route rather than
/// pushing a brand-new one. AppEntryPoint (in main.dart) is that base
/// route - it's the thing that reactively watches auth state and
/// decides what to show. An earlier version of this function used
/// pushAndRemoveUntil with a filter that removed every route, which
/// also removed AppEntryPoint itself from the navigation stack -
/// replacing it with a disconnected LoginScreen that nothing was
/// reactively watching anymore. That's exactly why a second login
/// attempt in the same session would hang indefinitely: nothing was
/// left listening for what should happen next, only a full page
/// refresh (which remounts AppEntryPoint from scratch) fixed it. Popping
/// back to the existing base route instead keeps AppEntryPoint alive
/// the whole time, so it's still there to react to the next sign-in.
Future<void> forceLogoutAndShowLogin({String? message}) async {
  final uidBeingSignedOut = FirebaseAuth.instance.currentUser?.uid;
  debugPrint('[LOGOUT] Starting for uid=${uidBeingSignedOut ?? "none"}${message != null ? " (message: $message)" : ""}');

  final context = navigatorKey.currentContext;

  if (context != null && context.mounted) {
    debugPrint('[LOGOUT] Resetting all user providers');
    try {
      resetAllUserProviders(context);
      debugPrint('[LOGOUT] Providers reset successfully');
    } catch (e, st) {
      // Must not prevent signOut() below from running regardless - a
      // provider lookup failing here is not a reason to leave the
      // account still signed in.
      debugPrint('[LOGOUT] Provider reset failed, continuing anyway: $e\n$st');
    }
  } else {
    debugPrint('[LOGOUT] No mounted context available - providers not reset');
  }

  // Set before signing out, not after - signOut() is what triggers the
  // auth-state event AppEntryPoint reacts to, so the message needs to
  // already be in place before that happens, not queued up afterward.
  pendingLoginMessage = message;

  try {
    await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 10));
    debugPrint('[LOGOUT] signOut() completed for uid=${uidBeingSignedOut ?? "none"}');
    if (pushAuthUser != null) {
      debugPrint('[LOGOUT] Pushing null directly to AppEntryPoint');
      pushAuthUser!(null);
    }
  } catch (e, st) {
    debugPrint('[LOGOUT] sign-out failed, continuing anyway: $e\n$st');
  }

  final navState = navigatorKey.currentState;
  if (navState != null) {
    debugPrint('[LOGOUT] Popping back to base route');
    try {
      navState.popUntil((route) => route.isFirst);
      debugPrint('[LOGOUT] popUntil(isFirst) call completed');
    } catch (e, st) {
      debugPrint('[LOGOUT] popUntil failed: $e\n$st');
    }
  } else {
    debugPrint('[LOGOUT] No navigator state available to pop');
  }
}
