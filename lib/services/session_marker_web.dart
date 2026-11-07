import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

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
