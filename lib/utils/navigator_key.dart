import 'package:flutter/material.dart';

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
