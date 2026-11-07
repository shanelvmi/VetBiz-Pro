// RV1 (docs/design/screen_reveal.md section 6, rule 8): Home's reveal adds no
// Firestore listener and no read. The loads are PH4's, and the gates watch
// what the dashboard already has (its period totals subscription through a
// notifier, the debts provider's own listener), counted on the fake.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/debt_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/counting_firestore.dart';

const _skip = true; // RV1: until the implementation

void main() {
  test('the loads are PH4\'s: phone cold open the period totals only, a return to Home nothing', () {
    expect(dashboardLoadsFor(DashboardMoment.coldOpen, phone: true), {DashboardLoad.periodTotals});
    expect(dashboardLoadsFor(DashboardMoment.returnToHome, phone: true), isEmpty);
    expect(dashboardLoadsFor(DashboardMoment.coldOpen, phone: false), {
      DashboardLoad.periodTotals,
      DashboardLoad.previousPeriod,
      DashboardLoad.previousSnapshot,
      DashboardLoad.todayGlance,
      DashboardLoad.chart,
      DashboardLoad.recentActivity,
    });
  }, skip: _skip);

  test('the phone gate adds no listener and no read: 4 period listeners and the debts\' 1, before and after',
      () async {
    final db = CountingFirestore();
    final f = db.inner.collection(Collections.facilities).doc('f1');
    await f.collection(Collections.debts).add({'clientId': 'c1', 'amountOwed': 500.0, 'timestamp': DateTime.now()});
    db.resetCounts();

    // As before RV1: the dashboard's period totals subscription and the
    // app-level debts listener.
    final debts = DebtProvider(firestore: db)..listenToDebts('f1');
    final now = DateTime.now();
    final answered = ValueNotifier(false);
    final sub = DashboardSummaryService(firestore: db)
        .watchDashboardTotals(facilityId: 'f1', start: DateTime(now.year, now.month, now.day), end: now)
        .listen((_) => answered.value = true, onError: (_) => answered.value = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final (listeners, reads) = (db.listeners, db.reads);
    expect(listeners, 5, reason: 'PH4: the four period totals listeners, plus the debts\'');

    // RV1: the gate, as dashboard_screen.dart makes it.
    final gate = RevealGate(primary: [
      ListenableRevealSource<bool>(answered, (v) => v),
      SelectorRevealSource<DebtProvider>(debts, (p) => p.loaded),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gate.isOpen, isTrue, reason: 'both had answered');
    expect(db.listeners, listeners);
    expect(db.reads, reads);
    // ignore: avoid_print
    print('RV1 phone Home: listeners $listeners -> ${db.listeners}, reads $reads -> ${db.reads}');

    gate.dispose();
    await sub.cancel();
    debts.clear();
    expect(db.listeners, 0);
  }, skip: _skip);

  test('the stream adapter passes the one subscription through: no second listener', () async {
    final db = CountingFirestore();
    final now = DateTime.now();
    final source = StreamRevealSource(DashboardSummaryService(firestore: db)
        .watchDashboardTotals(facilityId: 'f1', start: DateTime(now.year, now.month, now.day), end: now));
    final sub = source.stream.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(db.listeners, 4);
    expect(source.answered, isTrue);
    await sub.cancel();
    expect(db.listeners, 0);
  }, skip: _skip);

  test('DebtProvider.loaded: false until the first answer, false again after clear', () async {
    final db = CountingFirestore();
    final debts = DebtProvider(firestore: db);
    expect(debts.loaded, isFalse);
    debts.listenToDebts('f1');
    expect(debts.loaded, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(debts.loaded, isTrue, reason: 'an empty result answers');
    debts.clear();
    expect(debts.loaded, isFalse);
  }, skip: _skip);
}
