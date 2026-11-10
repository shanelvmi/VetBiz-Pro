// HUB2 (6): what Home costs on the counting fake, before and after HUB2. The
// card adds no listener (its figures are the period totals and the debts
// already watched); the charts add two range gets of at most 14 documents
// (the daily sales and service summaries), once a session, and no
// listener; the Product movement page adds Insights' sales get, only when
// shown, which Insights then reuses. A return to Home reads nothing.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';

import 'helpers/counting_firestore.dart';

const _skip = false;

void main() {
  test('cold open, return to Home, Product movement, then Insights', () async {
    final db = CountingFirestore();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String day(int back) {
      final d = today.subtract(Duration(days: back));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final f = db.inner.collection(Collections.facilities).doc('f1');
    for (var back = 0; back < 20; back++) {
      await f.collection(Collections.dailySummaries).doc(day(back)).set({'totalAmount': 1000.0});
      await f.collection(Collections.dailyServiceSummaries).doc(day(back)).set({'totalAmount': 500.0});
    }
    await f.collection(Collections.debts).add({'clientId': 'c1', 'amountOwed': 500.0, 'timestamp': now});
    await f.collection(Collections.sales).add({'timestamp': now, 'items': const []});
    db.resetCounts();

    // Before HUB2: the period totals (4 listeners) and the debts (1).
    final debts = DebtProvider(firestore: db)..listenToDebts('f1');
    final sub = DashboardSummaryService(firestore: db)
        .watchDashboardTotals(facilityId: 'f1', start: today, end: now)
        .listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = (listeners: db.listeners, gets: db.gets, reads: db.reads);
    expect(before.listeners, 5);

    // HUB2 cold open: the charts' two range gets, no listener.
    final charts = HomeChartLoader(firestore: db);
    await charts.days('f1');
    expect(db.listeners, before.listeners);
    expect(db.gets - before.gets, 2);
    expect(db.reads - before.reads, 28, reason: '14 days of each summary');
    final cold = (listeners: db.listeners, gets: db.gets, reads: db.reads);

    // A return to Home: nothing.
    await charts.days('f1');
    expect((db.listeners, db.gets, db.reads), (cold.listeners, cold.gets, cold.reads));

    // Product movement shown: Insights' sales get, once.
    final insights = InsightsDataLoader(firestore: db);
    await insights.sales('f1');
    await insights.sales('f1');
    expect(db.gets - cold.gets, 1);
    // Insights after it: its sales cost nothing, its services one get.
    await Future.wait([insights.sales('f1'), insights.services('f1')]);
    expect(db.gets - cold.gets, 2);
    expect(db.listeners, before.listeners, reason: 'no new listener anywhere');

    // ignore: avoid_print
    print('HUB2 phone Home: listeners ${before.listeners} -> ${cold.listeners}; cold open gets +2 '
        '(reads +${cold.reads - before.reads}); return to Home +0; Product movement +1 get; Insights then +1');
    await sub.cancel();
    debts.clear();
  }, skip: _skip);
}
