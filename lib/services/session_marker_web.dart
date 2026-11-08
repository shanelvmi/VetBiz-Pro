import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'active_facility_memory.dart';
import 'session_policy.dart';

/// Web: the marker in sessionStorage, which belongs to this tab, survives a
/// reload and is gone when the tab, the browser or the installed app closes.
SessionMarker platformSessionMarker() => _SessionStorageMarker();

class _SessionStorageMarker implements SessionMarker {
  static const _key = 'vetbiz_session_started';

  // Storage blocked or failing reads as missing: the safe side is one more
  // sign-in, never a session kept.
  @override
  bool get isSet {
    try {
      return web.window.sessionStorage.getItem(_key) != null;
    } catch (e) {
      debugPrint('[SESSION] sessionStorage read failed: $e');
      return false;
    }
  }

  @override
  void set() {
    try {
      web.window.sessionStorage.setItem(_key, '1');
    } catch (e) {
      debugPrint('[SESSION] sessionStorage write failed: $e');
    }
  }
}

/// Web: RELOAD1's session store, in the same sessionStorage as the marker.
SessionStore platformSessionStore() => _SessionStorageStore();

// Storage blocked or failing reads as nothing remembered: the safe side is
// today's decision (the picker or the only facility), never a wrong facility.
class _SessionStorageStore implements SessionStore {
  @override
  String? read(String key) {
    try {
      return web.window.sessionStorage.getItem(key);
    } catch (e) {
      debugPrint('[SESSION] sessionStorage read failed: $e');
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (e) {
      debugPrint('[SESSION] sessionStorage write failed: $e');
    }
  }

  @override
  void remove(String key) {
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (e) {
      debugPrint('[SESSION] sessionStorage remove failed: $e');
    }
  }
}
