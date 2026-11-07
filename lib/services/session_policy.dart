/// AUTH-1: every NEW launch of the app starts at the login (data protection).
///
/// A session lasts only as long as the browser tab or app window. A RELOAD in
/// the same tab keeps it; closing the tab, the browser or the installed app
/// ends it. See [SessionPolicy.applyAtStart].
library;

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

  Future<void> applyAtStart() async {}
}
