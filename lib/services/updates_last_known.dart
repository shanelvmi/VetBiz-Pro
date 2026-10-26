import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G6: whether the login page's Updates had anything to show the last time
/// they were read (in memory, and persisted as one boolean), so the page can
/// keep their 16:9 frame from the first frame instead of jumping when they
/// arrive. main() calls [restore] before runApp.
class UpdatesLastKnown {
  UpdatesLastKnown({Future<SharedPreferences> Function()? prefs}) : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static UpdatesLastKnown? _instance;

  /// The app's copy.
  static UpdatesLastKnown get instance => _instance ??= UpdatesLastKnown();

  /// Tests: a new copy before every test (test/flutter_test_config.dart).
  @visibleForTesting
  static void debugReset() => _instance = null;

  /// The shared_preferences key of the boolean.
  static const String prefsKey = 'updates_last_known_any';

  bool? _had;

  /// Null: never read on this device.
  bool? get hadUpdates => _had;

  /// Puts the persisted boolean in memory (before the first frame). Never
  /// throws.
  Future<void> restore() async {
    try {
      final saved = (await _prefs()).getBool(prefsKey);
      _had ??= saved;
    } catch (e) {
      debugPrint('UpdatesLastKnown could not restore: $e');
    }
  }

  /// Records the latest answer (persisted only when it changed).
  void record(bool had) {
    if (_had == had) return;
    _had = had;
    unawaited(() async {
      try {
        await (await _prefs()).setBool(prefsKey, had);
      } catch (e) {
        debugPrint('UpdatesLastKnown could not save: $e');
      }
    }());
  }
}
