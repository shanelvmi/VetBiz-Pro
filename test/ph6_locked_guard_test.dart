// PH6 finding (a): Add Client, Record Payment and Record Transaction had no
// locked-facility guard at any width (only the phone's "+" sheet guarded
// them). Every entry point now goes through navigateOrShowLockedDialog: a
// locked facility gets the friendly locked message and no form opens, on a
// phone and on a computer. Editing an existing client or transaction is
// not a new record and stays as it was.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _phone = Size(390, 844);
const _wide = Size(1200, 800);

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, [Ph5Client('c1', 'Amina Juma', ph5When(90), balance: 45000, oldestDebt: ph5When(45))]);
  await ph5SeedDebts(fs, [Ph5Debt('d1', 'c1', ph5When(45), 45000)]);
  await ph5SeedTransactions(fs, [Ph5Tx('t1', ph5When(0))]);
}

/// The locked message is up and no form opened.
void _expectLocked(WidgetTester tester) {
  expect(find.text('Subscription Expired'), findsOneWidget);
  expect(find.byType(AddClientScreen), findsNothing);
  expect(find.byType(AddPaymentScreen), findsNothing);
  expect(find.byType(AddTransactionScreen), findsNothing);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await ph5Settle(tester);
}

void main() {
  final cases = <String, (Widget Function(dynamic fs), Size, Future<void> Function(WidgetTester))>{
    'Clients, the phone\'s floating Add Client': (
      (fs) => ClientsScreen(firestore: fs),
      _phone,
      (t) => _tapAndSettle(t, ph5Key('phoneList-fab'))
    ),
    'Clients, the computer\'s Add Client': ((fs) => ClientsScreen(firestore: fs), _wide, (t) => _tapAndSettle(t, find.text('Add Client'))),
    'Active Debts, the phone\'s floating Record Payment': (
      (fs) => DebtorsScreen(firestore: fs),
      _phone,
      (t) => _tapAndSettle(t, ph5Key('phoneList-fab'))
    ),
    'Active Debts, the computer\'s Record Payment': (
      (fs) => DebtorsScreen(firestore: fs),
      _wide,
      (t) => _tapAndSettle(t, find.text('Record Payment'))
    ),
    'Active Debts, the details page\'s Record Payment': (
      (fs) => DebtorsScreen(firestore: fs),
      _phone,
      (t) async {
        await _tapAndSettle(t, ph5Key('phoneList-row-c1'));
        await _tapAndSettle(t, find.descendant(of: ph5Page, matching: find.text('Record Payment')));
      }
    ),
    'Active Debts, a debt\'s Pay': (
      (fs) => DebtorsScreen(firestore: fs),
      _phone,
      (t) async {
        await _tapAndSettle(t, ph5Key('phoneList-row-c1'));
        await _tapAndSettle(t, find.descendant(of: ph5Page, matching: find.text('Pay')));
      }
    ),
    'Transactions, the phone\'s floating Record Transaction': (
      (fs) => TransactionScreen(firestore: fs),
      _phone,
      (t) => _tapAndSettle(t, ph5Key('phoneList-fab'))
    ),
    'Transactions, the computer\'s Record Transaction': (
      (fs) => TransactionScreen(firestore: fs),
      _wide,
      (t) => _tapAndSettle(t, find.text('Record Transaction').last)
    ),
  };

  for (final e in cases.entries) {
    final (build, size, open) = e.value;
    ph5TestWidgets('locked: ${e.key} shows the locked message, no form', (tester) async {
      await pumpPh5(tester, (fs) => build(fs), size: size, pushed: true, locked: true, seed: _seed);
      // Today's wide layouts may overflow with the test font (fingerprinted).
      while (tester.takeException() != null) {}
      await open(tester);
      while (tester.takeException() != null) {}
      _expectLocked(tester);
    }, skip: _skip);
  }

  ph5TestWidgets('not locked: the phone\'s floating Add Client opens the form', (tester) async {
    await pumpPh5(tester, (fs) => ClientsScreen(firestore: fs), pushed: true, seed: _seed);
    await _tapAndSettle(tester, ph5Key('phoneList-fab'));
    while (tester.takeException() != null) {}
    expect(find.byType(AddClientScreen), findsOneWidget);
    expect(find.text('Subscription Expired'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('locked: editing a client is not a new record and still opens', (tester) async {
    await pumpPh5(tester, (fs) => ClientsScreen(firestore: fs), pushed: true, locked: true, seed: _seed);
    await _tapAndSettle(tester, ph5Key('phoneList-row-c1'));
    await _tapAndSettle(tester, find.byTooltip('Edit'));
    while (tester.takeException() != null) {}
    expect(find.byType(AddClientScreen), findsOneWidget);
  }, skip: _skip);
}
