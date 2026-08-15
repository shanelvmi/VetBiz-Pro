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
  final context = navigatorKey.currentContext;

  if (context != null && context.mounted) {
    resetAllUserProviders(context);
  }

  // Set before signing out, not after - signOut() is what triggers the
  // auth-state event AppEntryPoint reacts to, so the message needs to
  // already be in place before that happens, not queued up afterward.
  pendingLoginMessage = message;

  try {
    await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('forceLogoutAndShowLogin: sign-out failed, continuing anyway: $e');
  }

  final navState = navigatorKey.currentState;
  if (navState != null) {
    navState.popUntil((route) => route.isFirst);
  }
}
