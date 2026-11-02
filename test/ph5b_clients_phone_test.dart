// PH5b (docs/design/phone_list_pattern.md): Clients on a phone. Pushed from
// More (back arrow, title, no overflow menu: the screen has no secondary
// action), Add Client floating (R2), status chips and the Filter sheet
// against the toolbar (R3), "N clients" and a Summary sheet with the four
// cards (R4), a plain list with no day headers (R5: the list is not by
// date), rows (R6), the details page (R7), pull to refresh (R8), the states
// (R9) and paging (R10).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = true;

const _wide = Size(1200, 800);

final _three = [
  Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer', 'Vet'], phone: '0712111111'),
  Ph5Client('c2', 'Baraka Mushi', ph5When(0, minutes: 30), types: ['Retailer'], status: 'Inactive'),
  Ph5Client('c3', 'Neema Ally', ph5When(0, minutes: 60)),
];

final _many = [for (var i = 0; i < 30; i++) Ph5Client('m$i', 'Client $i', ph5When(0, minutes: 100 + i))];

Future<Ph5App> _clients(WidgetTester tester,
        {Size size = const Size(390, 844), List<Ph5Client>? clients, bool admin = true, CountingFirestore? firestore, bool settle = true}) =>
    pumpPh5(tester, (fs) => ClientsScreen(firestore: fs),
        size: size, pushed: true, admin: admin, firestore: firestore, settle: settle, seed: (fs) => ph5SeedClients(fs, clients ?? _three));


/// The clients the wide table lists (the cards also name the last added).
Set<String> _tableNames(WidgetTester tester) => {
      for (final c in _three)
        if (find.descendant(of: find.byType(ListView), matching: find.text(c.name)).evaluate().isNotEmpty) c.name,
    };

const _names = {'c1': 'Amina Juma', 'c2': 'Baraka Mushi', 'c3': 'Neema Ally'};
Set<String> _rowNames(WidgetTester tester) => {for (final id in ph5RowIds(tester)) _names[id] ?? id};

