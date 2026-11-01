// PH4 (2), (3), (5): All details (the eight figures as rows, the role rule,
// the screens they open, no truncated titles), tablets and computers keeping
// today's dashboard and loads, and the listeners and reads on a phone before
// and after, counted on the fake Firestore.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/dashboard/all_details_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';
import 'package:vetbiz_pro/services/sales_summary_service.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _totals = DashboardPeriodTotals(
  totalSales: 12500,
  totalCollected: 9700,
  totalProfit: 6000,
  totalRealizedProfit: 5000,
  totalUnrealizedProfit: 1000,
  netProfit: 4321,
  totalExpenses: 1500,
  completedServicesCount: 7,
  totalServiceRevenue: 5000,
);

const _figures = AllDetailsFigures(totals: _totals, productValue: 880000, outstanding: 8250.5, clients: 42);

Widget _details({bool isAdmin = true, List<DetailsTarget>? opened, String period = 'Today'}) => AllDetailsScreen(
      changes: ValueNotifier(0),
      figures: () => _figures,
      isAdmin: () => isAdmin,
      period: () => period,
      onPeriodChanged: (_) {},
      onOpen: (t) => opened?.add(t),
      chart: (_) => const SizedBox(height: 200, child: Text('CHART')),
      feed: (_) => const SizedBox(height: 200, child: Text('FEED')),
    );

