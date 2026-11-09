// HUB1 (3): with the bar's "+" gone, Sales on a phone has its own Record
// Sale button (PH5a R2, as Services): extended at rest, its icon only while
// the list scrolls down, gone while the keyboard is open, through the
// locked-facility guard, never over the last row; and a back arrow (Sales is
// a pushed screen now, never a tab).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/widgets/phone_list/collapsing_fab.dart';

import 'helpers/phone_list_harness.dart';

const _skip = false;

Finder _key(String k) => find.byKey(ValueKey(k));

Finder get _list => find.descendant(of: _key('phoneList-scroll'), matching: find.byType(Scrollable)).first;

final _many = [
  for (var i = 0; i < 24; i++) Ph5Sale('m$i', ph5When(i ~/ 4, minutes: i), client: 'Client $i', amount: 1000.0 + i, paid: 0, receipt: i + 1),
];

Future<Ph5App> _sales(WidgetTester tester, {bool locked = false, List<Ph5Sale>? sales}) => pumpPh5(
      tester,
      (fs) => SalesScreen(firestore: fs),
      pushed: true,
      locked: locked,
      seed: (fs) => ph5SeedSales(fs, sales ?? _many.take(3).toList()),
    );

bool _extended(WidgetTester tester) => tester.widget<CollapsingFab>(_key('phoneList-fab')).extended;

void main() {
  ph5TestWidgets('Record Sale at the bottom right, extended, under a back arrow', (tester) async {
    await _sales(tester);
    expect(find.byType(BackButton), findsOneWidget);
    final fab = _key('phoneList-fab');
    expect(fab, findsOneWidget);
    expect(find.descendant(of: fab, matching: find.text('Record Sale')), findsOneWidget);
    expect(_extended(tester), isTrue);
    expect(tester.getCenter(fab).dx, greaterThan(390 / 2));
  }, skip: _skip);

  ph5TestWidgets('its icon only while scrolling down, extended again scrolling up', (tester) async {
    await _sales(tester, sales: _many);
    await tester.drag(_list, const Offset(0, -300));
    await ph5Settle(tester);
    expect(_extended(tester), isFalse);
    await tester.drag(_list, const Offset(0, 150));
    await ph5Settle(tester);
    expect(_extended(tester), isTrue);
  }, skip: _skip);

  ph5TestWidgets('the last row is never under the button', (tester) async {
    await _sales(tester, sales: _many);
    for (var i = 0; i < 3; i++) {
      await tester.drag(_list, const Offset(0, -3000));
      await ph5Settle(tester);
    }
    final lastRow = tester.getRect(_key('phoneList-row-m23'));
    expect(lastRow.bottom, lessThanOrEqualTo(tester.getRect(_key('phoneList-fab')).top));
  }, skip: _skip);

  ph5TestWidgets('hidden while the keyboard is open', (tester) async {
    await _sales(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_key('phoneList-fab'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('locked: the guard holds and no form opens', (tester) async {
    await _sales(tester, locked: true);
    await tester.tap(_key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddSaleScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('unlocked: the form opens', (tester) async {
    await _sales(tester);
    await tester.tap(_key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddSaleScreen), findsOneWidget);
    while (tester.takeException() != null) {}
  }, skip: _skip);
}
