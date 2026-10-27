import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'announcement_service.dart';

/// Subscribes to public_announcements, newest first (Firestore in the app, a
/// fake in tests).
typedef UpdatesSubscribe = Stream<List<Announcement>> Function(FirebaseFirestore? db);

/// Starts loading a poster's image into Flutter's image cache.
typedef PosterWarm = void Function(String url);

/// AN6: the login page's Updates for the whole app. STUB (tests first).
class UpdatesStore extends ChangeNotifier {
  UpdatesStore({UpdatesSubscribe? subscribe, Future<SharedPreferences> Function()? prefs, PosterWarm? warm});

  static UpdatesStore? _instance;

  /// The app's store.
  static UpdatesStore get instance => _instance ??= UpdatesStore();

  /// Tests: put a store with fakes in place of the app's.
  @visibleForTesting
  static set debugInstance(UpdatesStore? store) => _instance = store;

  /// Tests: a new store before every test (test/flutter_test_config.dart).
  @visibleForTesting
  static void debugReset() => _instance = null;

  /// The shared_preferences key of the last-known copy.
  static const String prefsKey = 'updates_last_known';

  /// Every announcement known now, at once; null while nothing is known.
  List<Announcement>? get current => throw UnimplementedError();

  /// What the Updates show in [languageCode]; null while nothing is known.
  List<Announcement>? slidesFor(String languageCode) => throw UnimplementedError();

  /// Puts the persisted last-known copy in memory. Never throws.
  Future<void> restore() => throw UnimplementedError();

  /// Starts the one subscription unless it runs.
  void start([FirebaseFirestore? db]) => throw UnimplementedError();

  /// Warms the first, next and previous posters for [languageCode].
  void warmFor(String languageCode) => throw UnimplementedError();
}
