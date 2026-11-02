// PH5a (docs/design/phone_list_pattern.md R7, R11): on a phone a row opens a
// full details page with the content and actions of today's details panel;
// an admin deletes from it (today's confirmation, then Undo), an assistant
// sees no Delete or Edit; Back returns to the same place in the list; each
// row reads naturally to a screen reader.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

const _phone = Size(390, 844);
const _wide = Size(1200, 800);

Finder _key(String k) => find.byKey(ValueKey(k));
Finder get _list => find.descendant(of: _key('phoneList-scroll'), matching: find.byType(Scrollable)).first;

final _sale = Ph5Sale('s1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 45000, paid: 20000, receipt: 1);
final _service = Ph5Service('v1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 30000, paid: 10000, category: 'Surgical', receipt: 1);

Future<void> _seed(dynamic fs) async {
  await seedProduct(fs, id: 'p1', legacyQty: 10);
  await ph5SeedSales(fs, [_sale, for (var i = 2; i <= 30; i++) Ph5Sale('s$i', ph5When(1 + i ~/ 5, minutes: i), amount: 1000, receipt: i)]);
  await ph5SeedServices(fs, [_service]);
}

Set<String> _texts(Finder root) => {
      for (final e in find.descendant(of: root, matching: find.byType(Text)).evaluate())
        if ((e.widget as Text).data != null) (e.widget as Text).data!,
    };

void main() {
  final screens = {
    'Sales': ((dynamic fs) => SalesScreen(firestore: fs), 'SL-000001', 'Sale Details', 's1'),
    'Services': ((dynamic fs) => ServicesScreen(firestore: fs), 'Surgical visit', 'Service Details', 'v1'),
  };

  for (final e in screens.entries) {
    final (build, wideRow, title, id) = e.value;

    ph5TestWidgets('${e.key}: the page shows the panel\'s content and actions', (tester) async {
      await pumpPh5(tester, (fs) => build(fs), size: _wide, pushed: true, seed: _seed);
      await tester.tap(find.text(wideRow).first);
      await ph5Settle(tester);
      // Today's wide panel overflows with these names (recorded in the wide
      // fingerprints); only its texts matter here.
      while (tester.takeException() != null) {}
      final panel = _texts(find.ancestor(of: find.text(title), matching: find.byType(SingleChildScrollView)).first);

      await pumpPh5(tester, (fs) => build(fs), size: _phone, pushed: true, seed: _seed);
      await tester.tap(_key('phoneList-row-$id'));
      await ph5Settle(tester);
      final page = _key('phoneList-details');
      expect(page, findsOneWidget);
      expect(find.descendant(of: page, matching: find.byType(BackButton)), findsOneWidget);
      expect(_texts(page), panel);
      for (final action in ['Print', 'Delete']) {
        expect(find.descendant(of: page, matching: find.text(action)), findsOneWidget, reason: action);
      }
    }, skip: _skip);

    ph5TestWidgets('${e.key}: an assistant\'s page has no Delete (nor Edit)', (tester) async {
      await pumpPh5(tester, (fs) => build(fs), admin: false, pushed: true, seed: _seed);
      await tester.tap(_key('phoneList-row-$id'));
      await ph5Settle(tester);
      final page = _key('phoneList-details');
      expect(find.descendant(of: page, matching: find.text('Print')), findsOneWidget);
      expect(find.descendant(of: page, matching: find.text('Delete')), findsNothing);
      expect(find.descendant(of: page, matching: find.text('Edit')), findsNothing);
    }, skip: _skip);

    ph5TestWidgets('${e.key}: delete asks first, closes the page, and Undo brings the record back', (tester) async {
      await pumpPh5(tester, (fs) => build(fs), pushed: true, seed: _seed);
      await tester.tap(_key('phoneList-row-$id'));
      await ph5Settle(tester);
      await tester.tap(find.descendant(of: _key('phoneList-details'), matching: find.text('Delete')));
      await ph5Settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await ph5Settle(tester);
      expect(_key('phoneList-details'), findsNothing);
      expect(_key('phoneList-row-$id'), findsNothing);
      await tester.tap(find.text('Undo'));
      await ph5Settle(tester);
      await ph5Settle(tester);
      expect(_key('phoneList-row-$id'), findsOneWidget);
    }, skip: _skip);
  }

  ph5TestWidgets('Back returns to the same place in the list', (tester) async {
    await pumpPh5(tester, (fs) => SalesScreen(firestore: fs, asTab: true), seed: _seed);
    await tester.drag(_list, const Offset(0, -600));
    await ph5Settle(tester);
    final before = tester.state<ScrollableState>(_list).position.pixels;
    expect(before, greaterThan(0));
    final visible = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-row-') && w is! SliverList);
    await tester.tap(visible.hitTestable().first);
    await ph5Settle(tester);
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    expect(tester.state<ScrollableState>(_list).position.pixels, before);
  }, skip: _skip);

  ph5TestWidgets('a row reads "client, amount, status, date and time"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPh5(tester, (fs) => SalesScreen(firestore: fs, asTab: true), seed: _seed);
    final when = DateFormat('d MMM HH:mm').format(_sale.when);
    expect(find.bySemanticsLabel('Amina Juma, ${Money.format(45000)}, Partial, $when'), findsOneWidget);
    semantics.dispose();
  }, skip: _skip);
}
