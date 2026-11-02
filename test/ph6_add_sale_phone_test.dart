// PH6 Add Sale on a phone: Browse Products is a tall bottom sheet (search
// at the top, a row a product with its stock and price and a 48 px add
// button or stepper, the cart's count and total pinned), still today's
// dialog on a computer; the item rows fit 360 with a long name and an
// 8-digit price, their controls 48 px; the client is chosen in a sheet;
// the items and total are pinned above the action bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = true;

Finder _rowOf(String name) => find.ancestor(of: find.text(name).last, matching: find.byType(Row)).first;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await ph5Settle(tester);
}

Future<void> _add(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(of: _rowOf(name), matching: find.byIcon(Icons.add_circle)).last);
  await ph5Settle(tester);
}

void main() {
  ph5TestWidgets('Browse Products: a tall sheet, search on top, 48 px add buttons, the cart pinned', (tester) async {
    final app = await pumpPh6(tester, 'add-sale');
    await ph6LoadSaleProducts(tester, app);
    await _tap(tester, find.text('Browse Products').first);
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, greaterThan(844 * 0.8));
    final search = find.descendant(of: sheet, matching: find.byType(TextField)).first;
    expect(tester.getTopLeft(search).dy, lessThan(tester.getTopLeft(find.text('Albendazole 10%').last).dy));
    final add = find.descendant(of: _rowOf('Albendazole 10%'), matching: find.byIcon(Icons.add_circle)).last;
    final button = find.ancestor(of: add, matching: find.byType(IconButton)).first;
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await _add(tester, 'Albendazole 10%');
    await _add(tester, 'Albendazole 10%');
    expect(find.descendant(of: ph5Key('browseProducts-cart'), matching: find.text('2 items, ${Money.format(30000)}')), findsOneWidget);
    await tester.enterText(search, 'vit');
    await ph5Settle(tester);
    expect(find.text('Ivermectin 1%'), findsNothing);
    expect(find.text('Vitamin B12'), findsWidgets);
  }, skip: _skip);

  ph5TestWidgets('Browse Products is still today\'s dialog on a computer', (tester) async {
    final app = await pumpPh6(tester, 'add-sale', size: const Size(1200, 800));
    await ph6LoadSaleProducts(tester, app);
    await _tap(tester, find.text('Browse Products').first);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Filter by name, batch no or category...'), findsOneWidget);
  }, skip: _skip);

  for (final size in const [Size(360, 740), Size(390, 844)]) {
    ph5TestWidgets('${size.width.toInt()}: item rows fit a long name and an 8-digit price; 48 px steppers', (tester) async {
      final app = await pumpPh6(tester, 'add-sale', size: size);
      await ph6LoadSaleProducts(tester, app, longName: true);
      await _tap(tester, find.text('Browse Products').first);
      await _add(tester, matrixLongProductName);
      await _add(tester, matrixLongProductName);
      await _add(tester, 'Vitamin B12');
      await tester.binding.handlePopRoute();
      await ph5Settle(tester);
      expect(tester.takeException(), isNull);
      final plus = find.byKey(const ValueKey('saleItem-plus-0'));
      expect(tester.getSize(plus).height, greaterThanOrEqualTo(48));
      await _tap(tester, plus);
      expect(find.descendant(of: find.byKey(const ValueKey('saleItem-0')), matching: find.text('3')), findsOneWidget);
      await checkCase(tester, phone: true, where: 'add-sale items $size');
    }, skip: _skip);
  }

  ph5TestWidgets('the items and the total are pinned above the action bar', (tester) async {
    final app = await pumpPh6(tester, 'add-sale');
    await ph6LoadSaleProducts(tester, app);
    await _tap(tester, find.text('Browse Products').first);
    for (final name in ['Albendazole 10%', 'Albendazole 10%', 'Ivermectin 1%', 'Vitamin B12']) {
      await _add(tester, name);
    }
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.descendant(of: ph5Key('formActionBar'), matching: find.text('4 items, ${Money.format(42500)}')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the client is chosen in a sheet: search, a row, the sale is theirs', (tester) async {
    await pumpPh6(tester, 'add-sale');
    await _tap(tester, find.text('Search or select client...').first);
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    await tester.enterText(find.descendant(of: sheet, matching: find.byType(TextField)).first, 'Amina');
    await tester.pump(const Duration(seconds: 1));
    await ph5Settle(tester);
    final row = find.descendant(of: sheet, matching: find.text('Amina Juma'));
    expect(tester.getSize(find.ancestor(of: row, matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(56));
    await tester.tap(row);
    await ph5Settle(tester);
    expect(sheet, findsNothing);
    expect(find.text('Amina Juma'), findsWidgets);
  }, skip: _skip);
}
