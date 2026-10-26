import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/support_contact.dart';

/// Reads app_config/support_contact's data; throws when the read fails (the
/// store then keeps what it had).
typedef SupportContactFetch = Future<Map<String, dynamic>?> Function(FirebaseFirestore? db);

/// G6: the one copy of the support contact for the whole app. The sign-in
/// footer, the Help dialog (footer, dashboard, Settings) and the About page
/// read it here instead of each reading the document again.
class SupportContactStore extends ChangeNotifier {
  SupportContactStore({SupportContactFetch? fetch, Future<SharedPreferences> Function()? prefs, DateTime Function()? now});

  static SupportContactStore? _instance;

  /// The app's store.
  static SupportContactStore get instance => _instance ??= SupportContactStore();

  /// Tests: put a store with a fake read in place of the app's.
  @visibleForTesting
  static set debugInstance(SupportContactStore? store) => _instance = store;

  /// Tests: a new store before every test (test/flutter_test_config.dart).
  @visibleForTesting
  static void debugReset() => _instance = null;

  /// The shared_preferences key of the last-known copy.
  static const String prefsKey = 'support_contact_last_known';

  /// What is known now, at once: null until a copy was restored or read.
  SupportContact? get current => throw UnimplementedError();

  /// Puts the persisted last-known copy in memory (before the first frame).
  Future<void> restore() => throw UnimplementedError();

  /// The contact: the fresh copy at once, else the one read in flight.
  Future<SupportContact> contact([FirebaseFirestore? db]) => throw UnimplementedError();

  /// Starts a background read unless one runs or the copy is fresh.
  void revalidate([FirebaseFirestore? db]) => throw UnimplementedError();
}
