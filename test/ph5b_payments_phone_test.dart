// PH5b (docs/design/phone_list_pattern.md): Payments on a phone. Pushed
// (back arrow), Date Range in the one overflow menu, no floating button
// (payments are recorded from Active Debts), the chips Today, Yesterday and
// All in place of the app bar's dates, the Filter sheet (type, method)
// against the toolbar, the summary line and a Summary sheet with the four
// cards and the total, rows grouped by day with day totals, the details
// page, the one-client mode (payments_titleForClient) and the states.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/widgets/date_range_dialog.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _wide = Size(1200, 800);

final _payments = [
  Ph5Payment('p1', ph5When(0, minutes: 5), client: 'Amina Juma', clientId: 'c1', amount: 20000, method: 'M-Pesa'),
  Ph5Payment('p2', ph5When(0, minutes: 40), client: 'Baraka Mushi', clientId: 'c2', amount: 7000, method: 'Cash', source: 'debt_repayment', phone: '0712222222'),
  Ph5Payment('p3', ph5When(1), client: 'Neema Ally', clientId: 'c3', amount: 15000, method: 'Cash', source: 'service'),
  Ph5Payment('p4', ph5When(3), client: 'Amina Juma', clientId: 'c1', amount: 4000, method: 'Cash'),
];

Future<Ph5App> _open(WidgetTester tester,
        {Size size = const Size(390, 844), bool forClient = false, List<Ph5Payment>? payments, CountingFirestore? firestore, bool settle = true}) =>
    pumpPh5(
      tester,
      (fs) => forClient
          ? PaymentsScreen(firestore: fs, initialClientId: 'c1', initialClientName: 'Amina Juma')
          : PaymentsScreen(firestore: fs),
      size: size,
      pushed: true,
      firestore: firestore,
      settle: settle,
      seed: firestore != null ? null : (fs) => ph5SeedPayments(fs, payments ?? _payments),
    );

Finder _chip(String label) => find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text(label));

/// Today's wide layout overflows with the test font (each glyph a full em; the
/// fingerprints record it, unchanged): only its texts and figures matter here.
void _drainWide(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  // The chips' row scrolls sideways; a chip may start out of view.
  await tester.ensureVisible(_chip(label));
  await tester.pump();
  await tester.tap(_chip(label));
  await ph5Settle(tester);
}

/// A wide card's figures (its title, then the amount and the count).
Set<String> _card(String title) => ph5Texts(find.ancestor(of: find.text(title), matching: find.byType(Column)).first)..remove(title);

