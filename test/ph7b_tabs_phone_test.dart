// PH7b (docs/design/phone_reports.md): the report's 10 tabs on a phone.
// The scrollable tab bar (R1); per tab the same figures as the tablet's tab
// for the same report, compared as numbers, the rows behind See all
// included (R2, R4, R5); See all (R3); the role rules (R4, R6); Tigo Pesa
// and Mixx by Yas as one row (R7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/reports/report_tabbed_content.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _tabs = [
  'Summary',
  'Sales',
  'Services',
  'Products',
  'Stock Reconciliation',
  'Debt',
  'Expenses',
  'Transactions',
  'Activity Log',
  'Payment Methods',
];

final _number = RegExp(r'\d[\d,]*');

bool _inSeeAllRow(Element e) {
  var found = false;
  e.visitAncestorElements((a) {
    final key = a.widget.key;
    found = key is ValueKey<String> && key.value.startsWith('phoneReport-seeAll-');
    return !found;
  });
  return found;
}

/// The numbers every text under [root] shows (not See all's own count).
Set<String> _numbers(Finder root) => {
      for (final e in find.descendant(of: root, matching: find.byType(RichText)).evaluate())
        if (!_inSeeAllRow(e))
          for (final m in _number.allMatches((e.widget as RichText).text.toPlainText())) m.group(0)!,
    };

/// The open phone tab's numbers, and those of every See all page in it.
Future<Set<String>> _phoneNumbers(WidgetTester tester, String tab) async {
  final page = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneReport-tab-'));
  final out = _numbers(page);
  final seeAll = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneReport-seeAll-'));
  for (var i = 0; i < seeAll.evaluate().length; i++) {
    await tester.ensureVisible(seeAll.at(i));
    await tester.pump();
    await tester.tap(seeAll.at(i));
    await ph5Settle(tester);
    out.addAll(_numbers(find.byType(Scaffold).last));
    await tester.tap(find.byType(BackButton).last);
    await ph5Settle(tester);
  }
  return out;
}

/// The tablet's open tab (a tall window, so every row is built). Summary:
/// its Daily Summary card and the generated and submitted lines (the four
/// preview cards repeat the other tabs' first rows).
Set<String> _tabletNumbers(String tab) {
  if (tab != 'Summary') return _numbers(find.byType(TabBarView));
  final card = find.ancestor(of: find.text('Daily Summary'), matching: find.byType(Container)).first;
  return {
    ..._numbers(card),
    ..._numbers(find.textContaining('Generated ')),
    ..._numbers(find.textContaining('Submitted at')),
  };
}