void main() {
  group('All details', () {
    const labels = [
      'Total Product Value',
      'Total Sales (Today)',
      'Total Collected (Today)',
      'Net Profit (Today)',
      'Total Expenses (Today)',
      'Outstanding Payment',
      'Total Clients',
      'Completed Services (Today)',
    ];

    testWidgets('the eight cards as rows in order, label left and value right, then the chart and the feed',
        (tester) async {
      await pumpAtSize(tester, screen: _details(), size: const Size(390, 844));
      final ys = <double>[];
      for (final (label, value) in [
        (labels[0], Money.format(880000)),
        (labels[1], Money.format(12500)),
        (labels[2], Money.format(9700)),
        (labels[3], Money.format(4321)),
        (labels[4], Money.format(1500)),
        (labels[5], Money.format(8250.5)),
        (labels[6], '42'),
        (labels[7], '7'),
      ]) {
        await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
        final l = tester.getCenter(find.text(label));
        final v = tester.getCenter(find.text(value).first);
        expect(v.dx, greaterThan(l.dx), reason: label);
        expect((v.dy - l.dy).abs(), lessThan(4), reason: label);
        final row = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
        ys.add(tester.getTopLeft(find.text(label)).dy + Scrollable.of(tester.element(find.text(label))).position.pixels);
      }
      expect(ys, [...ys]..sort());
      expect(find.textContaining('Earned'), findsOneWidget);
      expect(find.textContaining('Pending'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('FEED'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.getTopLeft(find.text('CHART')).dy, lessThan(tester.getTopLeft(find.text('FEED')).dy));
    }, skip: _skip);

    testWidgets('each row opens the list its figure comes from', (tester) async {
      final opened = <DetailsTarget>[];
      await pumpAtSize(tester, screen: _details(opened: opened), size: const Size(390, 844));
      for (final label in labels) {
        await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text(label));
      }
      expect(opened, [
        DetailsTarget.products,
        DetailsTarget.sales,
        DetailsTarget.payments,
        DetailsTarget.reports,
        DetailsTarget.transactions,
        DetailsTarget.debtors,
        DetailsTarget.clients,
        DetailsTarget.services,
      ]);
    }, skip: _skip);

    testWidgets('an assistant: Net Profit masked as on today\'s card, no Earned or Pending', (tester) async {
      await pumpAtSize(tester, screen: _details(isAdmin: false), size: const Size(390, 844));
      expect(find.text(Money.format(4321)), findsNothing);
      expect(find.text('*****'), findsOneWidget);
      expect(find.textContaining('Earned'), findsNothing);
      expect(find.textContaining('Pending'), findsNothing);
      // Today's rule shows assistants Total Expenses (the card has no gate).
      expect(find.text('Total Expenses (Today)'), findsOneWidget);
    }, skip: _skip);

    group('sizes and looks: no overflow, 48 px targets, no truncated title', () {
      for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360)]) {
        for (final look in MatrixLook.values) {
          for (final admin in [true, false]) {
            final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name} ${admin ? 'admin' : 'assistant'}';
            testWidgets(where, (tester) async {
              await pumpAtSize(tester, screen: _details(isAdmin: admin, period: 'This Month'), size: size, look: look);
              await checkCase(tester, phone: true, where: where);
              for (final e in find.byType(RichText).evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                expect(p.didExceedMaxLines, isFalse, reason: '$where: "${p.text.toPlainText()}" is cut');
              }
            }, skip: _skip);
          }
        }
      }
    });
  });

  group('tablets and computers keep today\'s dashboard', () {
    for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: today\'s layout, no phone home', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: PhoneOrWide(phone: (_) => const Text('PHONE HOME'), wide: (_) => const Text('TODAY')),
        ));
        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('PHONE HOME'), findsNothing);
      }, skip: _skip);
    }

    test('their loads are unchanged: all five on every open, period change and return', () {
      const five = {
        DashboardLoad.periodTotals,
        DashboardLoad.previousPeriod,
        DashboardLoad.previousSnapshot,
        DashboardLoad.todayGlance,
        DashboardLoad.chart,
      };
      expect(dashboardLoadsFor(DashboardMoment.coldOpen, phone: false), {...five, DashboardLoad.recentActivity});
      expect(dashboardLoadsFor(DashboardMoment.periodChanged, phone: false), five);
      expect(dashboardLoadsFor(DashboardMoment.returnToHome, phone: false), five);
    }, skip: _skip);
  });

  group('listeners and reads on a phone, counted on the fake Firestore', () {
    const fid = 'f1';
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    Future<CountingFirestore> seeded() async {
      final db = CountingFirestore();
      final f = db.inner.collection(Collections.facilities).doc(fid);
      final now = DateTime.now();
      for (var i = 0; i < 14; i++) {
        final day = key(now.subtract(Duration(days: i)));
        await f.collection(Collections.dailySummaries).doc(day).set({'totalAmount': 1000.0 * i, 'saleCount': i});
        await f.collection(Collections.dailyCollections).doc(day).set({'totalCollected': 500.0 * i});
        await f.collection(Collections.dailyServiceSummaries).doc(day).set({'totalAmount': 300.0, 'serviceCount': 1});
        await f.collection(Collections.dailyTransactionSummaries).doc(day).set({'totalExpense': 100.0});
      }
      await f.collection(Collections.dailySnapshots).doc(key(now.subtract(const Duration(days: 1)))).set({'totalClients': 3});
      for (var i = 0; i < 8; i++) {
        await f.collection(Collections.activityLogs).add({
          'timestamp': now.subtract(Duration(minutes: i)),
          'userId': i.isEven ? 'u1' : 'u2',
          'targetUserId': 'x',
          'description': 'entry $i',
        });
      }
      return db;
    }

    /// The dashboard's loads, as dashboard_screen.dart makes them (Today).
    Future<void> run(CountingFirestore db, Set<DashboardLoad> loads, Map<DashboardLoad, StreamSubscription> live,
        {required bool isAdmin}) async {
      final summary = DashboardSummaryService(firestore: db);
      final sales = SalesSummaryService(firestore: db);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      for (final load in loads) {
        switch (load) {
          case DashboardLoad.periodTotals:
            // _loadPeriodTotals cancels the old subscription first.
            await live.remove(load)?.cancel();
            live[load] = summary.watchDashboardTotals(facilityId: fid, start: today, end: now).listen((_) {});
          case DashboardLoad.previousPeriod:
            await summary.getDashboardTotals(facilityId: fid, start: yesterday, end: yesterday);
          case DashboardLoad.previousSnapshot:
            await db
                .collection(Collections.facilities)
                .doc(fid)
                .collection(Collections.dailySnapshots)
                .doc(key(yesterday))
                .get();
          case DashboardLoad.todayGlance:
            await Future.wait([
              sales.getRangeTotals(facilityId: fid, start: today, end: today),
              sales.getTotalCollected(facilityId: fid, start: today, end: today),
              summary.getDashboardTotals(facilityId: fid, start: today, end: today),
              sales.getTotalOtherIncome(facilityId: fid, start: today, end: today),
            ]);
          case DashboardLoad.chart:
            final start = today.subtract(const Duration(days: 6));
            final prevEnd = start.subtract(const Duration(days: 1));
            final prevStart = prevEnd.subtract(const Duration(days: 6));
            await Future.wait([
              sales.getDailySummaries(facilityId: fid, start: start, end: today),
              sales.getDailyCollections(facilityId: fid, start: start, end: today),
              sales.getRangeTotals(facilityId: fid, start: prevStart, end: prevEnd),
              sales.getDailyServiceSummaries(facilityId: fid, start: start, end: today),
              sales.getTotalOtherIncome(facilityId: fid, start: start, end: today),
              sales.getDailyServiceSummaries(facilityId: fid, start: prevStart, end: prevEnd),
              sales.getTotalOtherIncome(facilityId: fid, start: prevStart, end: prevEnd),
            ]);
          case DashboardLoad.recentActivity:
            // The feed's stream is cached: made once.
            live[load] ??= recentActivityStream(db, fid, isAdmin: isAdmin, uid: 'u1').listen((_) {});
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    for (final isAdmin in [true, false]) {
      final role = isAdmin ? 'admin' : 'assistant';
      test('$role: Home starts fewer listeners and a return to Home reads nothing', () async {
        final results = <String, (int, int, int, int)>{};
        for (final phone in [false, true]) {
          // Before PH4 the phone's Home was the dashboard body with today's
          // loads (dashboardLoadsFor(phone: false)); after, phone: true.
          final db = await seeded();
          final live = <DashboardLoad, StreamSubscription>{};
          await run(db, dashboardLoadsFor(DashboardMoment.coldOpen, phone: phone), live, isAdmin: isAdmin);
          final coldListeners = db.listeners, coldReads = db.reads;
          db.resetCounts();
          await run(db, dashboardLoadsFor(DashboardMoment.returnToHome, phone: phone), live, isAdmin: isAdmin);
          results[phone ? 'after' : 'before'] = (coldListeners, coldReads, db.listeners, db.reads);
          for (final s in live.values) {
            await s.cancel();
          }
          expect(db.listeners, 0);
        }
        final (bListen, bReads, _, bReturn) = results['before']!;
        final (aListen, aReads, aListenAfterReturn, aReturn) = results['after']!;
        // ignore: avoid_print
        print('PH4 $role (dashboard-owned, Today): cold open listeners $bListen -> $aListen, reads $bReads -> $aReads; '
            'return to Home reads $bReturn -> $aReturn');
        expect(aListen, 4, reason: 'the four period totals listeners only');
        expect(bListen, isAdmin ? 5 : 6, reason: 'the period totals and Recent Activity');
        expect(aReads, lessThan(bReads));
        expect(aReturn, 0);
        expect(aListenAfterReturn, 4);
        expect(bReturn, greaterThan(0));
      }, skip: _skip);
    }

    test('opening All details: the chart\'s gets and Recent Activity, nothing else', () async {
      expect(dashboardLoadsFor(DashboardMoment.allDetailsOpened, phone: true),
          {DashboardLoad.chart, DashboardLoad.recentActivity});
      expect(dashboardLoadsFor(DashboardMoment.periodChanged, phone: true), {DashboardLoad.periodTotals});
    }, skip: _skip);
  });
}
