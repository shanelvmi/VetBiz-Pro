import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_defaults.dart';
import '../data/announcement_fields.dart';
import '../data/collections.dart';
import '../providers/ui_settings_provider.dart';
import '../utils/social_link.dart';
import '../utils/updates_selection.dart';
import 'announcement_service.dart';

/// Subscribes to public_announcements, newest first (Firestore in the app, a
/// fake in tests).
typedef UpdatesSubscribe = Stream<List<Announcement>> Function(FirebaseFirestore? db);

/// Starts loading a poster's image into Flutter's image cache.
typedef PosterWarm = void Function(String url);

/// AN6: the login page's Updates for the whole app, so the page has them on
/// its first frame instead of starting a read when it opens (the owner's
/// "late welcome card, late poster").
///
/// - ONE subscription to the announcements, started by main() at app start
///   in parallel with the auth check; anyone may call [start] again.
/// - [current] is known at once (synchronously): the live list, or the
///   persisted last-known copy until the first answer. Null only while
///   nothing at all is known (the page shows a skeleton then).
/// - The copy keeps only the public fields of what any language would show,
///   and is read back through the same checks (audience values, the link
///   sanitiser, an http or https image address); an unreadable one is
///   ignored.
/// - A failed read keeps the last-known list; with nothing known it answers
///   empty, so the page shows its calm panel, never a skeleton for ever.
/// - The audience, urgent and five-slide rules are applied per language when
///   read ([slidesFor]), never when storing.
/// - The first, next and previous posters are warmed into the image cache
///   once per URL, as soon as they are known.
class UpdatesStore extends ChangeNotifier {
  UpdatesStore({UpdatesSubscribe? subscribe, Future<SharedPreferences> Function()? prefs, PosterWarm? warm})
      : _subscribe = subscribe ?? _snapshots,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _warm = warm ?? _warmNetworkImage;

  final UpdatesSubscribe _subscribe;
  final Future<SharedPreferences> Function() _prefs;
  final PosterWarm _warm;

  static UpdatesStore? _instance;

  /// The app's store.
  static UpdatesStore get instance => _instance ??= UpdatesStore();

  /// Tests: put a store with fakes in place of the app's.
  @visibleForTesting
  static set debugInstance(UpdatesStore? store) => _instance = store;

  /// Tests: a new store before every test (test/flutter_test_config.dart).
  @visibleForTesting
  static void debugReset() {
    _instance?._subscription?.cancel();
    _instance = null;
  }

  /// The shared_preferences key of the last-known copy.
  static const String prefsKey = 'updates_last_known';

  // The copy's own name for the document id and the time (milliseconds).
  static const String _idKey = 'id';

  List<Announcement>? _current;
  StreamSubscription<List<Announcement>>? _subscription;
  FirebaseFirestore? _db;
  bool _started = false;
  String _language = AppDefaults.defaultLanguage;
  final Set<String> _warmed = {};
  String? _persisted;

