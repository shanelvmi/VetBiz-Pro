// PH5b (docs/design/phone_list_pattern.md): Active Debts on a phone. Pushed
// (back arrow), Export in the one overflow menu, Record Payment floating (it
// asks for the debtor first, from the shared debtors fetch), status chips
// (All, Overdue, Current) and the Filter sheet against the toolbar, "N
// debtors, Tsh X owed" and a Summary sheet with the four cards, a plain list
// in today's order (largest balance first), rows, the details page with
// the debts, notes and actions of today's panel, and the states.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _wide = Size(1200, 800);

// Overdue after 30 days (the facility's default); the ranges count the days
// since the oldest debt: Amina 45 (31-60), Neema 70 (61 and more), Baraka 10.
final _clients = [
  Ph5Client('c1', 'Amina Juma', ph5When(90), phone: '0712111111', balance: 45000, oldestDebt: ph5When(45)),
  Ph5Client('c2', 'Baraka Mushi', ph5When(90), balance: 12500, oldestDebt: ph5When(10)),
  Ph5Client('c3', 'Neema Ally', ph5When(90), balance: 80000, oldestDebt: ph5When(70)),
  Ph5Client('c4', 'Juma Paid', ph5When(90)),
];

final _debts = [
  Ph5Debt('d1', 'c1', ph5When(45), 45000),
  Ph5Debt('d2', 'c2', ph5When(10), 12500),
  Ph5Debt('d3', 'c3', ph5When(70), 80000),
];

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, _clients);
  await ph5SeedDebts(fs, _debts);
}

Future<Ph5App> _debtors(WidgetTester tester, {Size size = const Size(390, 844), bool empty = false, CountingFirestore? firestore}) =>
    pumpPh5(tester, (fs) => DebtorsScreen(firestore: fs),
        size: size, pushed: true, firestore: firestore, seed: empty ? null : _seed);

Finder _chip(String label) => find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text(label));

/// The debtors the wide table lists, in its order.
List<String> _tableNames(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(ListView), matching: find.byType(Text)).evaluate())
        if (_clients.any((c) => c.name == (e.widget as Text).data)) (e.widget as Text).data!,
    ];

List<String> _rowOrder(WidgetTester tester) {
  final ids = ph5RowIds(tester).toList()..sort((a, b) => tester.getTopLeft(ph5Key('phoneList-row-$a')).dy.compareTo(tester.getTopLeft(ph5Key('phoneList-row-$b')).dy));
  return [for (final id in ids) _clients.firstWhere((c) => c.id == id).name];
}

