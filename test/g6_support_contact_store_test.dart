import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/services/updates_last_known.dart';

// G6, written before the store existed (skipped until it does): ONE read of
// app_config/support_contact for any number of callers, a copy in memory for
// the session, a persisted last-known copy (public fields only, sanitised
// again when read back), a revalidation that tells listeners only when the
// data changed, and a failed read that keeps the last-known.
const _skip = true;

const sixLinks = {
  'email': 'help@vetbiz.example',
  'facebook': 'facebook.com/vetbiz',
  'instagram': 'instagram.com/vetbiz',
  'x': 'x.com/vetbiz',
  'linkedin': 'linkedin.com/company/vetbiz',
  'youtube': 'youtube.com/@vetbiz',
  'tiktok': 'tiktok.com/@vetbiz',
};

/// A read of the document the test answers by hand, counting the reads.
class FakeContactRead {
  int reads = 0;
  final pending = <Completer<Map<String, dynamic>?>>[];

  Future<Map<String, dynamic>?> call(Object? db) {
    reads++;
    final c = Completer<Map<String, dynamic>?>();
    pending.add(c);
    return c.future;
  }

  void answer(Map<String, dynamic>? data) => pending.removeAt(0).complete(data);
  void fail() => pending.removeAt(0).completeError(Exception('offline'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Map<String, dynamic>?> persisted() async {
    final raw = (await SharedPreferences.getInstance()).getString(SupportContactStore.prefsKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  test('one read in flight for any number of callers', () async {
    final read = FakeContactRead();
    final store = SupportContactStore(fetch: read.call);
    final a = store.contact();
    final b = store.contact();
    store.revalidate();
    final c = store.contact();
    expect(read.reads, 1);
    read.answer(sixLinks);
    final results = await Future.wait([a, b, c]);
    expect(results.map((r) => r.socialLinks.length), [6, 6, 6]);
    // Fresh now: the copy is known at once and nobody reads again.
    expect(store.current?.socialLinks.length, 6);
    await store.contact();
    store.revalidate();
    expect(read.reads, 1);
  }, skip: _skip);

  test('a failed read keeps the last-known copy (and the next caller tries again)', () async {
    final read = FakeContactRead();
    var clock = DateTime(2026, 1, 1);
    final store = SupportContactStore(fetch: read.call, now: () => clock);
    final first = store.contact();
    read.answer(sixLinks);
    await first;
    clock = clock.add(const Duration(days: 1));
    final second = store.contact();
    expect(read.reads, 2);
    read.fail();
    expect((await second).socialLinks.length, 6);
    expect(store.current?.socialLinks.length, 6);
    final third = store.contact();
    expect(read.reads, 3);
    read.answer(sixLinks);
    await third;
  }, skip: _skip);

  test('a failed first read with nothing known gives the empty contact', () async {
    final read = FakeContactRead();
    final store = SupportContactStore(fetch: read.call);
    final first = store.contact();
    read.fail();
    expect(await first, SupportContact.empty);
    expect(store.current, isNull);
  }, skip: _skip);

  test('listeners hear a revalidation only when the data changed', () async {
    final read = FakeContactRead();
    var clock = DateTime(2026, 1, 1);
    final store = SupportContactStore(fetch: read.call, now: () => clock);
    var heard = 0;
    store.addListener(() => heard++);
    store.revalidate();
    read.answer(sixLinks);
    await pumpEventQueue();
    expect(heard, 1);
    clock = clock.add(const Duration(days: 1));
    store.revalidate();
    read.answer(Map.of(sixLinks));
    await pumpEventQueue();
    expect(heard, 1, reason: 'the same data: no rebuild');
    clock = clock.add(const Duration(days: 1));
    store.revalidate();
    read.answer({'facebook': 'facebook.com/vetbiz'});
    await pumpEventQueue();
    expect(heard, 2);
    expect(store.current?.socialLinks.single.key, SocialNetwork.facebook);
  }, skip: _skip);

  test('the persisted copy holds only the public contact fields', () async {
    final read = FakeContactRead();
    final store = SupportContactStore(fetch: read.call);
    final first = store.contact();
    read.answer({...sixLinks, 'updatedBy': 'admin-uid', 'notes': 'private'});
    await first;
    await pumpEventQueue();
    final saved = await persisted();
    expect(saved, isNotNull);
    expect(saved!.keys.toSet(), {'email', 'phone', 'whatsapp', 'address', for (final n in SocialNetwork.values) n.field});
    expect(saved['facebook'], 'https://facebook.com/vetbiz');
  }, skip: _skip);

  test('a cold start restores the persisted copy before any read', () async {
    SharedPreferences.setMockInitialValues({SupportContactStore.prefsKey: jsonEncode(sixLinks)});
    final read = FakeContactRead();
    final store = SupportContactStore(fetch: read.call);
    expect(store.current, isNull);
    await store.restore();
    expect(store.current?.socialLinks.length, 6);
    expect(store.current?.email, 'help@vetbiz.example');
    expect(read.reads, 0);
    // Not fresh yet: the first caller still revalidates.
    store.revalidate();
    expect(read.reads, 1);
    read.answer(sixLinks);
  }, skip: _skip);

  test('a stored invalid link or value is ignored when read back', () async {
    SharedPreferences.setMockInitialValues({
      SupportContactStore.prefsKey: jsonEncode({
        'facebook': 'javascript:alert(1)',
        'instagram': 'instagram.com/ok',
        'x': 'ftp://x.com/a',
        'youtube': 42,
        'email': ['not', 'text'],
      }),
    });
    final store = SupportContactStore(fetch: FakeContactRead().call);
    await store.restore();
    expect(store.current?.socialLinks.map((e) => e.key), [SocialNetwork.instagram]);
    expect(store.current?.email, '');
  }, skip: _skip);

  test('an unreadable persisted copy is ignored', () async {
    SharedPreferences.setMockInitialValues({SupportContactStore.prefsKey: '{not json'});
    final store = SupportContactStore(fetch: FakeContactRead().call);
    await store.restore();
    expect(store.current, isNull);
  }, skip: _skip);

  test('Updates last-known: unknown, then recorded, then restored on the next launch', () async {
    final first = UpdatesLastKnown();
    await first.restore();
    expect(first.hadUpdates, isNull);
    first.record(true);
    expect(first.hadUpdates, isTrue);
    await pumpEventQueue();
    final next = UpdatesLastKnown();
    await next.restore();
    expect(next.hadUpdates, isTrue);
    next.record(false);
    await pumpEventQueue();
    final third = UpdatesLastKnown();
    await third.restore();
    expect(third.hadUpdates, isFalse);
  }, skip: _skip);
}
