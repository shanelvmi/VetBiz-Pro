// PH4 (1), (5): the phone home (phone_shell.md D2 and section 3): its sizes
// and looks, the Today card's figures against the old cards' for the same
// fake data and the period chip, the role rules, the top bar.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

void main() {
  group('the phone home at phone sizes', () {
    for (final s in ph4PhoneSizes) {
      for (final look in MatrixLook.values) {
        for (final admin in [true, false]) {
          final where = '${matrixCase(s, look)} ${admin ? 'admin' : 'assistant'}';
          testWidgets(where, (tester) async {
            await pumpAtSize(tester, screen: phoneHomeHarness(isAdmin: admin), size: s.size, look: look);
            await checkCase(tester, phone: true, where: where);
            // The page scrolls: the last section is reachable and fits too.
            await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
            await tester.pumpAndSettle();
            await checkCase(tester, phone: true, where: '$where, scrolled');
          }, skip: _skip);
        }
      }
    }
    testWidgets(matrixTextScaleCase, (tester) async {
      await pumpAtSize(tester, screen: phoneHomeHarness(), size: ph4PhoneSizes.first.size, textScale: matrixLargeTextScale);
      await checkCase(tester, phone: true, where: matrixTextScaleCase);
    }, skip: _skip);
  });

  group('the Today card', () {
    Future<DashboardPeriodTotals> totalsFor(FakeFirebaseFirestore db, DateTime start) => DashboardSummaryService(firestore: db)
        .getDashboardTotals(facilityId: 'f1', start: start, end: ph4Now);

    Future<FakeFirebaseFirestore> seeded() async {
      final db = FakeFirebaseFirestore();
      final f = db.collection(Collections.facilities).doc('f1');
      String key(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final jan1 = DateTime(ph4Now.year, 1, 1);
      for (final (day, scale) in [(ph4Now, 1.0), (jan1, 10.0)]) {
        await f.collection(Collections.dailySummaries).doc(key(day)).set({
          'totalAmount': 12500 * scale,
          'totalProfit': 4000 * scale,
          'totalRealizedProfit': 3000 * scale,
          'totalUnrealizedProfit': 1000 * scale,
        });
        await f.collection(Collections.dailyCollections).doc(key(day)).set({'totalCollected': 9000 * scale});
        await f.collection(Collections.dailyServiceSummaries).doc(key(day)).set(
            {'totalAmount': 5000 * scale, 'totalServiceProfit': 2000 * scale, 'serviceCount': 2 * scale});
        await f.collection(Collections.dailyTransactionSummaries).doc(key(day)).set(
            {'totalExpense': 1500 * scale, 'totalProfit': 0, 'totalOtherIncome': 700 * scale});
      }
      return db;
    }

    testWidgets('Sales, Collected, Owed and Net profit are the old cards\' figures, and follow the period chip',
        (tester) async {
      final db = await seeded();
      final debts = [ph4Debt('c1', 7000, 3), ph4Debt('c2', 1250.5, 40)];
      final owed = debts.fold<double>(0, (t, d) => t + d.amountOwed); // DebtProvider.totalOutstanding
      final today = (await tester.runAsync(() => totalsFor(db, DateTime(ph4Now.year, ph4Now.month, ph4Now.day))))!;
      final year = (await tester.runAsync(() => totalsFor(db, DateTime(ph4Now.year, 1, 1))))!;

      var period = 'Today';
      late StateSetter rebuild;
      await pumpPhoneHome(
        tester,
        StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          final totals = period == 'Today' ? today : year;
          return phoneHomeHarness(
            figures: PhoneHomeFigures.from(totals, owed: owed),
            period: period,
            onPeriodChanged: (p) => rebuild(() => period = p),
          );
        }),
      );
      // The old cards: Money.format(_periodTotals.totalSales / totalCollected
      // / netProfit) and Money.format(debtProvider.totalOutstanding()).
      for (final v in [today.totalSales, today.totalCollected, today.netProfit, owed]) {
        expect(find.text(Money.format(v)), findsWidgets, reason: Money.format(v));
      }
      await tester.tap(find.byTooltip('Change period'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This Year').last);
      await tester.pumpAndSettle();
      expect(period, 'This Year');
      if (ph4Now.month != 1 || ph4Now.day != 1) {
        expect(year.totalSales, greaterThan(today.totalSales));
        for (final v in [year.totalSales, year.totalCollected, year.netProfit]) {
          expect(find.text(Money.format(v)), findsWidgets, reason: Money.format(v));
        }
        expect(find.text(Money.format(today.totalSales)), findsNothing);
      }
    }, skip: _skip);

    testWidgets('an assistant sees Sales, Collected and Owed only: no Net profit, two columns', (tester) async {
      const figures = PhoneHomeFigures(sales: 100, collected: 200, owed: 300, netProfit: 987654);
      await pumpPhoneHome(tester, phoneHomeHarness(figures: figures, isAdmin: false));
      expect(find.text('Net profit'), findsNothing);
      expect(drawnTexts(tester).where((t) => t.contains(Money.format(987654))), isEmpty);
      expect(find.textContaining('Expenses'), findsNothing);
      expect(find.textContaining('Sales'), findsWidgets);
      for (final label in ['Collected', 'Owed']) {
        expect(find.text(label), findsWidgets);
      }
      final collected = tester.getSize(find.ancestor(of: find.text('Collected'), matching: find.byType(Expanded)).first);
      // UI5: the chevron takes the row's end; three columns would be about 100.
      expect(collected.width, greaterThan(140), reason: 'two columns');
    }, skip: _skip);

    testWidgets('an admin sees Net profit in a third column', (tester) async {
      const figures = PhoneHomeFigures(sales: 100, collected: 200, owed: 300, netProfit: 987654);
      await pumpPhoneHome(tester, phoneHomeHarness(figures: figures));
      expect(find.text('Net profit'), findsOneWidget);
      expect(find.text(Money.format(987654)), findsOneWidget);
    }, skip: _skip);

    // UI5: the whole card is the button (no "All details" line).
    testWidgets('All details opens from the card', (tester) async {
      var opened = 0;
      await pumpPhoneHome(tester, phoneHomeHarness(onAllDetails: () => opened++));
      await tester.tap(find.text('Collected'));
      expect(opened, 1);
    }, skip: _skip);
  });


  // UI5: the facility name (16, semibold) over the greeting with the name
  // (12, muted).
  testWidgets('the top bar: the facility name over the greeting', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness(facilityName: 'Kilimo Agrovet'));
    final name = tester.getTopLeft(find.text('Kilimo Agrovet'));
    final greeting = tester.getTopLeft(find.text(ph4Greeting));
    expect(name.dy, lessThan(greeting.dy));
    expect(tester.widget<Text>(find.text(ph4Greeting)).style!.fontSize, 12);
    expect(tester.widget<Text>(find.text('Kilimo Agrovet')).style!.fontSize, 16);
  }, skip: _skip);

  test('the period chip offers the dashboard\'s four periods, stored in English', () {
    expect(dashboardPeriods, ['Today', 'This Week', 'This Month', 'This Year']);
    final l = lookupAppLocalizations(const Locale('sw'));
    expect(dashboardPeriodLabel(l, 'Today'), l.common_today);
  }, skip: _skip);
}