void main() {
  ph5TestWidgets('the app bar: back arrow, the title, search, Export in the one overflow menu', (tester) async {
    await _debtors(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Active Debts'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    expect(find.text('Export'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Record Payment floats, hides with the keyboard, and asks for the debtor first', (tester) async {
    await _debtors(tester);
    expect(ph5FabExtended('Record Payment'), isTrue);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddPaymentScreen), findsOneWidget);
    final form = tester.widget<AddPaymentScreen>(find.byType(AddPaymentScreen));
    expect(form.preselectedClient, isNull);
    expect(form.debtorClients?.map((c) => c.id).toSet(), {'c1', 'c2', 'c3'});
    while (tester.takeException() != null) {}

    await _debtors(tester);
    await ph5OpenKeyboard(tester);
    expect(ph5Key('phoneList-fab'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the chips and the Filter sheet give the toolbar\'s results', (tester) async {
    await _debtors(tester, size: _wide);
    expect(_tableNames(tester), ['Neema Ally', 'Amina Juma', 'Baraka Mushi']);
    await tester.tap(find.text('Status: All'));
    await ph5Settle(tester);
    await tester.tap(find.text('Status: Overdue').last);
    await ph5Settle(tester);
    final overdue = _tableNames(tester).toSet();
    await tester.tap(find.text('Status: Overdue'));
    await ph5Settle(tester);
    await tester.tap(find.text('Status: All').last);
    await ph5Settle(tester);
    await tester.tap(find.text('Overdue: All'));
    await ph5Settle(tester);
    await tester.tap(find.text('Overdue: 31-60 days overdue').last);
    await ph5Settle(tester);
    final range = _tableNames(tester).toSet();
    expect(overdue, {'Neema Ally', 'Amina Juma'});
    expect(range, {'Amina Juma'});

    await _debtors(tester);
    expect(_rowOrder(tester), ['Neema Ally', 'Amina Juma', 'Baraka Mushi']);
    for (final c in ['All', 'Overdue', 'Current']) {
      expect(_chip(c), findsOneWidget, reason: c);
    }
    await tester.tap(_chip('Overdue'));
    await ph5Settle(tester);
    expect(_rowOrder(tester).toSet(), overdue);
    await tester.tap(_chip('All'));
    await ph5Settle(tester);
    await ph5OpenSheet(tester, 'Filter');
    expect(ph5InSheet('Status'), findsOneWidget);
    expect(ph5InSheet('Overdue'), findsWidgets);
    await tester.tap(ph5InSheet('31-60 days overdue'));
    await tester.pump();
    await tester.tap(ph5InSheet('Apply'));
    await ph5Settle(tester);
    expect(_rowOrder(tester).toSet(), range);
    expect(find.descendant(of: ph5Key('phoneList-appliedChips'), matching: find.text('Overdue: 31-60 days overdue')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('"3 debtors, Tsh 137,500 owed" and a Summary sheet with the four cards, as the tablet shows them', (tester) async {
    final cards = {
      'Total Debtors': '3',
      'Total Owed': Money.format(137500),
      'Overdue Debtors': '2',
      'Paid This Month': Money.format(0),
    };
    await _debtors(tester, size: _wide);
    for (final e in cards.entries) {
      final card = find.ancestor(of: find.text(e.key), matching: find.byType(Column)).first;
      expect(find.descendant(of: card, matching: find.text(e.value)), findsOneWidget, reason: e.key);
    }

    await _debtors(tester);
    expect(find.text('3 debtors, ${Money.format(137500)} owed'), findsOneWidget);
    await ph5OpenSummary(tester);
    for (final e in cards.entries) {
      expect(ph5SheetValue(tester, e.key), e.value, reason: e.key);
    }
    for (final sub in ['With outstanding balance', 'Outstanding balance', 'Over 30 days', 'From debt payments']) {
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining(sub)), findsOneWidget, reason: sub);
    }
  }, skip: _skip);

  ph5TestWidgets('rows: initials, the debtor and the amount owed, the oldest debt date and days, the status as text', (tester) async {
    await _debtors(tester);
    final row = ph5Key('phoneList-row-c1');
    for (final t in ['AJ', 'Amina Juma', Money.format(45000), DateFormat('dd MMM yyyy').format(_clients.first.oldestDebt!), '45 days', 'Overdue']) {
      expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: ph5Key('phoneList-row-c2'), matching: find.text('Current')), findsOneWidget);
    expect(ph5HasDayHeaders(tester), isFalse);
  }, skip: _skip);

  ph5TestWidgets('the details page: the panel\'s debts, notes and actions', (tester) async {
    await _debtors(tester, size: _wide);
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text('Amina Juma')));
    await ph5Settle(tester);
    while (tester.takeException() != null) {}
    final panel = ph5Texts(find.ancestor(of: find.text('Debtor Details'), matching: find.byType(SingleChildScrollView)).first);

    await _debtors(tester);
    await tester.tap(ph5Key('phoneList-row-c1'));
    await ph5Settle(tester);
    expect(ph5Texts(ph5Page), panel);
    for (final action in ['Send Reminder', 'Payment History', 'Add Note', 'Record Payment', 'Pay']) {
      expect(find.descendant(of: ph5Page, matching: find.text(action)), findsOneWidget, reason: action);
    }
    await tester.tap(find.descendant(of: ph5Page, matching: find.text('Pay')));
    await ph5Settle(tester);
    final form = tester.widget<AddPaymentScreen>(find.byType(AddPaymentScreen));
    expect((form.preselectedClient?.id, form.debtDocId), ('c1', 'd1'));
    while (tester.takeException() != null) {}
  }, skip: _skip);

  ph5TestWidgets('pull to refresh starts the list over and reloads the cards', (tester) async {
    final app = await _debtors(tester);
    await tester.runAsync(() => ph5SeedClients(app.fs, [Ph5Client('c5', 'Zawadi Said', ph5When(90), balance: 99000, oldestDebt: ph5When(2))]));
    expect(ph5RowIds(tester), isNot(contains('c5')));
    await ph5Pull(tester);
    expect(ph5RowIds(tester), contains('c5'));
    expect(find.text('4 debtors, ${Money.format(236500)} owed'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('states: empty with Record Payment (as the wide button); error with Retry', (tester) async {
    await _debtors(tester, empty: true);
    final empty = ph5Key('phoneList-empty');
    expect(find.descendant(of: empty, matching: find.text('No outstanding debts')), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Record Payment')), findsOneWidget);

    final failing = CountingFirestore()..failGets = true;
    await tester.runAsync(() => _seed(failing.inner));
    await _debtors(tester, firestore: failing);
    expect(ph5Key('phoneList-error'), findsOneWidget);
    failing.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'c1', 'c2', 'c3'});
  }, skip: _skip);
}
