// PH5a (docs/design/phone_list_pattern.md): Sales on a phone. The app bar
// (R1), no record button (R2), the quick chips and the filter sheet against
// the tablet toolbar on the same data (R3), the summary line and sheet
// against the tablet's cards (R4), the day groups and their totals (R5), the
// rows (R6), pull to refresh (R8) and paging (R10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';

import 'helpers/phone_list_harness.dart';

const _skip = true;

const _phone = Size(390, 844);
const _wide = Size(1200, 800);

Finder _key(String k) => find.byKey(ValueKey(k));

/// The list's own scrollable (not the chips' sideways one).
Finder get _list => find.descendant(of: _key('phoneList-scroll'), matching: find.byType(Scrollable)).first;

/// Every invoice number drawn under [root] (the phone rows or the table).
Set<String> _invoices(WidgetTester tester) => {
      for (final e in find.textContaining('SL-0').evaluate()) (e.widget as Text).data!,
    };

final _six = [
  Ph5Sale('s1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 45000, paid: 45000, receipt: 1),
  Ph5Sale('s2', ph5When(0, minutes: 40), amount: 12000, paid: 0, receipt: 2),
  Ph5Sale('s3', ph5When(1), client: 'Baraka Mushi', amount: 8000, paid: 3000, seller: 'Juma', receipt: 3),
  Ph5Sale('s4', ph5When(2), client: 'Amina Juma', amount: 20000, paid: 20000, seller: 'Juma', receipt: 4),
  Ph5Sale('s5', ph5When(9), client: 'Neema Ally', amount: 5000, paid: 5000, seller: 'Juma', receipt: 5),
  Ph5Sale('s6', ph5When(20), client: 'Neema Ally', amount: 7000, paid: 0, receipt: 6),
];

Future<Ph5App> _sales(WidgetTester tester, {Size size = _phone, List<Ph5Sale>? sales, bool asTab = true}) =>
    pumpPh5(tester, (fs) => SalesScreen(firestore: fs, asTab: asTab), size: size, pushed: !asTab,
        seed: (fs) => ph5SeedSales(fs, sales ?? _six));

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filter'));
  await ph5Settle(tester);
}

Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

/// A card's or a sheet row's value: the texts beside [label] in its box.
List<String> _valuesBeside(WidgetTester tester, Finder label, Type box, {Set<String> skip = const {}}) {
  final container = find.ancestor(of: label, matching: find.byType(box)).first;
  return [
    for (final e in find.descendant(of: container, matching: find.byType(Text)).evaluate())
      if (!skip.contains((e.widget as Text).data) && (e.widget as Text).data != (label.evaluate().first.widget as Text).data)
        (e.widget as Text).data!,
  ];
}

