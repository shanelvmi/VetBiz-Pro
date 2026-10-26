import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G6: whether the login page's Updates had anything to show the last time
/// they were read (in memory, and persisted as one boolean), so the page can
/// keep their 16:9 frame from the first frame instead of jumping when they
/// arrive.
class UpdatesLastKnown {
  UpdatesLastKnown({Future<SharedPreferences> Function()? prefs});

  static UpdatesLastKnown? _instance;

  /// The app's copy.
  static UpdatesLastKnown get instance => _instance ??= UpdatesLastKnown();

  /// Tests: a new copy before every test (test/flutter_test_config.dart).
  @visibleForTesting
  static void debugReset() => _instance = null;

  /// The shared_preferences key of the boolean.
  static const String prefsKey = 'updates_last_known_any';

  /// Null: never read on this device.
  bool? get hadUpdates => throw UnimplementedError();

  /// Puts the persisted boolean in memory (before the first frame).
  Future<void> restore() => throw UnimplementedError();

  /// Records the latest answer (persisted only when it changed).
  void record(bool had) => throw UnimplementedError();
}
