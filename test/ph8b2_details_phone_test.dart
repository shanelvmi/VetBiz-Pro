// PH8b-2 P2 (docs/design/phone_facilities.md): a facility's details on a
// phone, a full page opened from its list row: the app bar shows the name
// alone and one menu with today's More Actions; one column: the header card
// (the code and licence with their Copy buttons), the metrics in two
// columns, Overview inline, then the other five tabs as rows (icon, label,
// the Team Members count), each opening its own page with today's content.
// Nothing scrolls sideways.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8b2_facility_page.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/phone_list_harness.dart';

// True until the phone page is built (P2).
const _skip = false;

final _en = ph8b2En;

/// Each tab's index, its label and texts only its content shows.
final _tabs = <(int, String, List<String>)>[
  (1, _en.team_title, [_en.facilities_teamTabMessage, _en.facilities_openTeamMembers]),
  (2, _en.facilities_tabInventory, [_en.facilities_noProducts]),
  (3, _en.facilities_tabSales, [_en.facilities_recentSales]),
  (4, _en.export_activityLog, []),
  (5, _en.settings_title, [_en.facilities_actionsTitle, _en.facilities_retentionTitle, _en.facilities_overdueTitle]),
];

bool _noSidewaysScroller(WidgetTester tester) => tester
    .widgetList<Scrollable>(find.byType(Scrollable))
    .every((s) => s.axisDirection == AxisDirection.down || s.axisDirection == AxisDirection.up);

void main() {
  ph5TestWidgets('the app bar: the name alone, one menu; the header card, metrics, Overview, five rows', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    final bar = find.descendant(of: find.byKey(ph8b2Details), matching: find.byType(AppBar));
    expect(find.descendant(of: bar, matching: find.text('Kilimo Agrovet')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byKey(ph8b2Menu)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byType(IconButton)).evaluate().length, 2, reason: 'the back arrow and the menu only');
    expect(find.text(_en.facilities_moreActions), findsNothing);
    expect(find.byKey(ph8b2Header), findsOneWidget);
    expect(find.byKey(ph8b2Metrics), findsOneWidget);
    expect(find.text(_en.facilities_aboutTitle), findsOneWidget);
    for (final (i, label, _) in _tabs) {
      expect(find.descendant(of: ph8b2TabRow(i), matching: find.text(label)), findsOneWidget, reason: label);
      expect(find.descendant(of: ph8b2TabRow(i), matching: find.byType(Icon)), findsWidgets, reason: label);
    }
    expect(_noSidewaysScroller(tester), isTrue);
  }, skip: _skip);

  ph5TestWidgets('the metrics sit in two columns', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    final labels = [_en.products_totalProducts, _en.products_sellableTitle, _en.facilities_lowStockItems, _en.facilities_expiredItems];
    final lefts = {
      for (final l in labels) tester.getTopLeft(find.descendant(of: find.byKey(ph8b2Metrics), matching: find.text(l))).dx.round(),
    };
    expect(lefts.length, 2);
  }, skip: _skip);

  ph5TestWidgets('the Team Members row shows the assistant count', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester, ph8bClinicId);
    expect(find.descendant(of: ph8b2TabRow(1), matching: find.text('1')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the menu holds today\'s More Actions: Edit, Switch to this (not the open one), Delete', (tester) async {
    await pumpPh8b2(tester, size: const Size(1200, 1600));
    await ph8b2Tap(tester, find.text('Mifugo Clinic'));
    await ph8b2Tap(tester, find.text(_en.facilities_moreActions));
    final wideOther = ph8b2MenuTexts(tester);
    ph8b2DropOverflows(tester);
    await pumpPh8b2(tester, size: const Size(1200, 1600));
    await ph8b2Tap(tester, find.text(_en.facilities_moreActions));
    final wideOpen = ph8b2MenuTexts(tester);
    ph8b2DropOverflows(tester);

    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester, ph8bClinicId);
    await ph8b2Tap(tester, find.byKey(ph8b2Menu));
    expect(ph8b2MenuTexts(tester), wideOther);
    expect(wideOther, [_en.facilities_editTitle, _en.facilities_switchToThis, _en.facilities_deleteTitle]);
    await tester.tapAt(const Offset(10, 10));
    await ph8b2Settle(tester);
    await tester.pageBack();
    await ph8b2Settle(tester);
    await ph8b2OpenDetails(tester);
    await ph8b2Tap(tester, find.byKey(ph8b2Menu));
    expect(ph8b2MenuTexts(tester), wideOpen);
  }, skip: _skip);

  ph5TestWidgets('the header card keeps the code and licence Copy buttons', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    final copies = find.descendant(of: find.byKey(ph8b2Header), matching: find.byIcon(Icons.copy));
    expect(copies, findsNWidgets(2));
    await ph8b2Tap(tester, copies.first);
    await ph8b2Tap(tester, copies.last);
    expect(copied, ['VBP-001', 'LIC-0']);
  }, skip: _skip);

  for (final (index, label, marks) in _tabs) {
    ph5TestWidgets('the $label row opens its own page with today\'s tab content', (tester) async {
      // Today's tab, on the wide screen.
      await pumpPh8b2(tester, size: const Size(1200, 1600));
      await ph8b2Tap(tester, find.text(label).first);
      for (final m in marks) {
        expect(find.text(m), findsWidgets, reason: 'wide $m');
      }
      ph8b2DropOverflows(tester);

      await pumpPh8b2(tester);
      await ph8b2OpenDetails(tester);
      await ph8b2OpenTab(tester, index);
      final page = ph8b2TabPage(index);
      expect(page, findsOneWidget);
      expect(find.descendant(of: find.descendant(of: page, matching: find.byType(AppBar)), matching: find.text(label)),
          findsOneWidget);
      for (final m in marks) {
        expect(find.descendant(of: page, matching: find.text(m)), findsWidgets, reason: 'phone $m');
      }
      expect(_noSidewaysScroller(tester), isTrue);
      await tester.pageBack();
      await ph8b2Settle(tester);
      expect(find.byKey(ph8b2Header), findsOneWidget);
    }, skip: _skip);
  }

  ph5TestWidgets('the Settings page holds today\'s rows: Edit details, Deactivate, Delete, retention, overdue', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    await ph8b2OpenTab(tester, 5);
    final page = ph8b2TabPage(5);
    for (final t in [
      _en.facilities_editDetails,
      _en.facilities_deactivateThis,
      _en.facilities_deleteThis,
      _en.facilities_retentionTitle,
      _en.facilities_overdueTitle,
    ]) {
      expect(find.descendant(of: page, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: page, matching: find.text(_en.common_change)), findsNWidgets(2));
  }, skip: _skip);

  ph5TestWidgets('a metric\'s link opens its tab\'s page', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    await ph8b2Tap(tester, find.descendant(of: find.byKey(ph8b2Metrics), matching: find.text(_en.facilities_viewReport)));
    expect(ph8b2TabPage(3), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('back from the page returns to the list', (tester) async {
    await pumpPh8b2(tester);
    await ph8b2OpenDetails(tester);
    await tester.pageBack();
    await ph8b2Settle(tester);
    expect(ph8b2Row(testFacilityId), findsOneWidget);
    expect(find.byKey(ph8b2Details), findsNothing);
  }, skip: _skip);
}
