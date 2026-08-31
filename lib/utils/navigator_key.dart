import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lives in its own file with no other dependencies, specifically to
/// avoid a circular import: main.dart needs this for MaterialApp, and
/// force_logout.dart (used by providers that main.dart also sets up)
/// needs it too. Keeping it here means neither file has to import the
/// other.
final navigatorKey = GlobalKey<NavigatorState>();

/// Set by forceLogoutAndShowLogin() right before it pops back to
/// AppEntryPoint's own base route - AppEntryPoint's "signed out" branch
/// reads and clears this the moment it shows the login screen, so a
/// message like "your account was deactivated" survives the trip
/// without needing a whole separate LoginScreen instance pushed on top
/// (which was the actual bug - see force_logout.dart for the full
/// explanation).
String? pendingLoginMessage;

/// Called directly by LoginScreen the instant its own sign-in call
/// succeeds - the direct fix for auth state occasionally not being
/// detected promptly after a logout-then-login-as-someone-else
/// sequence. authStateChanges() has a known, documented Flutter-web
/// reliability gap (AppEntryPoint's own manual tracking in main.dart
/// already exists specifically to work around it), and this bypasses
/// that dependency entirely for the one event that matters most - a
/// person actively waiting on the login button right now. Registered
/// by AppEntryPoint on mount, cleared on dispose, so this is never
/// called against a torn-down widget; the stream and the periodic poll
/// both remain as fallbacks regardless of whether this fires.
void Function(User)? pushAuthUser;
