import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_timeouts.dart';
import '../data/collections.dart';
import '../data/support_contact_fields.dart';
import '../models/support_contact.dart';

/// Reads app_config/support_contact's data; throws when the read fails (the
/// store then keeps what it had).
typedef SupportContactFetch = Future<Map<String, dynamic>?> Function(FirebaseFirestore? db);

/// G6: the one copy of the support contact for the whole app. The sign-in
/// footer, the Help dialog (footer, dashboard, Settings) and the About page
/// read it here instead of each reading the document again. Each page used
/// to start its own read, so its footer showed no icons until that read
/// answered and then grew when they appeared: the owner's "bounces twice".
///
/// - ONE read in flight, whoever asks and however many ask at once.
/// - [current] is known at once (synchronously) for the rest of the session,
///   so a page opened again draws the icons on its first frame.
/// - The last-known copy is persisted (only the public fields, sanitised
///   again when read back), so a later launch draws them on its first frame
///   too: main() calls [restore] before runApp.
/// - A read older than [AppTimeouts.supportContactFresh] is revalidated in
///   the background; listeners hear only a real change.
/// - A failed read keeps the last-known copy (or gives the empty one).
class SupportContactStore extends ChangeNotifier {
  SupportContactStore({SupportContactFetch? fetch, Future<SharedPreferences> Function()? prefs, DateTime Function()? now})
      : _fetch = fetch ?? _readDocument,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  final SupportContactFetch _fetch;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  /// Tests: a store that already knows [contact], fresh, as after a read.
  @visibleForTesting
  factory SupportContactStore.seeded(SupportContact contact) => SupportContactStore(fetch: (_) async => contact.toMap())
    .._current = contact
    .._readAt = DateTime.now();

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

  SupportContact? _current;
  DateTime? _readAt;
  Future<SupportContact>? _inFlight;

  static Future<Map<String, dynamic>?> _readDocument(FirebaseFirestore? db) async {
    final doc = await (db ?? FirebaseFirestore.instance)
        .collection(Collections.appConfig)
        .doc(SupportContactFields.docId)
        .get();
    return doc.data();
  }

  /// What is known now, at once: null until a copy was restored or read.
  SupportContact? get current => _current;

  bool get _isFresh {
    final readAt = _readAt;
    return readAt != null && _now().difference(readAt) < AppTimeouts.supportContactFresh;
  }

  /// Puts the persisted last-known copy in memory (before the first frame).
  /// Never throws: a missing or unreadable copy is simply not used.
  Future<void> restore() async {
    try {
      final raw = (await _prefs()).getString(prefsKey);
      // A read that answered meanwhile is newer than the device's copy.
      if (raw == null || _current != null) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      // fromMap takes only text values and sanitises every link again, so
      // a bad stored value is dropped, never opened.
      _current = SupportContact.fromMap(data);
      notifyListeners();
    } catch (e) {
      debugPrint('SupportContactStore could not restore the last-known copy: $e');
    }
  }

  /// The contact: the fresh copy at once, else the one read in flight
  /// (started if none). Never throws: a failed read gives the last-known
  /// copy, or [SupportContact.empty] when nothing is known.
  Future<SupportContact> contact([FirebaseFirestore? db]) {
    if (_isFresh) return Future.value(_current ?? SupportContact.empty);
    return _inFlight ??= _read(db).whenComplete(() => _inFlight = null);
  }

  /// Starts a background read unless one runs or the copy is fresh.
  void revalidate([FirebaseFirestore? db]) => unawaited(contact(db));

  Future<SupportContact> _read(FirebaseFirestore? db) async {
    try {
      final next = SupportContact.fromMap(await _fetch(db));
      _readAt = _now();
      if (next != _current) {
        _current = next;
        notifyListeners();
        unawaited(_persist(next));
      }
      return next;
    } catch (e) {
      // Offline or refused: keep what is shown; the next caller tries again.
      debugPrint('SupportContactStore could not read the support contact: $e');
      return _current ?? SupportContact.empty;
    }
  }

  Future<void> _persist(SupportContact contact) async {
    try {
      await (await _prefs()).setString(prefsKey, jsonEncode(contact.toMap()));
    } catch (e) {
      debugPrint('SupportContactStore could not save the last-known copy: $e');
    }
  }
}