void main() {
  ph5TestWidgets('R1: one scrollable bar from the left, labels at 14, tabs 48 high; the chosen tab is scrolled into view', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport(activityLog: true));
    final bar = tester.widget<TabBar>(find.descendant(of: find.byKey(const ValueKey('phoneReport-tabBar')), matching: find.byType(TabBar)));
    expect(bar.isScrollable, isTrue);
    expect(bar.tabAlignment, TabAlignment.start);
    expect(bar.labelStyle?.fontSize, 14);
    expect(bar.tabs, hasLength(10));
    expect(tester.getSize(find.byType(Tab).first).height, greaterThanOrEqualTo(48));
    // Swipe the pages to the end: the last tab comes into view.
    for (var i = 0; i < 9; i++) {
      await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1000);
      await ph5Settle(tester);
    }
    final last = tester.getRect(find.text('Payment Methods'));
    expect(last.right, lessThanOrEqualTo(390));
    expect(last.left, greaterThanOrEqualTo(0));
  }, skip: _skip);

  for (final tab in _tabs) {
    ph5TestWidgets('$tab: the phone shows the tablet\'s figures for the same report', (tester) async {
      final report = ph7bReport(activityLog: true);
      await ph7bPumpTabs(tester, report, size: const Size(1200, 2400));
      await ph7bOpenTab(tester, tab);
      ph7bDropWideFontErrors(tester);
      final tablet = _tabletNumbers(tab);
      expect(tablet, isNotEmpty);

      // A phone as tall as the tablet: every row of the lazy list is built.
      await ph7bPumpTabs(tester, report, size: const Size(390, 4000));
      await ph7bOpenTab(tester, tab);
      expect(tester.takeException(), isNull);
      expect(await _phoneNumbers(tester, tab), tablet);
    }, skip: _skip);
  }

  ph5TestWidgets('R3: Sales shows 5 rows and See all (7); See all opens every row in the same order', (tester) async {
    final report = ph7bReport();
    await ph7bPumpTabs(tester, report);
    await ph7bOpenTab(tester, 'Sales');
    final section = find.byKey(const ValueKey('phoneReport-section-sales'));
    final names = [for (final s in report.salesLineItems) s.customerName];
    expect(find.descendant(of: section, matching: find.text(names[5])), findsNothing);
    expect(find.text('See all (7)'), findsOneWidget);
    await tester.ensureVisible(find.text('See all (7)'));
    await tester.pump();
    await tester.tap(find.text('See all (7)'));
    await ph5Settle(tester);
    final page = find.byKey(const ValueKey('phoneReport-seeAllPage-sales'));
    expect(page, findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('Sales')), findsOneWidget, reason: 'the heading as the title');
    final shown = [
      for (final e in find.descendant(of: page, matching: find.byType(Text)).evaluate())
        if (names.contains((e.widget as Text).data)) (e.widget as Text).data,
    ];
    expect(shown, names);
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    expect(page, findsNothing);
  }, skip: _skip);

  ph5TestWidgets('R4, R6: an assistant has 9 tabs (no Activity Log) and no Expenses in Summary; an admin has both', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport(), admin: false);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(9));
    expect(find.text('Activity Log'), findsNothing);
    final summary = find.byKey(const ValueKey('phoneReport-section-summary'));
    expect(find.descendant(of: summary, matching: find.text('Expenses')), findsNothing);
    expect(find.descendant(of: summary, matching: find.text('Total Sales')), findsOneWidget);
    expect(find.textContaining('Net Profit'), findsNothing);

    await ph7bPumpTabs(tester, ph7bReport());
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(10));
    expect(find.descendant(of: find.byKey(const ValueKey('phoneReport-section-summary')), matching: find.text('Expenses')),
        findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('R5: Stock Reconciliation shows expected and physical, the difference as text and colour, the reason', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport());
    await ph7bOpenTab(tester, 'Stock Reconciliation');
    expect(find.text('Expected: 120  |  Physical: 118'), findsOneWidget);
    expect(find.text('-2'), findsOneWidget);
    expect(find.text('Variance'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Reason: Two bottles broken'), findsOneWidget);

    await ph7bPumpTabs(tester, ph7bReport(status: 'draft'));
    await ph7bOpenTab(tester, 'Stock Reconciliation');
    expect(find.text('Physical counts have not been submitted yet.'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('R6: the Activity Log tab lists the admin\'s log as two-line rows', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport(activityLog: true));
    await ph7bOpenTab(tester, 'Activity Log');
    expect(find.text('Expense: Electricity'), findsOneWidget);
    expect(find.text('09:10'), findsOneWidget);
    expect(find.text('Juma Admin'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('R7: Payment Methods shows Tigo Pesa and Mixx by Yas as one Mixx by Yas row', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport());
    await ph7bOpenTab(tester, 'Payment Methods');
    expect(find.text('Tigo Pesa'), findsNothing);
    final combined = find.byKey(const ValueKey('phoneReport-section-methods-combined'));
    final row = find.ancestor(of: find.descendant(of: combined, matching: find.text('Mixx by Yas')), matching: find.byType(Row)).first;
    // Sales 30,000 + 45,000, services 40,000 + 60,000, repayments 30,000,
    // other income 20,000.
    expect(find.descendant(of: row, matching: find.text(Money.format(225000))), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Products: a long press shows the adjustment\'s detail (the tablet\'s tooltip)', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport());
    await ph7bOpenTab(tester, 'Products');
    await tester.longPress(find.text('Adjusted: -2'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Asha: 122 -> 120 at 10:20'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('tablets keep today\'s tab bar and tabs (no phone pieces)', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport(), size: const Size(1024, 768));
    ph7bDropWideFontErrors(tester);
    expect(find.byKey(const ValueKey('phoneReport-tabBar')), findsNothing);
    expect(find.byType(ReportTabbedContent), findsOneWidget);
  }, skip: _skip);
}
