// PH4b (2) and (3), the owner's decisions. (2) Total Expenses is hidden from
// assistants everywhere: with Sales and Collected it would let them work out
// the Net Profit that is masked for them. On the tablet and computer grid and
// in the phone's All details; admins unchanged. A display rule only: the
// summaries stay readable by members under firestore.rules. (3) Each row of
// All details opens its list, for both roles; a row hidden from assistants is
// not drawn, so nothing opens.
//
// The dashboard itself still cannot be built in a test, so the grid is
// checked through the function its card list comes from
// (dashboardShowsFigure, dashboard_figures.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/dashboard/all_details_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_figures.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/services/dashboard_summary_service.dart';

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

const _expenses = 'Total Expenses (Today)';

const _labels = {
  DetailsTarget.products: 'Total Product Value',
  DetailsTarget.sales: 'Total Sales (Today)',
  DetailsTarget.payments: 'Total Collected (Today)',
  DetailsTarget.reports: 'Net Profit (Today)',
  DetailsTarget.transactions: _expenses,
  DetailsTarget.debtors: 'Outstanding Payment',
  DetailsTarget.clients: 'Total Clients',
  DetailsTarget.services: 'Completed Services (Today)',
};

Widget _details({required bool isAdmin, List<DetailsTarget>? opened}) => AllDetailsScreen(
      changes: ValueNotifier(0),
      figures: () => _figures,
      isAdmin: () => isAdmin,
      period: () => 'Today',
      onPeriodChanged: (_) {},
      onOpen: (t) => opened?.add(t),
      chart: (_) => const SizedBox(height: 200, child: Text('CHART')),
      feed: (_) => const SizedBox(height: 200, child: Text('FEED')),
    );

void main() {
  group('Total Expenses is for admins only', () {
    test('the figures each role is shown, in the grid\'s order', () {
      expect(dashboardFiguresFor(isAdmin: true), DashboardFigure.values);
      expect(dashboardFiguresFor(isAdmin: false), [
        DashboardFigure.productValue,
        DashboardFigure.sales,
        DashboardFigure.collected,
        DashboardFigure.netProfit,
        DashboardFigure.outstanding,
        DashboardFigure.clients,
        DashboardFigure.services,
      ]);
    }, skip: _skip);

    test('the tablet and computer grid: an assistant\'s Total Expenses card is not drawn; an admin\'s is', () {
      // The grid's card is drawn behind dashboardShowsFigure (dashboard_screen.dart).
      expect(dashboardShowsFigure(DashboardFigure.expenses, isAdmin: false), isFalse);
      expect(dashboardShowsFigure(DashboardFigure.expenses, isAdmin: true), isTrue);
      for (final f in DashboardFigure.values.where((f) => f != DashboardFigure.expenses)) {
        expect(dashboardShowsFigure(f, isAdmin: false), isTrue, reason: f.name);
        expect(dashboardShowsFigure(f, isAdmin: true), isTrue, reason: f.name);
      }
    }, skip: _skip);

    testWidgets('the phone\'s All details: an assistant has no Total Expenses row', (tester) async {
      await pumpAtSize(tester, screen: _details(isAdmin: false), size: const Size(390, 844));
      expect(find.text(_expenses), findsNothing);
      expect(find.text(Money.format(1500)), findsNothing);
      // Net Profit stays a masked row, as before.
      expect(find.text('Net Profit (Today)'), findsOneWidget);
      expect(find.text('*****'), findsOneWidget);
    }, skip: _skip);

    testWidgets('the phone\'s All details: an admin still has Total Expenses with its figure', (tester) async {
      await pumpAtSize(tester, screen: _details(isAdmin: true), size: const Size(390, 844));
      await tester.scrollUntilVisible(find.text(_expenses), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text(_expenses), findsOneWidget);
      expect(find.text(Money.format(1500)), findsOneWidget);
    }, skip: _skip);
  });

  group('each All details row opens its list', () {
    for (final isAdmin in [true, false]) {
      final role = isAdmin ? 'admin' : 'assistant';
      final shown = [
        for (final e in _labels.entries)
          if (isAdmin || e.key != DetailsTarget.transactions) e,
      ];

      testWidgets('$role: a tap on each row opens its list${isAdmin ? '' : '; Total Expenses is not there to tap'}',
          (tester) async {
        final opened = <DetailsTarget>[];
        await pumpAtSize(tester, screen: _details(isAdmin: isAdmin, opened: opened), size: const Size(390, 844));
        for (final e in shown) {
          await tester.scrollUntilVisible(find.text(e.value), 100, scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text(e.value));
        }
        expect(opened, [for (final e in shown) e.key]);
        if (!isAdmin) expect(find.text(_expenses), findsNothing);
      }, skip: _skip);

      test('$role: every row\'s list is one the role can open (a phone tab, or a place in More)', () {
        final more = moreItemsFor(isAdmin: isAdmin);
        for (final e in shown) {
          final item = detailsTargetMoreItem(e.key);
          if (item == null) {
            // Products and Sales: the bar's own tabs, for both roles.
            expect(e.key, isIn([DetailsTarget.products, DetailsTarget.sales]), reason: e.value);
          } else {
            expect(more, contains(item), reason: e.value);
          }
        }
      }, skip: _skip);
    }

    test('the rows lead where their figures come from', () {
      expect({for (final t in DetailsTarget.values) t: detailsTargetMoreItem(t)}, {
        DetailsTarget.products: null,
        DetailsTarget.sales: null,
        DetailsTarget.payments: MoreItem.payments,
        DetailsTarget.reports: MoreItem.reports,
        DetailsTarget.transactions: MoreItem.transactions,
        DetailsTarget.debtors: MoreItem.debtors,
        DetailsTarget.clients: MoreItem.clients,
        DetailsTarget.services: MoreItem.services,
      });
    }, skip: _skip);
  });
}
