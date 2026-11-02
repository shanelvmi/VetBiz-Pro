// PH5b (docs/design/phone_list_pattern.md): Transactions on a phone. Pushed
// (back arrow), Date Range in the one overflow menu (the cards' period),
// Record Transaction floating, the chips for the types the toolbar has (All,
// Other Income, Expense; the toolbar's only filter, so no Filter sheet), the
// summary line and a Summary sheet with the four figures, rows grouped by
// day with the day's net total, signed amounts (the sign as a character),
// the details page (an assistant has no Edit and no Delete, E4d-2), paging
// and the states.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/widgets/date_range_dialog.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = true;

const _wide = Size(1200, 800);

final _txs = [
  Ph5Tx('t1', ph5When(0, minutes: 5), description: 'Fuel for the car', amount: 30000, receipt: 1),
  Ph5Tx('t2', ph5When(0, minutes: 50), type: 'other income', category: 'Consultation', description: 'Farm visit talk', amount: 50000, method: 'mpesa', receipt: 2),
  Ph5Tx('t3', ph5When(1), category: 'Rent', description: 'Rent for November', amount: 150000, receipt: 3),
  Ph5Tx('t4', ph5When(4), type: 'other income', category: 'Consultation', description: 'Dog boarding', amount: 20000, receipt: 4),
];

final _many = [for (var i = 0; i < 30; i++) Ph5Tx('m$i', ph5When(i ~/ 6, minutes: i), description: 'Item $i', amount: 1000, receipt: 10 + i)];

Future<Ph5App> _open(WidgetTester tester,
        {Size size = const Size(390, 844), bool admin = true, List<Ph5Tx>? txs, CountingFirestore? firestore, bool settle = true}) =>
    pumpPh5(tester, (fs) => TransactionScreen(firestore: fs),
        size: size,
        pushed: true,
        admin: admin,
        firestore: firestore,
        settle: settle,
        seed: firestore != null ? null : (fs) => ph5SeedTransactions(fs, txs ?? _txs));

Finder _chip(String label) => find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text(label));

