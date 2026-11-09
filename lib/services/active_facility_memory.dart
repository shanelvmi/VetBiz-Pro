/// RELOAD1: a reload in the same session opens the dashboard of the SAME
/// facility (owner report: a reload sent them to Select Facility, because the
/// open facility lived only in memory).
///
/// The open facility's id is kept in the session's own store (sessionStorage
/// on web, through AUTH-1's seam): the id only, never names, codes or tokens.
/// (HUB1: the phone's bottom tab was remembered too; the hub has no tabs.) A fresh session never
/// reads them, and every sign-out forgets them.
library;

import 'package:flutter/foundation.dart';

import '../data/fields.dart';
import 'session_marker.dart';

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

  @visibleForTesting
  static SessionStore store = platformSessionStore();

  // Set at start when this is a reload in the same session; the first
  // decision takes it, so a later sign-in or decision in the same tab keeps
  // today's rules.
  static bool _resumable = false;

  /// SessionPolicy at start: [sameSession] when the session marker was
  /// already there (a reload in the same tab). A new session starts empty.
  static void sessionStarted({required bool sameSession}) {
    if (!sameSession) forget();
    _resumable = sameSession;
  }

  /// A facility was opened (the only one, picked, switched, refreshed): it is
  /// the one a reload comes back to.
  static void remember(String facilityId) => store.write(facilityKey, facilityId);

  /// The first decision after a reload: the remembered facility when it is
  /// still one of [facilities] (this person's own list, read with every
  /// account check passed). One that is not (removed, deactivated, deleted)
  /// is forgotten and today's decision follows. Null on a fresh session and
  /// after the first call.
  static Map<String, dynamic>? facilityToResume(List<Map<String, dynamic>> facilities) {
    if (!_resumable) return null;
    _resumable = false;
    final id = store.read(facilityKey);
    if (id == null) return null;
    for (final facility in facilities) {
      if (facility[Fields.facilityId] == id) return facility;
    }
    debugPrint('[RELOAD] The remembered facility is no longer this person\'s: forgotten');
    forget();
    return null;
  }

  /// Any sign-out, or nothing open any more.
  static void forget() {
    store.remove(facilityKey);
    _resumable = false;
  }
}
