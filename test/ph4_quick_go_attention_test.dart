// PH4 (1), (5): the phone home's Quick access (through the "+" sheet's guard)
// and View all, the Go to row, and the Needs attention strip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';

import 'helpers/phone_home_harness.dart';

const _skip = true; // PH4: until the phone home is implemented

void main() {
  group('Quick access', () {
    const tiles = ['Record Sale', 'Record Visit', 'Record Payment', 'Add Client'];

    RecordSheetActions actions(List<String> opened) => RecordSheetActions(
          recordSale: (_) async => opened.add('sale'),
          recordVisit: (_) async => opened.add('visit'),
          recordPayment: (_, __) async => opened.add('payment'),
          addClient: (_) async => opened.add('client'),
          fetchDebtors: (_) async => [Client.fromMap('c1', {'name': 'Juma', 'phone': '0712000000', 'balance': 500})],
        );

    testWidgets('the four tiles, in the sheet\'s order with its labels', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness());
      final xs = [for (final t in tiles) tester.getCenter(find.text(t)).dx];
      expect(xs, [...xs]..sort());
    }, skip: _skip);

    testWidgets('each tile goes through the "+" sheet\'s guard; locked, no form opens', (tester) async {
      final guarded = <String>[];
      final opened = <String>[];
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(
          onQuickAction: (context, a) => runRecordAction(context, a,
              actions: actions(opened),
              guard: (context, destination, {onNavigate}) async => guarded.add(destination.runtimeType.toString())),
        ),
      );
      for (final t in tiles) {
        await tester.tap(find.text(t));
        await tester.pumpAndSettle();
      }
      expect(guarded, ['AddSaleScreen', 'AddEditServiceScreen', 'AddPaymentScreen', 'AddClientScreen']);
      expect(opened, isEmpty);
    }, skip: _skip);

    testWidgets('unlocked, each tile opens its form (Record Payment with the debtors)', (tester) async {
      final opened = <String>[];
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(
          onQuickAction: (context, a) => runRecordAction(context, a,
              actions: actions(opened), guard: (context, destination, {onNavigate}) async => onNavigate?.call()),
        ),
      );
      for (final t in tiles) {
        await tester.tap(find.text(t));
        await tester.pumpAndSettle();
      }
      expect(opened, ['sale', 'visit', 'payment', 'client']);
    }, skip: _skip);

    for (final admin in [true, false]) {
      testWidgets('View all: the sheet with the other actions (${admin ? 'admin' : 'assistant'})', (tester) async {
        await pumpPhoneHome(tester, phoneHomeHarness(isAdmin: admin, onViewAll: (context) => showRecordSheet(context, all: true, isAdmin: admin)));
        await tester.tap(find.text('View all'));
        await tester.pumpAndSettle();
        final expected = [...tiles, if (admin) 'Add Product', 'Add New Batch', 'Record Transaction'];
        final sheet = find.byType(BottomSheet);
        for (final row in expected) {
          expect(find.descendant(of: sheet, matching: find.text(row)), findsOneWidget, reason: row);
        }
        if (!admin) expect(find.descendant(of: sheet, matching: find.text('Add Product')), findsNothing);
        expect(recordActionsFor(isAdmin: admin, all: true), hasLength(expected.length));
      }, skip: _skip);
    }

    testWidgets('View all rows go through the guard too; locked, no form opens', (tester) async {
      final guarded = <String>[];
      await pumpPhoneHome(
        tester,
        phoneHomeHarness(
          onViewAll: (context) => showRecordSheet(context,
              all: true,
              isAdmin: true,
              actions: actions([]),
              guard: (context, destination, {onNavigate}) async => guarded.add(destination.runtimeType.toString())),
        ),
      );
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      for (final row in ['Add Product', 'Add New Batch', 'Record Transaction']) {
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
      }
      expect(guarded, hasLength(3));
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'locked: the sheet stays, no form');
    }, skip: _skip);
  });

  group('Go to', () {
    const order = ['Products', 'Clients', 'Debtors', 'Reports', 'Transactions', 'Stock Store', 'Services', 'Payments'];

    test('section 4\'s order for both roles; nothing is admin-only', () {
      for (final admin in [true, false]) {
        expect(goToItemsFor(isAdmin: admin), [
          GoToItem.products,
          GoToItem.clients,
          GoToItem.debtors,
          GoToItem.reports,
          GoToItem.transactions,
          GoToItem.stockStore,
          GoToItem.services,
          GoToItem.payments,
        ]);
      }
    }, skip: _skip);

    testWidgets('the row shows them in order, scrolls sideways, and a tap opens its place', (tester) async {
      final went = <GoToItem>[];
      await pumpPhoneHome(tester, phoneHomeHarness(onGoTo: went.add));
      final row = find.byKey(const ValueKey('phone-home-go-to'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      // Labels in the row, left to right, as it scrolls (a ListView builds
      // only what is near the screen).
      List<String> shown() {
        final items = find.descendant(of: row, matching: find.byType(Text)).evaluate().toList()
          ..sort((a, b) => tester.getTopLeft(find.byElementPredicate((e) => e == a)).dx
              .compareTo(tester.getTopLeft(find.byElementPredicate((e) => e == b)).dx));
        return [for (final e in items) (e.widget as Text).data!];
      }

      final first = shown();
      expect(first, order.take(first.length));
      expect(first, isNot(contains('Payments')), reason: 'the last shortcuts are off screen: the row scrolls');
      await tester.tap(find.descendant(of: row, matching: find.text('Clients')));
      await tester.drag(row, const Offset(-600, 0));
      await tester.pumpAndSettle();
      final last = shown();
      expect(last, order.skip(order.length - last.length));
      await tester.tap(find.descendant(of: row, matching: find.text('Payments')));
      expect(went, [GoToItem.clients, GoToItem.payments]);
      expect(find.byType(ShaderMask), findsOneWidget, reason: 'the fade at the edge');
    }, skip: _skip);
  });

  group('Needs attention', () {
    test('counts from memory: low or out of stock, expired or expiring, debts older than the setting', () {
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
      expect(attentionCountsFor(products: [ph4Product('fine')], debts: [ph4Debt('c', 9, 1)], overdueDays: 30).isEmpty, isTrue);
    }, skip: _skip);

    testWidgets('absent when nothing needs attention', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(attention: const AttentionCounts()));
      expect(find.text('Needs attention'), findsNothing);
      expect(find.byType(NeedsAttentionStrip), findsNothing);
    }, skip: _skip);

    testWidgets('one strip with the counts; each row opens its screen', (tester) async {
      final opened = <AttentionTarget>[];
      await pumpPhoneHome(tester, phoneHomeHarness(onAttention: opened.add));
      await tester.scrollUntilVisible(find.text('Owed for more than 30 days'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      for (final (text, count) in [
        ('Low or out of stock', '3'),
        ('Expired or expiring soon', '2'),
        ('Owed for more than 30 days', '4'),
      ]) {
        final row = find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;
        expect(find.descendant(of: row, matching: find.text(count)), findsOneWidget, reason: text);
        expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
        await tester.tap(find.text(text));
      }
      expect(opened, [AttentionTarget.stockAlerts, AttentionTarget.stockAlerts, AttentionTarget.debtors]);
    }, skip: _skip);

    testWidgets('only the rows with something to report', (tester) async {
      await pumpPhoneHome(tester, phoneHomeHarness(attention: const AttentionCounts(overdueDebtors: 1, overdueDays: 14)));
      await tester.scrollUntilVisible(find.text('Owed for more than 14 days'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Low or out of stock'), findsNothing);
      expect(find.text('Expired or expiring soon'), findsNothing);
    }, skip: _skip);
  });

}