void main() {
  ph5TestWidgets('the app bar: back arrow, the title, search; no overflow menu (nothing secondary)', (tester) async {
    await _clients(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Show menu'), findsNothing);
    expect(find.text('Add Client'), findsOneWidget, reason: 'only the floating button');
  }, skip: _skip);

  ph5TestWidgets('Add Client floats, shrinks scrolling down, grows back, hides with the keyboard, opens the form', (tester) async {
    await _clients(tester, clients: _many);
    expect(ph5FabExtended('Add Client'), isTrue);
    await tester.drag(ph5List, const Offset(0, -300));
    await ph5Settle(tester);
    expect(ph5FabExtended('Add Client'), isFalse);
    await tester.drag(ph5List, const Offset(0, 150));
    await ph5Settle(tester);
    expect(ph5FabExtended('Add Client'), isTrue);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddClientScreen), findsOneWidget);
    while (tester.takeException() != null) {}
  }, skip: _skip);

  ph5TestWidgets('hidden while the keyboard is open', (tester) async {
    await _clients(tester);
    await ph5OpenKeyboard(tester);
    expect(ph5Key('phoneList-fab'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('status chips and the Filter sheet give the toolbar\'s results', (tester) async {
    await _clients(tester, size: _wide);
    await tester.tap(find.text('Status: All'));
    await ph5Settle(tester);
    await tester.tap(find.text('Inactive').last);
    await ph5Settle(tester);
    final inactive = _tableNames(tester);
    await tester.tap(find.text('Inactive').first);
    await ph5Settle(tester);
    await tester.tap(find.text('Status: All').last);
    await ph5Settle(tester);
    await tester.tap(find.text('Type: All'));
    await ph5Settle(tester);
    await tester.tap(find.text('Vet').last);
    await ph5Settle(tester);
    final vets = _tableNames(tester);
    expect(inactive, {'Baraka Mushi'});
    expect(vets, {'Amina Juma'});

    await _clients(tester);
    for (final chip in ['All', 'Active', 'Inactive']) {
      expect(find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text(chip)), findsOneWidget, reason: chip);
    }
    await tester.tap(find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text('Inactive')));
    await ph5Settle(tester);
    expect(_rowNames(tester), inactive);
    await tester.tap(find.descendant(of: ph5Key('phoneList-quickChips'), matching: find.text('All')));
    await ph5Settle(tester);
    await ph5OpenSheet(tester, 'Filter');
    for (final field in ['Type', 'Status']) {
      expect(ph5InSheet(field), findsOneWidget);
    }
    await tester.tap(ph5InSheet('Vet'));
    await tester.pump();
    await tester.tap(ph5InSheet('Apply'));
    await ph5Settle(tester);
    expect(_rowNames(tester), vets);
    expect(find.descendant(of: ph5Key('phoneList-appliedChips'), matching: find.text('Type: Vet')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('"3 clients" and a Summary sheet with the four cards\' figures, as the tablet shows them', (tester) async {
    final cards = {'Total Clients': '3', 'New This Month': '3', 'Most Active Type': 'Farmer', 'Last Added': 'Amina Juma'};
    await _clients(tester, size: _wide);
    for (final e in cards.entries) {
      final card = find.ancestor(of: find.text(e.key), matching: find.byType(Container)).first;
      expect(find.descendant(of: card, matching: find.text(e.value)), findsOneWidget, reason: e.key);
    }
    expect(find.text('67% of clients'), findsOneWidget);

    await _clients(tester);
    expect(find.text('3 clients'), findsOneWidget);
    await ph5OpenSummary(tester);
    for (final e in cards.entries) {
      expect(ph5SheetValue(tester, e.key), e.value, reason: e.key);
    }
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('67% of clients')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('All time')), findsWidgets);
  }, skip: _skip);

  ph5TestWidgets('rows: initials, the name, phone and joined date, the types as a chip; no amount; no day headers', (tester) async {
    await _clients(tester);
    final row = ph5Key('phoneList-row-c1');
    for (final t in ['AJ', 'Amina Juma', '0712111111', DateFormat('dd MMM yyyy').format(_three.first.created), 'Farmer, Vet']) {
      expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: row, matching: find.textContaining('Tsh')), findsNothing);
    expect(ph5HasDayHeaders(tester), isFalse);
    expect(ph5RowIds(tester), {'c1', 'c2', 'c3'});
  }, skip: _skip);

  ph5TestWidgets('the details page: the panel\'s content, Call and Save / Share, Edit; Delete asks, closes, Undo', (tester) async {
    await _clients(tester, size: _wide);
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text('Neema Ally')));
    await ph5Settle(tester);
    final panel = ph5Texts(find.ancestor(of: find.text('Client Details'), matching: find.byType(SingleChildScrollView)).first);

    await _clients(tester);
    await tester.tap(ph5Key('phoneList-row-c3'));
    await ph5Settle(tester);
    expect(ph5Texts(ph5Page), panel);
    expect(find.descendant(of: ph5Page, matching: find.byType(BackButton)), findsOneWidget);
    for (final action in ['Call', 'Edit', 'Delete']) {
      expect(find.descendant(of: ph5Page, matching: find.byTooltip(action)), findsOneWidget, reason: action);
    }
    expect(find.descendant(of: ph5Page, matching: find.text('Save / Share')), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await ph5Settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await ph5Settle(tester);
    expect(ph5Page, findsNothing);
    expect(ph5Key('phoneList-row-c3'), findsNothing);
    await tester.tap(find.text('Undo'));
    await ph5Settle(tester);
    await ph5Settle(tester);
    expect(ph5Key('phoneList-row-c3'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('an assistant\'s page: Edit, no Delete (today\'s row menu)', (tester) async {
    await _clients(tester, admin: false);
    await tester.tap(ph5Key('phoneList-row-c1'));
    await ph5Settle(tester);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsOneWidget);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('pull to refresh starts the list over (a client added since shows)', (tester) async {
    final app = await _clients(tester);
    await tester.runAsync(() => ph5SeedClients(app.fs, [Ph5Client('c4', 'Zawadi Said', DateTime.now())]));
    expect(ph5RowIds(tester), isNot(contains('c4')));
    await ph5Pull(tester);
    expect(ph5RowIds(tester), contains('c4'));
  }, skip: _skip);

  ph5TestWidgets('paging: the next page loads near the end; Load more is the fallback', (tester) async {
    await _clients(tester, clients: _many);
    expect(ph5RowIds(tester), hasLength(25));
    for (var i = 0; i < 3; i++) {
      await tester.drag(ph5List, const Offset(0, -3000));
      await ph5Settle(tester);
    }
    expect(ph5RowIds(tester), hasLength(30));
    expect(ph5Key('phoneList-loadMore'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('states: six skeleton rows, then the rows; empty with Add Client; error with Retry', (tester) async {
    final held = CountingFirestore()..holdGets = Completer<void>();
    await tester.runAsync(() => ph5SeedClients(held.inner, _three));
    await _clients(tester, firestore: held, settle: false);
    expect(find.descendant(of: ph5Key('phoneList-skeleton'), matching: ph5SkeletonRows), findsNWidgets(6));
    held.holdGets!.complete();
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(3));

    await _clients(tester, clients: const []);
    final empty = ph5Key('phoneList-empty');
    expect(find.descendant(of: empty, matching: find.text('No clients found')), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Add Client')), findsOneWidget);

    final failing = CountingFirestore()..failGets = true;
    await tester.runAsync(() => ph5SeedClients(failing.inner, _three));
    await _clients(tester, firestore: failing);
    expect(ph5Key('phoneList-error'), findsOneWidget);
    failing.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(3));
  }, skip: _skip);
}
