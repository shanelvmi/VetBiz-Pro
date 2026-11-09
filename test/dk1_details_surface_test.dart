// DK1: the money screens' details in Dark and Light hold no bright filled box
// with text or icons on it (no dark one in Light): the side panel on wide
// windows, and on a phone the details page and its delete confirmation. The
// phone lists, details pages and sheets are scanned by every phone matrix
// (checkCase); this adds the wide panels and the confirmations.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/dark_surface_scan.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

Future<void> _seed(dynamic fs) async {
  await seedProduct(fs, id: 'p1', legacyQty: 10);
  await ph5SeedSales(fs, [Ph5Sale('s1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 45000, paid: 20000, receipt: 1)]);
  await ph5SeedServices(
      fs, [Ph5Service('v1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 30000, paid: 10000, category: 'Surgical', receipt: 1)]);
  await ph5SeedClients(fs, [
    Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer'], balance: 45000, oldestDebt: ph5When(45)),
    Ph5Client('c3', 'Baraka Mushi', ph5When(0, minutes: 60), balance: 12500, oldestDebt: ph5When(10)),
  ]);
  await ph5SeedDebts(fs, [Ph5Debt('d1', 'c3', ph5When(10), 12500), Ph5Debt('d2', 'c1', ph5When(45), 45000)]);
  await ph5SeedPayments(fs, [Ph5Payment('p3', ph5When(0, minutes: 90), client: 'Baraka Mushi', clientId: 'c3', amount: 7000)]);
  await ph5SeedTransactions(fs, [Ph5Tx('t3', ph5When(3), category: 'Rent', description: 'Rent for November', amount: 150000, receipt: 3)]);
}

void main() {
  // name: (screen, the wide row to tap, the phone row id, a Delete on the
  // phone details page).
  final screens = <String, (Widget Function(dynamic fs), String, String, bool)>{
    'Sales': ((fs) => SalesScreen(firestore: fs), 'SL-000001', 's1', true),
    'Services': ((fs) => ServicesScreen(firestore: fs), 'Surgical visit', 'v1', true),
    'Debtors': ((fs) => DebtorsScreen(firestore: fs), 'Baraka Mushi', 'c3', false),
    'Payments': ((fs) => PaymentsScreen(firestore: fs), 'Baraka Mushi', 'p3', false),
    'Transactions': ((fs) => TransactionScreen(firestore: fs), 'Rent for November', 't3', false),
  };

  for (final look in [MatrixLook.dark, MatrixLook.light]) {
    final dark = look == MatrixLook.dark;
    for (final e in screens.entries) {
      final (build, wideRow, id, delete) = e.value;

      for (final size in const [Size(1200, 800), Size(768, 1024)]) {
        ph5TestWidgets('${look.name} ${e.key} ${size.width.toInt()}: the details panel', (tester) async {
          await pumpPh5(tester, (fs) => build(fs), size: size, look: look, pushed: true, seed: _seed);
          await tester.tap(find.text(wideRow).last);
          await ph5Settle(tester);
          // Some wide panels overflow with long names (their fingerprints hold
          // it); only the colours matter here.
          while (tester.takeException() != null) {}
          expectNoBadSurfaces(tester, dark: dark, where: '${e.key} details panel');
        }, skip: _skip);
      }

      if (delete) {
        ph5TestWidgets('${look.name} ${e.key} phone: the delete confirmation', (tester) async {
          await pumpPh5(tester, (fs) => build(fs), look: look, pushed: true, seed: _seed);
          await tester.tap(ph5Key('phoneList-row-$id'));
          await ph5Settle(tester);
          await tester.tap(find.descendant(of: ph5Key('phoneList-details'), matching: find.text('Delete')));
          await ph5Settle(tester);
          expect(find.byType(AlertDialog), findsOneWidget);
          expectNoBadSurfaces(tester, dark: dark, where: '${e.key} delete confirmation');
        }, skip: _skip);
      }
    }

    ph5TestWidgets('${look.name} Products phone: the details page and the delete confirmation', (tester) async {
      await pumpPh5(tester, (fs) => ProductsScreen(firestore: fs), look: look, seed: ph7SeedProducts);
      await tester.tap(ph5Key('phoneList-row-p1'));
      await ph5Settle(tester);
      expectNoBadSurfaces(tester, dark: dark, where: 'Product details page');
      await tester.tap(find.descendant(of: ph5Key('phoneList-details'), matching: find.byTooltip('Delete')));
      await ph5Settle(tester);
      expect(find.text('Confirm Delete'), findsOneWidget);
      expectNoBadSurfaces(tester, dark: dark, where: 'Product delete confirmation');
    }, skip: _skip);
  }
}
