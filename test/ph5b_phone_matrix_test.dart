// PH5b: Clients, Debtors, Payments and Transactions on phones at 360x740,
// 390x844 and 740x360, in Light, Dark and Kiswahili, with a very long
// Kiswahili name and an 8-digit amount: no overflow, 48 px targets, no text
// under 12 px, on the list and on the details page (R11). Each row reads
// naturally (R11). The cost (R12): a cold open on a phone opens the
// computer's listeners and reads, and coming back from a details page reads
// nothing (the counts are printed for the ledger).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// The screens done so far: the others stay skipped until theirs is.
const _done = {'Clients', 'Debtors'};

final _client = Ph5Client('c1', matrixLongClientName, ph5When(0, minutes: 5),
    types: ['Farmer', 'Vet', 'Wholesaler'], balance: matrixBigAmount, oldestDebt: ph5When(45));
final _amina = Ph5Client('c2', 'Amina Juma', ph5When(0, minutes: 9), phone: '0712111111', balance: 45000, oldestDebt: ph5When(45));
final _payment = Ph5Payment('p1', ph5When(0, minutes: 5), client: matrixLongClientName, clientId: 'c1', amount: matrixBigAmount);
final _aminaPaid = Ph5Payment('p2', ph5When(0, minutes: 9), client: 'Amina Juma', clientId: 'c2', amount: 20000);
final _tx = Ph5Tx('t1', ph5When(0, minutes: 5), type: 'other income', category: 'Veterinary Supplies', description: matrixLongClientName, amount: matrixBigAmount);
final _fuel = Ph5Tx('t2', ph5When(0, minutes: 9), description: 'Fuel for the car', amount: 30000, receipt: 2);

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, [_client, _amina]);
  await ph5SeedDebts(fs, [Ph5Debt('d1', 'c1', ph5When(45), matrixBigAmount), Ph5Debt('d2', 'c2', ph5When(45), 45000)]);
  await ph5SeedPayments(fs, [_payment, _aminaPaid]);
  await ph5SeedTransactions(fs, [_tx, _fuel]);
}

void main() {
  final screens = <String, (Widget Function(dynamic fs), String)>{
    'Clients': ((fs) => ClientsScreen(firestore: fs), 'c1'),
    'Debtors': ((fs) => DebtorsScreen(firestore: fs), 'c1'),
    'Payments': ((fs) => PaymentsScreen(firestore: fs), 'p1'),
    'Transactions': ((fs) => TransactionScreen(firestore: fs), 't1'),
  };

  for (final e in screens.entries) {
    final (build, id) = e.value;
    group('${e.key} phone matrix', () {
      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '${e.key} ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh5(tester, (fs) => build(fs), size: size.size, look: look, pushed: true, seed: _seed);
            await checkCase(tester, phone: true, where: '$where list');
            await tester.tap(ph5Key('phoneList-row-$id'));
            await ph5Settle(tester);
            await checkCase(tester, phone: true, where: '$where details');
          }, skip: !_done.contains(e.key));
        }
      }
    });
  }

  group('each row reads naturally (R11)', () {
    final date = DateFormat('dd MMM yyyy');
    final when = DateFormat('d MMM HH:mm');
    final labels = <String, (Widget Function(dynamic fs), String)>{
      'Clients': ((fs) => ClientsScreen(firestore: fs), 'Amina Juma, 0712111111, Farmer, ${date.format(_amina.created)}'),
      'Debtors': ((fs) => DebtorsScreen(firestore: fs), 'Amina Juma, ${Money.format(45000)}, Overdue, ${date.format(_amina.oldestDebt!)}'),
      'Payments': ((fs) => PaymentsScreen(firestore: fs), 'Amina Juma, ${Money.format(20000)}, Sale payment, ${when.format(_aminaPaid.when)}'),
      'Transactions': ((fs) => TransactionScreen(firestore: fs), 'Fuel for the car, -${Money.format(30000)}, Expense, ${when.format(_fuel.when)}'),
    };
    for (final e in labels.entries) {
      ph5TestWidgets(e.key, (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPh5(tester, (fs) => e.value.$1(fs), pushed: true, seed: _seed);
        expect(find.bySemanticsLabel(e.value.$2), findsOneWidget);
        semantics.dispose();
      }, skip: !_done.contains(e.key));
    }
  });

  group('cost (R12), counted on the fake Firestore', () {
    for (final e in screens.entries) {
      final (build, id) = e.value;
      ph5TestWidgets('${e.key}: a phone opens with the computer\'s listeners and reads; back from details reads nothing',
          (tester) async {
        final counts = <String, (int, int, int)>{};
        for (final size in const [Size(1200, 800), Size(390, 844)]) {
          final db = CountingFirestore();
          await tester.runAsync(() => _seed(db.inner));
          await pumpPh5(tester, (fs) => build(fs), size: size, pushed: true, firestore: db);
          counts['${size.width.toInt()}'] = (db.listeners, db.gets, db.reads);
          if (size.width < 600) {
            db.resetCounts();
            await tester.tap(ph5Key('phoneList-row-$id'));
            await ph5Settle(tester);
            final details = (db.gets, db.reads);
            db.resetCounts();
            await tester.tap(find.byType(BackButton).first);
            await ph5Settle(tester);
            expect((db.gets, db.reads, db.listens), (0, 0, 0), reason: 'back from the details page');
            // ignore: avoid_print
            print('PH5b ${e.key} details page opens (gets, reads): $details');
          }
          await tester.pumpWidget(const SizedBox());
        }
        // ignore: avoid_print
        print('PH5b ${e.key} cold open (listeners, gets, reads): computer ${counts['1200']}, phone ${counts['390']}');
        expect(counts['390'], counts['1200']);
      }, skip: !_done.contains(e.key));
    }
  });
}
