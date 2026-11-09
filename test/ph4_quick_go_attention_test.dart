// PH4 (5), as UI5 reshaped it: the one Needs attention strip. HUB1: the
// record tiles, what View all offered and the places (the grid, the "+"
// sheet's More group, the bottom bar and More) are the action panel's now:
// hub1_destinations_test and hub1_panel_test check them, with the same
// guard and forms.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';

import 'helpers/phone_home_harness.dart';

const _skip = false;

void main() {
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