void main() {
  ph5TestWidgets('the app bar: back arrow, title, search, Date Range in the menu; no Filter button', (tester) async {
    await _open(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsNothing);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    await tester.tap(find.text('Date Range'));
    await ph5Settle(tester);
    expect(find.byType(DateRangeDialog), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Record Transaction floats, hides with the keyboard, opens the form', (tester) async {
    await _open(tester);
    expect(ph5FabExtended('Record Transaction'), isTrue);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    while (tester.takeException() != null) {}

    await _open(tester);
    await ph5OpenKeyboard(tester);
    expect(ph5Key('phoneList-fab'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the chips give the toolbar\'s type filter results', (tester) async {
    await _open(tester, size: _wide);
    await tester.tap(find.text('Type: All').first);
    await ph5Settle(tester);
    await tester.tap(find.text('Type: Expense').last);
    await ph5Settle(tester);
    final toolbar = {for (final t in _txs) if (find.text(t.description).evaluate().isNotEmpty) t.id};
    expect(toolbar, {'t1', 't3'});

    await _open(tester);
    for (final c in ['All', 'Other Income', 'Expense']) {
      expect(_chip(c), findsOneWidget, reason: c);
    }
    await tester.tap(_chip('Expense'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), toolbar);
  }, skip: _skip);

  ph5TestWidgets('the summary line and a Summary sheet with the four figures, as on the tablet', (tester) async {
    await _open(tester, size: _wide);
    for (final v in [Money.format(70000), Money.format(180000), Money.format(-110000), '4 transactions']) {
      expect(find.text(v), findsOneWidget, reason: v);
    }

    await _open(tester);
    expect(find.textContaining(': income ${Money.format(70000)}, expenses ${Money.format(180000)}'), findsOneWidget);
    await ph5OpenSummary(tester);
    expect(ph5SheetValue(tester, 'Other Income'), Money.format(70000));
    expect(ph5SheetValue(tester, 'Expenses'), Money.format(180000));
    expect(ph5SheetValue(tester, 'Other Income vs Expenses'), Money.format(-110000));
    expect(ph5SheetValue(tester, 'Transactions'), '4');
  }, skip: _skip);

  ph5TestWidgets('grouped by day with the day\'s net; rows: icon, description and signed amount, category and time, type', (tester) async {
    await _open(tester);
    expect(find.descendant(of: ph5Key('phoneList-day-${ph5DayKey(ph5When(0))}'), matching: find.text(Money.format(20000))), findsOneWidget);
    expect(find.descendant(of: ph5Key('phoneList-day-${ph5DayKey(ph5When(1))}'), matching: find.text(Money.format(-150000))), findsOneWidget);
    final t1 = ph5Key('phoneList-row-t1');
    for (final t in ['Fuel for the car', '-${Money.format(30000)}', 'Fuel', DateFormat('HH:mm').format(_txs.first.when), 'Expense']) {
      expect(find.descendant(of: t1, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: t1, matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
    expect(find.descendant(of: ph5Key('phoneList-row-t2'), matching: find.text('+${Money.format(50000)}')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the details page: the panel\'s content (method, recorded by), Print, Edit and Delete for an admin; Undo offered', (tester) async {
    await _open(tester, size: _wide);
    await tester.tap(find.text('Rent for November'));
    await ph5Settle(tester);
    final panel = ph5Texts(find.ancestor(of: find.text('Transaction Details'), matching: find.byType(SingleChildScrollView)).first);
    expect(panel, containsAll(['Cash', 'Asha Seller']));

    await _open(tester);
    await tester.tap(ph5Key('phoneList-row-t3'));
    await ph5Settle(tester);
    expect(ph5Texts(ph5Page), panel);
    expect(find.descendant(of: ph5Page, matching: find.text('Print')), findsOneWidget);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsOneWidget);
    await tester.tap(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')));
    await ph5Settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await ph5Settle(tester);
    expect(ph5Page, findsNothing);
    expect(ph5Key('phoneList-row-t3'), findsNothing);
    // Undo is offered (today's restore, TrashService on the app's own
    // Firestore, cannot run on the fake: the owner checks it on the phone).
    expect(find.text('Undo'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('an assistant: no Edit and no Delete on the page (E4d-2)', (tester) async {
    await _open(tester, admin: false);
    await tester.tap(ph5Key('phoneList-row-t1'));
    await ph5Settle(tester);
    expect(find.descendant(of: ph5Page, matching: find.text('Print')), findsOneWidget);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsNothing);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('pull to refresh reloads the cards\' totals', (tester) async {
    final app = await _open(tester);
    await tester.runAsync(() => ph5SeedTransactions(app.fs, [..._txs, Ph5Tx('t5', ph5When(0, minutes: 1), amount: 5000, receipt: 5)]));
    await ph5Pull(tester);
    expect(ph5RowIds(tester), contains('t5'));
    expect(find.textContaining('expenses ${Money.format(185000)}'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('paging: older transactions load near the end', (tester) async {
    await _open(tester, txs: _many);
    for (var i = 0; i < 3; i++) {
      await tester.drag(ph5List, const Offset(0, -3000));
      await ph5Settle(tester);
    }
    // The last of 30 (page size 25) is at the end once the older page came.
    expect(ph5Key('phoneList-row-m29'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('states: six skeleton rows until the first answer; empty with Record Transaction', (tester) async {
    final held = CountingFirestore()..holdListens = Completer<void>();
    await tester.runAsync(() => ph5SeedTransactions(held.inner, _txs));
    await _open(tester, firestore: held, settle: false);
    expect(find.descendant(of: ph5Key('phoneList-skeleton'), matching: ph5SkeletonRows), findsNWidgets(6));
    held.holdListens!.complete();
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(4));

    await _open(tester, txs: const []);
    final empty = ph5Key('phoneList-empty');
    expect(find.descendant(of: empty, matching: find.text('No transactions.')), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Record Transaction')), findsOneWidget);
  }, skip: _skip);
}
