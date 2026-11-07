/// AUTH-1: every NEW launch of the app starts at the login (data protection).
///
/// A session lasts only as long as the browser tab or app window. A RELOAD in
/// the same tab keeps it; closing the tab, the browser or the installed app
/// ends it. See [SessionPolicy.applyAtStart].
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_timeouts.dart';
import '../utils/force_logout.dart';
import 'session_marker.dart';

/// The one-time "this session has started" marker. On web it lives in
/// sessionStorage (one per tab, kept across a reload, gone when the tab
/// closes); elsewhere it lives in memory, so every cold start lacks it.
abstract class SessionMarker {
  bool get isSet;
  void set();
}

/// Not web: in memory, so the flag dies with the process (a cold start).
class MemorySessionMarker implements SessionMarker {
  static bool _set = false;

  @override
  bool get isSet => _set;

  @override
  void set() => _set = true;

  /// A new process, for tests.
  static void resetForTest() => _set = false;
}

class SessionPolicy {
  SessionPolicy({
    required this.isWeb,
    required this.marker,
    required this.setSessionPersistence,
    required this.restoredUserPresent,
    required this.signOut,
  });

  final bool isWeb;
  final SessionMarker marker;

  /// Web only: FirebaseAuth keeps the user in the tab's session, not for ever.
  final Future<void> Function() setSessionPersistence;

  /// Whether a user came back from storage at start.
  final Future<bool> Function() restoredUserPresent;

  /// The app's one sign-out (forceLogoutAndShowLogin).
  final Future<void> Function() signOut;

  /// The real wiring: SESSION persistence and the sessionStorage marker on web,
  /// the in-memory flag elsewhere, the sign-out every other path uses.
  factory SessionPolicy.forThisPlatform() => SessionPolicy(
        isWeb: kIsWeb,
        marker: platformSessionMarker(),
        setSessionPersistence: () => FirebaseAuth.instance.setPersistence(Persistence.SESSION),
        restoredUserPresent: _restoredUserPresent,
        signOut: forceLogoutAndShowLogin,
      );

  /// Run once, in main() before runApp: before AppEntryPoint listens and
  /// before anyone can sign in. A user restored at the start of a session
  /// that never had the marker (a LOCAL session left over from before AUTH-1,
  /// a cold start off the web) is signed out; a reload in the same tab finds
  /// the marker and keeps its session.
  Future<void> applyAtStart() async {
    if (isWeb) {
      try {
        await setSessionPersistence();
      } catch (e) {
        // The marker below still ends a leftover session.
        debugPrint('[SESSION] setPersistence(SESSION) failed: $e');
      }
    }
    if (!marker.isSet && await restoredUserPresent()) {
      debugPrint('[SESSION] A new session found a signed-in user: signing out');
      await signOut();
    }
    marker.set();
  }
}

/// Waits for FirebaseAuth to finish restoring (on web its first event), not
/// for ever.
Future<bool> _restoredUserPresent() async {
  final auth = FirebaseAuth.instance;
  try {
    return await auth.authStateChanges().first.timeout(AppTimeouts.sessionRestore) != null;
  } on TimeoutException {
    return auth.currentUser != null;
  }
}
