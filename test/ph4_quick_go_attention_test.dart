// PH4 (1), (5), as UI5 reshaped them: the record tiles of Home's grid (once
// Quick access, through the "+" sheet's guard), what View all offered (now
// the "+" sheet's More group), the places (once Go to: the grid's second
// row, the bottom bar and More) and the one Needs attention strip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';

import 'helpers/phone_home_harness.dart';

const _skip = false;

/// A page with one button that opens the "+" sheet as the shell does.
Widget _sheetHost(Future<void> Function(BuildContext) open) => Scaffold(
      body: Builder(builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open'))),
    );

void main() {
  group('the record tiles (Quick access before UI5)', () {
    const tiles = ['Record Sale', 'Record Visit', 'Record Payment', 'Add Client'];

    RecordSheetActions actions(List<String> opened) => RecordSheetActions(
          recordSale: (_) async => opened.add('sale'),
          recordVisit: (_) async => opened.add('visit'),
          recordPayment: (_, __) async => opened.add('payment'),
          addClient: (_) async => opened.add('client'),
          fetchDebtors: (_) async => [Client.fromMap('c1', {'name': 'Juma', 'phone': '0712000000', 'balance': 500})],
        );

    Future<void> run(BuildContext context, HomeTile tile, RecordSheetActions a, RecordGuard guard) =>
        runRecordAction(context, homeTileAction(tile)!, actions: a, guard: guard);

    testWidgets('the four tiles, in the sheet\'s order with its labels, on the first row', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness());
      final xs = [for (final t in tiles) tester.getCenter(find.text(t)).dx];
      expect(xs, [...xs]..sort());
      final ys = {for (final t in tiles) tester.getTopLeft(find.text(t)).dy};
      expect(ys, hasLength(1));
    }, skip: _skip);

    testWidgets('each goes through the "+" sheet\'s guard; locked, no form opens', (tester) async {
      final guarded = <String>[];
      final opened = <String>[];
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(
          onTile: (context, t) => run(context, t, actions(opened),
              (context, destination, {onNavigate}) async => guarded.add(destination.runtimeType.toString())),
        ),
      );
      for (final t in tiles) {
        await tester.tap(find.text(t));
        await tester.pumpAndSettle();
      }
      expect(guarded, ['AddSaleScreen', 'AddEditServiceScreen', 'AddPaymentScreen', 'AddClientScreen']);
      expect(opened, isEmpty);
    }, skip: _skip);

    testWidgets('unlocked, each opens its form (Record Payment with the debtors)', (tester) async {
      final opened = <String>[];
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(
          onTile: (context, t) =>
              run(context, t, actions(opened), (context, destination, {onNavigate}) async => onNavigate?.call()),
        ),
      );
      for (final t in tiles) {
        await tester.tap(find.text(t));
        await tester.pumpAndSettle();
      }
      expect(opened, ['sale', 'visit', 'payment', 'client']);
    }, skip: _skip);

    testWidgets('no "View all" and no section titles on Home', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness());
      for (final t in ['View all', 'Quick access', 'Go to', 'Needs attention']) {
        expect(find.text(t), findsNothing, reason: t);
      }
    }, skip: _skip);
  });

  group('what View all offered: the "+" sheet\'s More group', () {
    for (final admin in [true, false]) {
      testWidgets('the four, then More with the role\'s extras (${admin ? 'admin' : 'assistant'})', (tester) async {
        await pumpPhoneHome(tester, _sheetHost((context) => showRecordSheet(context, isAdmin: admin)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final expected = [
          'Record Sale',
          'Record Visit',
          'Record Payment',
          'Add Client',
          if (admin) 'Add Product',
          'Add New Batch',
          'Record Transaction',
        ];
        final sheet = find.byType(BottomSheet);
        for (final row in expected) {
          expect(find.descendant(of: sheet, matching: find.text(row)), findsOneWidget, reason: row);
        }
        if (!admin) expect(find.descendant(of: sheet, matching: find.text('Add Product')), findsNothing);
        expect(find.descendant(of: sheet, matching: find.text('More')), findsOneWidget);
        expect(tester.getTopLeft(find.text('More')).dy, greaterThan(tester.getTopLeft(find.text('Add Client')).dy));
        expect([...recordActionsFor(isAdmin: admin), ...recordMoreActionsFor(isAdmin: admin)], hasLength(expected.length));
      }, skip: _skip);
    }

    testWidgets('the More rows go through the guard too; locked, no form opens', (tester) async {
      final guarded = <String>[];
      await pumpPhoneHome(
        tester,
        _sheetHost((context) => showRecordSheet(context,
            isAdmin: true,
            guard: (context, destination, {onNavigate}) async => guarded.add(destination.runtimeType.toString()))),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final row in ['Add Product', 'Add New Batch', 'Record Transaction']) {
        await tester.ensureVisible(find.text(row));
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
      }
      expect(guarded, hasLength(3));
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'locked: the sheet stays, no form');
    }, skip: _skip);
  });

  group('the places (Go to before UI5)', () {
    test('the grid\'s second row: Debtors, Stock Store, Reports, Transactions; the rest stay reachable', () {
      expect([for (final t in homeTilesFor(isAdmin: true)) homeTilePlace(t)].whereType<MoreItem>(),
          [MoreItem.debtors, MoreItem.stockStore, MoreItem.reports, MoreItem.transactions]);
      // Go to's Clients, Services and Payments are on the More page for both
      // roles; Products is the bottom bar's tab.
      for (final admin in [true, false]) {
        expect(moreItemsFor(isAdmin: admin), containsAll([MoreItem.clients, MoreItem.services, MoreItem.payments]));
      }
    }, skip: _skip);

    testWidgets('a place tile opens its place', (tester) async {
      final went = <HomeTile>[];
      await pumpPhoneHome(tester, phoneHomeHarness(onTile: (_, t) async => went.add(t)));
      for (final t in ['Debtors', 'Stock Store', 'Reports', 'Transactions']) {
        await tester.tap(find.text(t));
      }
      expect(went, [HomeTile.debtors, HomeTile.stockStore, HomeTile.reports, HomeTile.transactions]);
    }, skip: _skip);
  });

  group('Needs attention', () {
    test('counts from memory: overdue debtors by the facility\'s setting (attentionCountsFor)', () {
      final products = [
        ph4Product('fine'),
        ph4Product('low', qty: 3),
        ph4Product('out', qty: 0),
        ph4Product('new', qty: 0, everStocked: false),
        ph4Product('expiring', expiry: ph4Now.add(const Duration(days: 10))),
        ph4Product('expired', expiry: ph4Now.subtract(const Duration(days: 2))),
        ph4Product('lowAndExpiring', qty: 2, expiry: ph4Now.add(const Duration(days: 5))),
      ];
      final debts = [
        ph4Debt('a', 1000, 45), // overdue
        ph4Debt('a', 500, 50), // same client
        ph4Debt('b', 200, 31), // overdue
        ph4Debt('c', 900, 10), // recent
        ph4Debt('d', 0, 90), // paid
      ];
      final counts = attentionCountsFor(products: products, debts: debts, overdueDays: 30, now: ph4Now);
      expect(counts.stock, 3);
      expect(counts.expiry, 3);
      expect(counts.overdueDebtors, 2);
      expect(attentionCountsFor(products: products, debts: debts, overdueDays: 60, now: ph4Now).overdueDebtors, 0);
      // UI5: the same data as items, most urgent first.
      expect(attentionItemsFor(products: products, debts: debts, overdueDays: 30, isAdmin: true, now: ph4Now), const [
        AttentionItem(AttentionKind.expired, 1),
        AttentionItem(AttentionKind.outOfStock, 1),
        AttentionItem(AttentionKind.overdueDebts, 2),
        AttentionItem(AttentionKind.expiringSoon, 2),
        AttentionItem(AttentionKind.lowStock, 2),
      ]);
    }, skip: _skip);

    testWidgets('absent when nothing needs attention', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(attention: const []));
      expect(find.byType(AttentionStrip), findsNothing);
    }, skip: _skip);

    testWidgets('one strip under the card with the first item and +N; its tap opens the sheet', (tester) async {
      var taps = 0;
      await pumpPhoneHome(tester, phoneHomeHarness(onAttention: (_) => taps++));
      expect(find.byType(AttentionStrip), findsOneWidget);
      expect(find.text('Out of stock: 3 products'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(AttentionStrip)).dy,
          greaterThan(tester.getBottomLeft(find.byType(TodayCard)).dy));
      await tester.tap(find.byType(AttentionStrip));
      expect(taps, 1);
    }, skip: _skip);
  });
}
