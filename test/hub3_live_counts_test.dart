// HUB3 (2) DATA, after UI6: the live line is gone, so phone Home no longer
// listens to Recent Activity's stream (ui6_costs_test). The stream itself
// stays as HUB3 left it for the feeds that use it (the wide dashboard's,
// All details'): the last 5 entries, newest first, shared. An admin's is one
// listener; an assistant's is the pair today's rules require (entries they
// did, entries about them: each query must filter on one of those), merged,
// so a feed only ever shows what the role already sees. Cancelling closes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/test_clock.dart';

const _skip = false;

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

Future<CountingFirestore> _seed() async {
  final db = CountingFirestore();
  final logs = db.inner.collection(Collections.facilities).doc('f1').collection(Collections.activityLogs);
  for (var i = 0; i < 8; i++) {
    await logs.doc('e$i').set({
      'userId': i.isEven ? 'admin' : 'asst',
      'userName': 'X',
      'actionType': 'Sales',
      'description': 'Recorded sale to Client $i - Tsh ${i}000',
      'timestamp': testNow.subtract(Duration(minutes: 10 - i)),
    });
  }
  db.resetCounts();
  return db;
}

void main() {
  test('admin: one listener of 5 entries, newest first; shared by a second feed', () async {
    final db = await _seed();
    final stream = recentActivityStream(db, 'f1', isAdmin: true, uid: 'admin');
    final seen = <List<String>>[];
    final sub = stream.listen((docs) => seen.add([for (final d in docs) d.id]));
    await _settle();
    expect(db.listeners, 1);
    expect(db.reads, 5, reason: 'limit 5');
    expect(seen.last.first, 'e7', reason: 'newest first');
    // A second feed (All details) listens to the same shared stream.
    final feed = stream.listen((_) {});
    await _settle();
    expect(db.listeners, 1);
    expect(db.reads, 5);
    await feed.cancel();
    await sub.cancel();
    await _settle();
    expect(db.listeners, 0, reason: 'a facility switch or sign-out cancels it');
  }, skip: _skip);

  test('assistant: only what they did or what is about them (the rules\' pair, merged)', () async {
    final db = await _seed();
    final stream = recentActivityStream(db, 'f1', isAdmin: false, uid: 'asst');
    final seen = <List<String>>[];
    final sub = stream.listen((docs) => seen.add([for (final d in docs) d.id]));
    await _settle();
    expect(db.listeners, 2);
    expect(seen.last, ['e7', 'e5', 'e3', 'e1'], reason: 'the assistant\'s entries only');
    await sub.cancel();
    final other = recentActivityStream(db, 'f1', isAdmin: false, uid: 'nobody');
    final none = <List<String>>[];
    final sub2 = other.listen((docs) => none.add([for (final d in docs) d.id]));
    await _settle();
    expect(none, [<String>[]], reason: 'no entry of theirs: nothing, never someone else\'s');
    await sub2.cancel();
  }, skip: _skip);
}
