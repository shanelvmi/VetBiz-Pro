// PH5b: tablets and computers keep today's Clients, Debtors, Payments (also
// for one client) and Transactions exactly. At 768x1024, 1024x768 and
// 1200x800 the whole widget tree under the screen is compared with the
// fingerprint recorded from the code before PH5b
// (test/fixtures/ph5a_wide_fingerprints.json, the ph5b- names), once with the
// list and once with a row's details panel open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

// Every date the cards count stays inside today's month and week, so the
// figures (and so the widths) do not move with the calendar.
final _clients = [
  Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer', 'Vet'], balance: 45000, oldestDebt: ph5When(45)),
  Ph5Client('c2', matrixLongClientName, ph5When(0, minutes: 30), types: ['Retailer'], balance: matrixBigAmount, oldestDebt: ph5When(3)),
  Ph5Client('c3', 'Baraka Mushi', ph5When(0, minutes: 60), status: 'Inactive', balance: 12500, oldestDebt: ph5When(10)),
];

final _debts = [
  Ph5Debt('d1', 'c3', ph5When(10), 12500),
  Ph5Debt('d2', 'c1', ph5When(45), 45000),
];

final _payments = [
  Ph5Payment('p1', ph5When(0, minutes: 5), client: 'Amina Juma', clientId: 'c1', amount: 20000, method: 'mpesa'),
  Ph5Payment('p2', ph5When(0, minutes: 40), client: matrixLongClientName, clientId: 'c2', amount: matrixBigAmount),
  Ph5Payment('p3', ph5When(0, minutes: 90), client: 'Baraka Mushi', clientId: 'c3', amount: 7000, source: 'debt_repayment'),
];

final _txs = [
  Ph5Tx('t1', ph5When(0, minutes: 5), description: 'Fuel for the car', amount: 30000, receipt: 1),
  Ph5Tx('t2', ph5When(0, minutes: 50), type: 'other income', category: 'Consultation', description: matrixLongClientName, amount: matrixBigAmount, receipt: 2),
  Ph5Tx('t3', ph5When(3), category: 'Rent', description: 'Rent for November', amount: 150000, method: 'mpesa', receipt: 3),
];

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, _clients);
  await ph5SeedDebts(fs, _debts);
  await ph5SeedPayments(fs, _payments);
  await ph5SeedTransactions(fs, _txs);
}

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void main() {
  final screens = <String, (Widget Function(dynamic fs), Type, String)>{
    'clients': ((fs) => ClientsScreen(firestore: fs), ClientsScreen, 'Amina Juma'),
    'debtors': ((fs) => DebtorsScreen(firestore: fs), DebtorsScreen, 'Baraka Mushi'),
    'payments': ((fs) => PaymentsScreen(firestore: fs), PaymentsScreen, 'Baraka Mushi'),
    'payments-client': (
      (fs) => PaymentsScreen(firestore: fs, initialClientId: 'c1', initialClientName: 'Amina Juma'),
      PaymentsScreen,
      'Amina Juma'
    ),
    'transactions': ((fs) => TransactionScreen(firestore: fs), TransactionScreen, 'Rent for November'),
  };
  for (final e in screens.entries) {
    final (build, type, rowText) = e.value;
    for (final size in ph5WideSizes) {
      final where = 'ph5b-${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: the list and the details panel as before PH5b', (tester) async {
        await pumpPh5(tester, (fs) => build(fs), size: size, pushed: true, seed: _seed);
        expectSameFingerprint('$where-list', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
        await tester.tap(find.text(rowText).last);
        await ph5Settle(tester);
        expectSameFingerprint('$where-details', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      }, skip: _skip);
    }
  }
}