void main() {
  group('the app bar (R1) and no record button (R2)', () {
    testWidgets('as a tab: the title only, a search icon and one overflow menu with Archive; nothing else', (tester) async {
      await _sales(tester);
      expect(find.text('Sales Records'), findsOneWidget);
      expect(find.text('Track and manage all sales transactions'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.text('Record Sale'), findsNothing, reason: 'the bar\'s "+" records a sale');
      expect(_key('phoneList-fab'), findsNothing);
      await tester.tap(find.byTooltip('Show menu'));
      await ph5Settle(tester);
      expect(find.text('Archive'), findsOneWidget);
    }, skip: _skip);

    testWidgets('pushed: the back arrow', (tester) async {
      await _sales(tester, asTab: false);
      expect(find.byType(BackButton), findsOneWidget);
    }, skip: _skip);

    testWidgets('the cards, the toolbar, the table header and the page bar are gone', (tester) async {
      await _sales(tester);
      expect(find.text('Revenue'), findsNothing);
      expect(find.text('Date: Last 30 days'), findsNothing);
      expect(find.text('Invoice No.'), findsNothing);
      expect(find.text('Page 1'), findsNothing);
    }, skip: _skip);
  });

  group('search and filters (R3)', () {
    testWidgets('the quick chips: All, Unpaid, Partial, Paid; a chip filters by that status', (tester) async {
      await _sales(tester);
      final chips = _key('phoneList-quickChips');
      final labels = [for (final l in ['All', 'Unpaid', 'Partial', 'Paid']) tester.getCenter(find.descendant(of: chips, matching: find.text(l))).dx];
      expect(labels, [...labels]..sort());
      await tester.tap(find.descendant(of: chips, matching: find.text('Unpaid')));
      await ph5Settle(tester);
      expect(_invoices(tester), {'SL-000002', 'SL-000006'});
      expect(_key('phoneList-filterDot'), findsOneWidget);
      await tester.tap(find.descendant(of: chips, matching: find.text('All')));
      await ph5Settle(tester);
      expect(_invoices(tester), hasLength(6));
      expect(_key('phoneList-filterDot'), findsNothing);
    }, skip: _skip);

    testWidgets('the filter sheet gives the tablet toolbar\'s results for the same data', (tester) async {
      await _sales(tester, size: _wide);
      Future<void> pick(String current, String choice) async {
        await tester.tap(find.text(current));
        await ph5Settle(tester);
        await tester.tap(find.text(choice).last);
        await ph5Settle(tester);
      }

      await pick('Date: Last 30 days', 'Date: Last 7 days');
      await pick('Seller: All', 'Seller: Juma');
      final toolbar = _invoices(tester);
      await pick('Payment Status: All', 'Payment Status: Paid');
      final toolbarPaid = _invoices(tester);
      expect(toolbar, {'SL-000003', 'SL-000004'});
      expect(toolbarPaid, {'SL-000004'});

      await _sales(tester);
      await _openSheet(tester);
      for (final field in ['Date', 'Payment Status', 'Seller']) {
        expect(_inSheet(field), findsOneWidget);
      }
      await tester.tap(_inSheet('Last 7 days'));
      await tester.tap(_inSheet('Juma'));
      await tester.pump();
      await tester.tap(_inSheet('Apply'));
      await ph5Settle(tester);
      expect(_invoices(tester), toolbar);
      await _openSheet(tester);
      await tester.tap(_inSheet('Paid'));
      await tester.pump();
      await tester.tap(_inSheet('Apply'));
      await ph5Settle(tester);
      expect(_invoices(tester), toolbarPaid);
    }, skip: _skip);

    testWidgets('applied filters show as removable chips; Reset in the sheet puts the defaults back', (tester) async {
      await _sales(tester);
      await _openSheet(tester);
      await tester.tap(_inSheet('Last 7 days'));
      await tester.tap(_inSheet('Juma'));
      await tester.pump();
      await tester.tap(_inSheet('Apply'));
      await ph5Settle(tester);
      final applied = _key('phoneList-appliedChips');
      expect(find.descendant(of: applied, matching: find.text('Date: Last 7 days')), findsOneWidget);
      expect(find.descendant(of: applied, matching: find.text('Seller: Juma')), findsOneWidget);
      await tester.tap(find.descendant(of: applied, matching: find.byTooltip('Remove')).first);
      await ph5Settle(tester);
      expect(find.text('Date: Last 7 days'), findsNothing);
      expect(_invoices(tester), {'SL-000003', 'SL-000004', 'SL-000005'});
      await _openSheet(tester);
      await tester.tap(_inSheet('Reset'));
      await tester.pump();
      await tester.tap(_inSheet('Apply'));
      await ph5Settle(tester);
      expect(applied, findsNothing);
      expect(_invoices(tester), hasLength(6));
    }, skip: _skip);

    testWidgets('search expands in place; results are not grouped; Close clears it', (tester) async {
      await _sales(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      await tester.enterText(_key('phoneList-searchField'), 'amina');
      await tester.pump(const Duration(seconds: 1));
      await ph5Settle(tester);
      expect(_invoices(tester), {'SL-000001', 'SL-000004'});
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-day-')),
          findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await ph5Settle(tester);
      expect(_invoices(tester), hasLength(6));
    }, skip: _skip);
  });

  group('the summary (R4)', () {
    testWidgets('one line and a Summary sheet with every card\'s figure, equal to the tablet\'s cards', (tester) async {
      await _sales(tester, size: _wide);
      const labels = ['Total Sales', 'Revenue', 'Collected', 'Pending'];
      final cards = {for (final l in labels) l: _valuesBeside(tester, find.text(l), FittedBox, skip: {'Last 30 days'})};
      expect(cards['Revenue'], [Money.format(97000)]);

      await _sales(tester);
      expect(find.text('Last 30 days: 6 sales, ${Money.format(97000)}'), findsOneWidget);
      await tester.tap(find.text('Summary'));
      await ph5Settle(tester);
      for (final l in labels) {
        expect(_valuesBeside(tester, _inSheet(l), Row), cards[l], reason: l);
      }
    }, skip: _skip);
  });

  group('grouped by day (R5) with rows (R6)', () {
    testWidgets('Today, Yesterday, then the weekday and date; each day\'s total; no Date column', (tester) async {
      await _sales(tester);
      final today = ph5DayKey(ph5When(0));
      final yesterday = ph5DayKey(ph5When(1));
      expect(find.descendant(of: _key('phoneList-day-$today'), matching: find.text('Today')), findsOneWidget);
      expect(find.descendant(of: _key('phoneList-day-$yesterday'), matching: find.text('Yesterday')), findsOneWidget);
      expect(find.descendant(of: _key('phoneList-day-$today'), matching: find.text(Money.format(57000))), findsOneWidget);
      final row = _key('phoneList-row-s1');
      for (final t in ['Amina Juma', Money.format(45000), 'SL-000001', 'Paid']) {
        expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: _key('phoneList-row-s2'), matching: find.text('Walk-in')), findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(64));
    }, skip: _skip);

    testWidgets('a day cut by the page end shows no total until it is fully loaded', (tester) async {
      // 20 today and 10 yesterday: the first page (25) ends inside yesterday.
      final sales = [
        for (var i = 0; i < 20; i++) Ph5Sale('t$i', ph5When(0, minutes: i), amount: 1000, receipt: 100 + i),
        for (var i = 0; i < 10; i++) Ph5Sale('y$i', ph5When(1, minutes: i), amount: 1000, receipt: 200 + i),
      ];
      await _sales(tester, sales: sales);
      final yesterday = ph5DayKey(ph5When(1));
      expect(find.descendant(of: _key('phoneList-day-${ph5DayKey(ph5When(0))}'), matching: find.text(Money.format(20000))),
          findsOneWidget);
      await tester.scrollUntilVisible(_key('phoneList-day-$yesterday'), 200, scrollable: _list);
      expect(find.descendant(of: _key('phoneList-day-$yesterday'), matching: find.textContaining('Tsh')), findsNothing);
      // Scrolling near the end loads the next page by itself.
      for (var i = 0; i < 3; i++) {
        await tester.drag(_list, const Offset(0, -3000));
        await ph5Settle(tester);
      }
      await tester.scrollUntilVisible(_key('phoneList-row-y9'), 200, scrollable: _list);
      expect(find.descendant(of: _key('phoneList-day-$yesterday'), matching: find.text(Money.format(10000))), findsOneWidget);
      expect(_key('phoneList-loadMore'), findsNothing);
    }, skip: _skip);
  });

  group('refresh (R8)', () {
    testWidgets('pull to refresh restarts the list and reloads the summary', (tester) async {
      final app = await _sales(tester);
      await tester.runAsync(() => ph5SeedSales(app.fs, [..._six, Ph5Sale('s7', ph5When(0, minutes: 1), amount: 3000, receipt: 7)]));
      expect(_invoices(tester), isNot(contains('SL-000007')));
      await tester.fling(_key('phoneList-scroll'), const Offset(0, 500), 1500);
      await tester.pump(const Duration(seconds: 1));
      await ph5Settle(tester);
      expect(_invoices(tester), contains('SL-000007'));
      expect(find.text('Last 30 days: 7 sales, ${Money.format(100000)}'), findsOneWidget);
    }, skip: _skip);
  });
}