  static Stream<List<Announcement>> _snapshots(FirebaseFirestore? db) => (db ?? FirebaseFirestore.instance)
      .collection(Collections.publicAnnouncements)
      .orderBy(AnnouncementFields.timestamp, descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Announcement.fromMap(d.id, d.data())]);

  /// Every announcement known now, at once; null while nothing is known.
  List<Announcement>? get current => _current;

  /// What the Updates show in [languageCode]; null while nothing is known.
  List<Announcement>? slidesFor(String languageCode) {
    final all = _current;
    return all == null ? null : UpdatesSelection.pick(all, languageCode: languageCode);
  }

  /// Puts the persisted last-known copy in memory (main() awaits it before
  /// the first frame) and warms its posters for the saved language. Never
  /// throws: a missing or unreadable copy is simply not used.
  Future<void> restore() async {
    try {
      final prefs = await _prefs();
      final language = prefs.getString(UiSettingsProvider.languageKey);
      if (AppDefaults.supportedLanguages.contains(language)) _language = language!;
      final raw = prefs.getString(prefsKey);
      // An answer that came meanwhile is newer than the device's copy.
      if (raw == null || _current != null) return;
      final data = jsonDecode(raw);
      if (data is! List) return;
      _current = List.unmodifiable([
        for (final item in data)
          if (_fromStored(item) case final announcement?) announcement,
      ]);
      _persisted = raw;
      notifyListeners();
      _warmFirst();
    } catch (e) {
      debugPrint('UpdatesStore could not restore the last-known copy: $e');
    }
  }

  /// Starts the one subscription unless it runs. [db] is Firestore in the
  /// app; a different one (only in tests) replaces the source and forgets
  /// what the old one said.
  void start([FirebaseFirestore? db]) {
    if (_started && db != null && _db != null && !identical(db, _db)) {
      _subscription?.cancel();
      _subscription = null;
      _current = null;
      _persisted = null;
    }
    _db = db ?? _db;
    if (_subscription != null) return;
    _started = true;
    try {
      _subscription = _subscribe(_db).listen(_onAnswer, onError: _onError);
    } catch (e) {
      // Told after this call, never while a page is being built.
      scheduleMicrotask(() => _onError(e));
    }
  }

  void _onAnswer(List<Announcement> all) {
    _current = List.unmodifiable(all);
    notifyListeners();
    _warmFirst();
    unawaited(_persist(all));
  }

  void _onError(Object e) {
    // Offline or refused: keep what is shown. A listen that failed is over,
    // so the next start() tries again.
    debugPrint('UpdatesStore could not read the announcements: $e');
    _subscription?.cancel();
    _subscription = null;
    if (_current == null) {
      _current = const [];
      notifyListeners();
    }
  }

  /// Warms the first, next and previous posters for [languageCode] (the
  /// page's language; it may differ from the saved one).
  void warmFor(String languageCode) {
    _language = languageCode;
    _warmFirst();
  }

  void _warmFirst() {
    final slides = slidesFor(_language);
    if (slides == null || slides.isEmpty) return;
    for (final a in {slides.first, slides[1 % slides.length], slides.last}) {
      final url = a.imageUrl;
      if (a.kind != AnnouncementKind.poster || url == null || !_warmed.add(url)) continue;
      _warm(url);
    }
  }

  /// Loads [url] into the image cache without a widget: the stream is kept
  /// listened to until the image is decoded (or fails), and the cache keeps
  /// it after that, so the slide's NetworkImage of the same URL is ready.
  static void _warmNetworkImage(String url) {
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) => stream.removeListener(listener),
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  // ---- The persisted copy ----

  /// Only what some language would show, so the copy stays small.
  Future<void> _persist(List<Announcement> all) async {
    final keep = <String>{
      for (final language in AppDefaults.supportedLanguages)
        for (final a in UpdatesSelection.pick(all, languageCode: language)) a.id,
    };
    final raw = jsonEncode([for (final a in all) if (keep.contains(a.id)) _toStored(a)]);
    if (raw == _persisted) return;
    _persisted = raw;
    try {
      await (await _prefs()).setString(prefsKey, raw);
    } catch (e) {
      debugPrint('UpdatesStore could not save the last-known copy: $e');
    }
  }

  static Map<String, Object?> _toStored(Announcement a) => {
    _idKey: a.id,
    AnnouncementFields.kind: a.kind.key,
    AnnouncementFields.title: a.title,
    AnnouncementFields.message: a.message,
    AnnouncementFields.audience: a.audience.key,
    AnnouncementFields.imageUrl: a.imageUrl,
    AnnouncementFields.imageWidth: a.imageWidth,
    AnnouncementFields.imageHeight: a.imageHeight,
    AnnouncementFields.linkUrl: a.linkUrl,
    AnnouncementFields.linkLabel: a.linkLabel,
    AnnouncementFields.urgent: a.urgent,
    AnnouncementFields.timestamp: a.publishedAt?.millisecondsSinceEpoch,
  };

  /// One stored entry back through the document's own reading (unknown kind
  /// or audience: text, everyone) and the checks: the link sanitised, the
  /// image only at an http or https address. Null when it is not an entry.
  static Announcement? _fromStored(Object? item) {
    if (item is! Map) return null;
    final id = item[_idKey];
    if (id is! String || id.isEmpty) return null;
    String? text(String key) => item[key] is String ? item[key] as String : null;
    int? number(String key) => item[key] is int ? item[key] as int : null;
    final image = text(AnnouncementFields.imageUrl);
    final imageUri = image == null ? null : Uri.tryParse(image);
    final millis = number(AnnouncementFields.timestamp);
    return Announcement.fromMap(id, {
      AnnouncementFields.kind: text(AnnouncementFields.kind),
      AnnouncementFields.title: text(AnnouncementFields.title),
      AnnouncementFields.message: text(AnnouncementFields.message),
      AnnouncementFields.audience: text(AnnouncementFields.audience),
      if (imageUri != null && SocialLink.isLaunchable(imageUri)) AnnouncementFields.imageUrl: image,
      AnnouncementFields.imageWidth: number(AnnouncementFields.imageWidth),
      AnnouncementFields.imageHeight: number(AnnouncementFields.imageHeight),
      AnnouncementFields.linkUrl: SocialLink.sanitize(text(AnnouncementFields.linkUrl)) ?? '',
      AnnouncementFields.linkLabel: text(AnnouncementFields.linkLabel),
      AnnouncementFields.urgent: item[AnnouncementFields.urgent] == true,
      AnnouncementFields.hidden: false,
      if (millis != null) AnnouncementFields.timestamp: Timestamp.fromMillisecondsSinceEpoch(millis),
    });
  }
}
