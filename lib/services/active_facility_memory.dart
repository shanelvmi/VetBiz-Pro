/// RELOAD1: a reload in the same session opens the dashboard of the SAME
/// facility (owner report: a reload sent them to Select Facility, because the
/// open facility lived only in memory).
///
/// The open facility's id and the phone's bottom tab are kept in the
/// session's own store (sessionStorage on web, through AUTH-1's seam): ids
/// and tab names only, never names, codes or tokens. A fresh session never
/// reads them, and every sign-out forgets them.
library;

/// A store that lives exactly as long as the session: sessionStorage on web
/// (one per tab, kept across a reload, gone when the tab closes), memory
/// elsewhere (where every cold start is a new session, AUTH-1).
abstract class SessionStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

/// Not web, and tests: in memory.
class MemorySessionStore implements SessionStore {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

class ActiveFacilityMemory {
  ActiveFacilityMemory._();

  static const facilityKey = 'vetbiz_active_facility';
  static const tabKey = 'vetbiz_phone_tab';

  static SessionStore store = MemorySessionStore();

  static void sessionStarted({required bool sameSession}) => throw UnimplementedError('RELOAD1');

  static void remember(String facilityId) => throw UnimplementedError('RELOAD1');

  static Map<String, dynamic>? facilityToResume(List<Map<String, dynamic>> facilities) =>
      throw UnimplementedError('RELOAD1');

  static void resumed() => throw UnimplementedError('RELOAD1');

  static void rememberTab(String tab) => throw UnimplementedError('RELOAD1');

  static String? takeTabToRestore() => throw UnimplementedError('RELOAD1');

  static void forget() => throw UnimplementedError('RELOAD1');
}
