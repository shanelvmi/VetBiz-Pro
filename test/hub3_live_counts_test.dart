// HUB3 (2) DATA: the live line costs one small listener, and it is the one
// the dashboard already had: Recent Activity's stream (the last 5 entries,
// newest first, recentActivityStream), shared, so All details' feed costs
// nothing more afterwards. An admin's is one listener; an assistant's is the
// pair today's rules require (entries they did, entries about them: each
// query must filter on one of those), merged, so the line only ever shows
// what the role already sees. Cancelling the line (a facility switch, a
// sign-out) closes it. No new Firestore rule: the queries are the ones the
// feed has always made.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/home_live_event.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';

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
  test('admin: one listener of 5 entries, newest first; the line shows the newest', () async {
    final db = await _seed();
    final stream = recentActivityStream(db, 'f1', isAdmin: true, uid: 'admin');
    final seen = <HomeLiveEvent?>[];
    final sub = homeLiveEvents(stream).listen(seen.add);
    await _settle();
    expect(db.listeners, 1);
    expect(db.reads, 5, reason: 'limit 5');
    expect(seen.last!.client, 'Client 7');
    // All details' feed listens to the same shared stream: nothing more.
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
    final seen = <HomeLiveEvent?>[];
    final sub = homeLiveEvents(stream).listen(seen.add);
    await _settle();
    expect(db.listeners, 2);
    expect(seen.last!.client, 'Client 7', reason: 'entry 7 is the assistant\'s');
    await sub.cancel();
    final other = recentActivityStream(db, 'f1', isAdmin: false, uid: 'nobody');
    final none = <HomeLiveEvent?>[];
    final sub2 = homeLiveEvents(other).listen(none.add);
    await _settle();
    expect(none, [null], reason: 'no entry of theirs: the empty line, never someone else\'s');
    await sub2.cancel();
  }, skip: _skip);

  test('the offline signal comes from the same listener (its snapshots\' metadata)', () async {
    final db = await _seed();
    final online = <bool>[];
    final stream = recentActivityStream(db, 'f1', isAdmin: true, uid: 'admin', onFromCache: (c) => online.add(!c));
    final sub = stream.listen((_) {});
    await _settle();
    expect(db.listeners, 1, reason: 'no second listener for the signal');
    expect(online.last, isTrue);
    await sub.cancel();
  }, skip: _skip);

  test('phone Home cold open and return, before and after HUB3', () async {
    final db = await _seed();
    final f = db.inner.collection(Collections.facilities).doc('f1');
    await f.collection(Collections.debts).add({'clientId': 'c1', 'amountOwed': 500.0, 'timestamp': testNow});
    db.resetCounts();
    final debts = DebtProvider(firestore: db)..listenToDebts('f1');
    final totals = DashboardSummaryService(firestore: db)
        .watchDashboardTotals(facilityId: 'f1', start: testToday, end: testNow)
        .listen((_) {});
    await HomeChartLoader(firestore: db).days('f1', now: testNow);
    await _settle();
    final before = (listeners: db.listeners, gets: db.gets, reads: db.reads);
    expect(before.listeners, 5, reason: 'HUB2: 4 period totals and the debts');

    final stream = recentActivityStream(db, 'f1', isAdmin: true, uid: 'admin');
    final line = homeLiveEvents(stream).listen((_) {});
    await _settle();
    expect(db.listeners, before.listeners + 1);
    expect(db.gets, before.gets);
    expect(db.reads - before.reads, 5);
    final cold = (listeners: db.listeners, reads: db.reads);
    // A return to Home: the same stream, held.
    await _settle();
    expect((db.listeners, db.reads), (cold.listeners, cold.reads));
    // ignore: avoid_print
    print('HUB3 phone Home: listeners ${before.listeners} -> ${cold.listeners} (admin; assistant +2, the rules\' pair); '
        'cold open reads +${cold.reads - before.reads}, gets +0; return to Home +0; All details\' feed +0 (shared)');
    await line.cancel();
    await totals.cancel();
    debts.clear();
  }, skip: _skip);
}
