import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/announcement_fields.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/services/updates_store.dart';
import 'package:vetbiz_pro/widgets/announcement_poster.dart';

// AN6, written before the store: ONE shared subscription to the
// announcements, started at app start; an in-memory list known at once; a
// persisted last-known copy (public fields only, validated again when read
// back); a failed read keeps the last-known list; the audience, urgent and
// five-slide rules applied per language when read; the first, next and
// previous posters warmed once per URL.
const _skip = false;

class _Feed {
  int subscribes = 0;
  final controller = StreamController<List<Announcement>>.broadcast();
  Stream<List<Announcement>> call(FirebaseFirestore? db) {
    subscribes++;
    return controller.stream;
  }
}

Announcement _a(String id, {String kind = 'text', String audience = 'all', bool urgent = false, bool hidden = false, int day = 1, String? image, String? link}) =>
    Announcement.fromMap(id, {
      'kind': kind,
      'title': 'Title $id',
      'message': 'Message $id',
      'audience': audience,
      'urgent': urgent,
      'hidden': hidden,
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, day)),
      if (image != null) 'imageUrl': image,
      if (link != null) ...{'linkUrl': link, 'linkLabel': 'Open'},
    });

void main() {
  late _Feed feed;
  late List<String> warmed;
  UpdatesStore store() => UpdatesStore(subscribe: feed.call, warm: warmed.add);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    feed = _Feed();
    warmed = [];
  });

  test('ONE subscription however many readers start it', () async {
    final s = store();
    s.start();
    s.start();
    s.start();
    expect(feed.subscribes, 1);
  }, skip: _skip);

  test('nothing known before the first answer; then the list at once, and live changes', () async {
    final s = store()..start();
    expect(s.current, isNull);
    expect(s.slidesFor('en'), isNull);
    var told = 0;
    s.addListener(() => told++);
    feed.controller.add([_a('1'), _a('2')]);
    await pumpEventQueue();
    expect(s.current!.map((a) => a.id), ['1', '2']);
    feed.controller.add([_a('3')]);
    await pumpEventQueue();
    expect(s.current!.map((a) => a.id), ['3']);
    expect(told, 2);
  }, skip: _skip);

  test('an empty answer is known and empty (not "nothing known")', () async {
    final s = store()..start();
    feed.controller.add([]);
    await pumpEventQueue();
    expect(s.slidesFor('en'), isEmpty);
  }, skip: _skip);

  test('the persisted copy restores before any read, and a later launch starts from it', () async {
    final first = store()..start();
    feed.controller.add([_a('1'), _a('h', hidden: true), _a('2', kind: 'poster', image: 'https://files.example/2.png')]);
    await pumpEventQueue();
    final next = store();
    await next.restore();
    expect(next.current!.map((a) => a.id), ['1', '2'], reason: 'a hidden one is never stored');
    expect(next.current![1].kind, AnnouncementKind.poster);
    expect(next.current![1].imageUrl, 'https://files.example/2.png');
    expect(next.current![0].publishedAt, DateTime(2026, 1, 1));
    expect(first.current, isNotNull);
  }, skip: _skip);

  test('a restore after an answer does not replace it', () async {
    SharedPreferences.setMockInitialValues({UpdatesStore.prefsKey: jsonEncode([{'id': 'old', 'title': 'Old'}])});
    final s = store()..start();
    feed.controller.add([_a('new')]);
    await pumpEventQueue();
    await s.restore();
    expect(s.current!.map((a) => a.id), ['new']);
  }, skip: _skip);

  test('the persisted copy goes through the validators: audience, link, image address', () async {
    SharedPreferences.setMockInitialValues({
      UpdatesStore.prefsKey: jsonEncode([
        {'id': '1', 'kind': 'poster', 'title': 'P', 'audience': 'xx', 'imageUrl': 'javascript:alert(1)', 'linkUrl': 'javascript:alert(1)', 'linkLabel': 'Go', 'timestamp': 0},
        {'id': '2', 'kind': 'text', 'title': 'T', 'audience': 'sw', 'linkUrl': 'https://a.example/x', 'linkLabel': 'Go', 'urgent': 'yes'},
        'not a map',
        {'title': 'no id'},
      ]),
    });
    final s = store();
    await s.restore();
    expect(s.current!.map((a) => a.id), ['1', '2']);
    final [one, two] = s.current!;
    expect(one.audience, AnnouncementAudience.all, reason: 'an unknown audience reads as everyone');
    expect(one.imageUrl, isNull, reason: 'only an http or https image address is kept');
    expect(AnnouncementLinkButton.addressOf(one), isNull, reason: 'javascript: is never a link');
    expect(two.audience, AnnouncementAudience.sw);
    expect(AnnouncementLinkButton.addressOf(two), 'https://a.example/x');
    expect(two.urgent, isFalse, reason: 'only a real true is urgent');
  }, skip: _skip);

  test('an unreadable persisted copy is ignored', () async {
    SharedPreferences.setMockInitialValues({UpdatesStore.prefsKey: '{not json'});
    final s = store();
    await s.restore();
    expect(s.current, isNull);
  }, skip: _skip);

  test('a failed read keeps the last-known list; with nothing known it answers empty (never loading for ever)', () async {
    final seeded = store()..start();
    feed.controller.add([_a('1')]);
    await pumpEventQueue();
    feed.controller.addError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await pumpEventQueue();
    expect(seeded.current!.map((a) => a.id), ['1']);

    final fresh = UpdatesStore(subscribe: (_) => Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), warm: warmed.add);
    fresh.start();
    await pumpEventQueue();
    expect(fresh.slidesFor('en'), isEmpty);
  }, skip: _skip);

  test('per language when read: the audience, urgent ones take over, five at most', () async {
    final s = store()..start();
    // Newest first, as the query gives them.
    feed.controller.add([
      _a('sw', audience: 'sw', day: 25),
      _a('swUrgent', audience: 'sw', urgent: true, day: 24),
      _a('en', audience: 'en', day: 23),
      for (var i = 1; i <= 7; i++) _a('all$i', day: 20 - i),
    ]);
    await pumpEventQueue();
    expect(s.current, hasLength(10), reason: 'stored whole, filtered when read');
    expect(s.slidesFor('sw')!.map((a) => a.id), ['swUrgent']);
    expect(s.slidesFor('en')!.map((a) => a.id), ['en', 'all1', 'all2', 'all3', 'all4']);
    expect(s.slidesFor('en'), hasLength(AppLimits.updatesMaxSlides));
  }, skip: _skip);

  test('warming: the first, next and previous posters for the language, once per URL', () async {
    final s = store()..start();
    s.warmFor('en');
    expect(warmed, isEmpty, reason: 'nothing known yet');
    final list = [
      _a('a', kind: 'poster', image: 'https://f.example/a.png', day: 9),
      _a('b', kind: 'poster', image: 'https://f.example/b.png', day: 8),
      _a('c', kind: 'poster', image: 'https://f.example/c.png', day: 7),
      _a('d', kind: 'poster', image: 'https://f.example/d.png', day: 6),
      _a('sw', kind: 'poster', audience: 'sw', image: 'https://f.example/sw.png', day: 5),
    ];
    feed.controller.add(list);
    await pumpEventQueue();
    expect(warmed.toSet(), {'https://f.example/a.png', 'https://f.example/b.png', 'https://f.example/d.png'});
    feed.controller.add(list);
    await pumpEventQueue();
    s.warmFor('en');
    expect(warmed, hasLength(3), reason: 'once per URL');
  }, skip: _skip);

  test('warming at startup: from the persisted copy, for the saved language', () async {
    final seed = store()..start();
    feed.controller.add([_a('sw', kind: 'poster', audience: 'sw', image: 'https://f.example/sw.png')]);
    await pumpEventQueue();
    final saved = (await SharedPreferences.getInstance()).getString(UpdatesStore.prefsKey)!;
    expect(seed.current, isNotNull);
    SharedPreferences.setMockInitialValues({UpdatesStore.prefsKey: saved, UiSettingsProvider.languageKey: 'sw'});
    warmed.clear();
    await store().restore();
    expect(warmed, ['https://f.example/sw.png']);
  }, skip: _skip);
}