void main() {
  ph5TestWidgets('the app bar: back arrow, title, search, Date Range in the menu; no floating button', (tester) async {
    await _open(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(ph5Key('phoneList-fab'), findsNothing);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    await tester.tap(find.text('Date Range'));
    await ph5Settle(tester);
    expect(find.byType(DateRangeDialog), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Today, Yesterday and All set the days as the date range did', (tester) async {
    await _open(tester);
    expect(tester.widget<ChoiceChip>(find.ancestor(of: _chip('Today'), matching: find.byType(ChoiceChip))).selected, isTrue);
    expect(ph5RowIds(tester), {'p1', 'p2'});
    await _tapChip(tester, 'Yesterday');
    expect(ph5RowIds(tester), {'p3'});
    await _tapChip(tester, 'All');
    expect(ph5RowIds(tester), {'p1', 'p2', 'p3', 'p4'});
  }, skip: _skip);

  ph5TestWidgets('the Filter sheet (type, method) gives the toolbar\'s results', (tester) async {
    await _open(tester, size: _wide);
    await tester.tap(find.text('Type: All'));
    await ph5Settle(tester);
    await tester.tap(find.text('Type: Debt Repayments').last);
    await ph5Settle(tester);
    _drainWide(tester);
    final byType = {for (final n in ['Amina Juma', 'Baraka Mushi']) if (find.text(n).evaluate().isNotEmpty) n};
    expect(byType, {'Baraka Mushi'});

    await _open(tester);
    await ph5OpenSheet(tester, 'Filter');
    expect(ph5InSheet('Type'), findsOneWidget);
    expect(ph5InSheet('Method'), findsOneWidget);
    await tester.tap(ph5InSheet('Debt Repayments'));
    await tester.pump();
    await tester.tap(ph5InSheet('Apply'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'p2'});
    await ph5OpenSheet(tester, 'Filter');
    await tester.tap(ph5InSheet('Reset'));
    await tester.tap(ph5InSheet('M-Pesa'));
    await tester.pump();
    await tester.tap(ph5InSheet('Apply'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'p1'});
    expect(find.descendant(of: ph5Key('phoneList-appliedChips'), matching: find.text('Method: M-Pesa')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the summary line and a Summary sheet with the four cards and the total, as on the tablet', (tester) async {
    await _open(tester, size: _wide);
    _drainWide(tester);
    final cards = {for (final t in ['Today', 'This Week', 'This Month', 'Outstanding']) t: _card(t)};
    expect(cards['Today'], containsAll([Money.format(27000), '2 payments', '80.0%']));
    expect(find.text('Total: ${Money.format(27000)}'), findsOneWidget);

    await _open(tester);
    expect(find.text('2 payments, ${Money.format(27000)}'), findsOneWidget);
    await ph5OpenSummary(tester);
    final sheet = find.byType(BottomSheet);
    for (final e in cards.entries) {
      final amount = e.value.firstWhere((t) => t.startsWith('Tsh'));
      expect(ph5SheetValue(tester, e.key), amount, reason: e.key);
      final count = e.value.firstWhere((t) => t.endsWith('payments') || t.endsWith('payment') || t.endsWith('debts') || t.endsWith('debt'));
      expect(find.descendant(of: sheet, matching: find.textContaining(count)), findsWidgets, reason: '${e.key} $count');
    }
    expect(find.descendant(of: sheet, matching: find.textContaining('+80.0%')), findsOneWidget);
    expect(ph5SheetValue(tester, 'Total'), Money.format(27000));
  }, skip: _skip);

  ph5TestWidgets('grouped by day with day totals; rows: initials, client and amount, method and time, the source', (tester) async {
    await _open(tester);
    await _tapChip(tester, 'All');
    for (final (days, total) in [(0, 27000), (1, 15000), (3, 4000)]) {
      final header = ph5Key('phoneList-day-${ph5DayKey(ph5When(days))}');
      expect(find.descendant(of: header, matching: find.text(Money.format(total))), findsOneWidget, reason: '$days');
    }
    final row = ph5Key('phoneList-row-p1');
    for (final t in ['AJ', 'Amina Juma', Money.format(20000), 'M-Pesa', DateFormat('HH:mm').format(_payments.first.when), 'Sale payment']) {
      expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget, reason: t);
    }
  }, skip: _skip);

  ph5TestWidgets('the details page: the panel\'s content (recorded by), Call and Print Receipt', (tester) async {
    await _open(tester, size: _wide);
    await tester.tap(find.text('Baraka Mushi'));
    await ph5Settle(tester);
    _drainWide(tester);
    final panel = ph5Texts(find.ancestor(of: find.text('Payment Details'), matching: find.byType(SingleChildScrollView)).first);
    expect(panel, contains('Asha Seller'));

    await _open(tester);
    await tester.tap(ph5Key('phoneList-row-p2'));
    await ph5Settle(tester);
    expect(ph5Texts(ph5Page), panel);
    expect(find.descendant(of: ph5Page, matching: find.text('Print Receipt')), findsOneWidget);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Call')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('for one client: "Payments - Amina Juma", no Filter, All chosen, that client\'s payments', (tester) async {
    await _open(tester, forClient: true);
    expect(find.text('Payments - Amina Juma'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsNothing);
    expect(tester.widget<ChoiceChip>(find.ancestor(of: _chip('All'), matching: find.byType(ChoiceChip))).selected, isTrue);
    expect(ph5RowIds(tester), {'p1', 'p4'});
    expect(find.text('2 payments, ${Money.format(24000)}'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('pull to refresh starts the list over and reloads the cards', (tester) async {
    final app = await _open(tester);
    await tester.runAsync(() => ph5SeedPayments(app.fs, [Ph5Payment('p5', ph5When(0, minutes: 1), client: 'Zawadi Said', amount: 1000)]));
    expect(ph5RowIds(tester), isNot(contains('p5')));
    await ph5Pull(tester);
    expect(ph5RowIds(tester), contains('p5'));
    expect(find.text('3 payments, ${Money.format(28000)}'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('states: six skeleton rows; empty (no button); error with Retry', (tester) async {
    final held = CountingFirestore()..holdGets = Completer<void>();
    await tester.runAsync(() => ph5SeedPayments(held.inner, _payments));
    await _open(tester, firestore: held, settle: false);
    expect(find.descendant(of: ph5Key('phoneList-skeleton'), matching: ph5SkeletonRows), findsNWidgets(6));
    held.holdGets!.complete();
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'p1', 'p2'});

    await _open(tester, payments: const []);
    final empty = ph5Key('phoneList-empty');
    expect(find.descendant(of: empty, matching: find.text('No payments in this period.')), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.byType(FilledButton)), findsNothing);

    final failing = CountingFirestore()..failGets = true;
    await tester.runAsync(() => ph5SeedPayments(failing.inner, _payments));
    await _open(tester, firestore: failing);
    expect(ph5Key('phoneList-error'), findsOneWidget);
    failing.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'p1', 'p2'});
  }, skip: _skip);
}
