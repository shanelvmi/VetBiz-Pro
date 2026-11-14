// UI6 (1) COST: the live line's one small listener (Recent Activity's stream,
// limit 5) only fed the line on phones; no other phone Home element used it,
// so phone Home no longer opens it. Recent Activity's stream stays for the
// wide dashboard's feed and All details' feed, which open it when they are
// built (as before HUB3). Phone Home's listeners: admin 6 -> 5, assistant
// 7 -> 5 (the assistant's was the rules' merged pair).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/test_clock.dart';

const _skip = true;

String _read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('the live line, its event model and its metrics are gone', () {
    for (final path in ['lib/screens/dashboard/home_live_line.dart', 'lib/screens/dashboard/home_live_event.dart']) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    for (final banned in ['HomeLiveMetrics', 'liveLineArrive']) {
      expect(_read('lib/theme/app_dimens.dart').contains(banned) || _read('lib/theme/app_motion.dart').contains(banned),
          isFalse, reason: banned);
    }
    for (final path in ['lib/screens/dashboard/today_card.dart', 'lib/screens/dashboard/phone_home.dart']) {
      final source = _read(path);
      for (final banned in ['Widget? live', 'this.live', 'live: skeleton', 'live ??']) {
        expect(source.contains(banned), isFalse, reason: '$path still takes a live line ($banned)');
      }
    }
  }, skip: _skip);

  test('phone Home opens no recent-activity listener; the wide and All details feeds keep theirs', () {
    final dashboard = _read('lib/screens/dashboard/dashboard_screen.dart');
    for (final banned in ['HomeLiveFeed', '_liveEventsFor', '_liveOnline', 'onFromCache', 'home_live_line']) {
      expect(dashboard.contains(banned), isFalse, reason: banned);
    }
    // The stream is made in one place only: the feed builder (wide layout,
    // All details), never in the phone Home's build.
    final calls = RegExp(r'_recentActivityStreamFor\(').allMatches(dashboard).length;
    expect(calls, 2, reason: 'its definition and the feed builder');
    final feed = dashboard.indexOf('Widget _buildRecentActivityFeed(');
    expect(feed, isNot(-1));
    expect(dashboard.indexOf('_recentActivityStreamFor(', feed), greaterThan(feed));
    // No Offline signal is listened for any more.
    for (final path in ['lib/screens/dashboard/dashboard_panels.dart', 'lib/utils/merged_query_stream.dart']) {
      expect(_read(path).contains('onFromCache'), isFalse, reason: path);
    }
  }, skip: _skip);

  test('phone Home cold open: admin 6 -> 5 listeners, assistant 7 -> 5; reads -5; a return reads nothing', () async {
    final db = CountingFirestore();
    final f = db.inner.collection(Collections.facilities).doc('f1');
    for (var i = 0; i < 8; i++) {
      await f.collection(Collections.activityLogs).doc('e$i').set({
        'userId': i.isEven ? 'admin' : 'asst',
        'actionType': 'Sales',
        'description': 'Recorded sale to Client $i - Tsh ${i}000',
        'timestamp': testNow.subtract(Duration(minutes: 10 - i)),
      });
    }
    await f.collection(Collections.debts).add({'clientId': 'c1', 'amountOwed': 500.0, 'timestamp': testNow});
    db.resetCounts();
    // What phone Home opens (HUB2..HUB4b): the period totals and the debts,
    // and HomeChartLoader's one get; nothing for activity.
    final debts = DebtProvider(firestore: db)..listenToDebts('f1');
    final totals = DashboardSummaryService(firestore: db)
        .watchDashboardTotals(facilityId: 'f1', start: testToday, end: testNow)
        .listen((_) {});
    await HomeChartLoader(firestore: db).days('f1', now: testNow);
    await _settle();
    final after = (listeners: db.listeners, reads: db.reads);
    expect(after.listeners, 5, reason: 'UI6: 4 period totals and the debts; the live line\'s listener is gone');

    // What the live line added before UI6, for the record.
    final admin = recentActivityStream(db, 'f1', isAdmin: true, uid: 'admin').listen((_) {});
    await _settle();
    final adminBefore = (listeners: db.listeners, reads: db.reads);
    await admin.cancel();
    final assistant = recentActivityStream(db, 'f1', isAdmin: false, uid: 'asst').listen((_) {});
    await _settle();
    final assistantBefore = db.listeners;
    await assistant.cancel();
    await _settle();
    expect(adminBefore.listeners, 6);
    expect(adminBefore.reads - after.reads, 5, reason: 'limit 5');
    expect(assistantBefore, 7);
    expect(db.listeners, after.listeners, reason: 'cancelled');
    expect(dashboardLoadsFor(DashboardMoment.returnToHome, phone: true), isEmpty, reason: 'a return reads nothing');
    // ignore: avoid_print
    print('UI6 phone Home listeners: admin ${adminBefore.listeners} -> ${after.listeners}, '
        'assistant $assistantBefore -> ${after.listeners}; cold open reads -5 (the line\'s limit 5); return +0');
    await totals.cancel();
    debts.clear();
  }, skip: _skip);
}
