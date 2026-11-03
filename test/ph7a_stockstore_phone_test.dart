// PH7a (docs/design/phone_list_pattern.md): Stock Store on a phone, pushed
// from More or Go to (back arrow). One menu (Stock Alerts as a sheet: the
// bell's dropdown, stockstore_screen.dart:92, never shows on a phone), Add
// Product floating for admins (today's primary action) through the guard,
// the stock chips and Filter sheet against the side panel, the summary line
// and sheet against the cards, rows with the stored quantity, value and
// expiry, and the details page from the card (Edit, Release, the batches,
// Delete).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_date_format.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/widgets/product_catalog_side_panel.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = true;

const _wide = Size(1200, 800);

Future<Ph5App> _store(WidgetTester tester, {Size size = const Size(390, 844), bool admin = true, bool locked = false}) =>
    pumpPh5(tester, (fs) => const StockStoreScreen(),
        size: size, pushed: true, admin: admin, locked: locked, seed: ph7SeedProducts);

final _names = {for (final p in ph7Products) p.id: p.name};
Set<String> _rowNames(WidgetTester tester) => {for (final id in ph5RowIds(tester)) _names[id]!};

Set<String> _tabletNames(WidgetTester tester) => {
      for (final p in ph7Products)
        if (find.descendant(of: find.byType(StockStoreScreen), matching: find.text(p.name)).evaluate().isNotEmpty) p.name,
    };

Future<void> _tapIn(WidgetTester tester, Finder within, String text) async {
  final f = find.descendant(of: within, matching: find.text(text)).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await ph5Settle(tester);
}

String _cardValue(WidgetTester tester, String label) {
  final labelText = find.descendant(of: find.byType(GridView), matching: find.text(label)).first;
  final card = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  return (ph5Texts(card)..remove(label)).single;
}

void main() {
  ph5TestWidgets('the bar: back arrow, the title, search, one menu with Stock Alerts as a sheet; Add Product floats for an admin only', (tester) async {
    await _store(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Stock Store'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(ph5FabExtended('Add Product'), isTrue);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    await tester.tap(find.text('Stock Alerts'));
    await ph5Settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);

    await _store(tester, admin: false);
    expect(ph5Key('phoneList-fab'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Add Product goes through the guard: the form, or the locked message', (tester) async {
    await _store(tester);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddEditProductScreen), findsOneWidget);

    await _store(tester, locked: true);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.text('Subscription Expired'), findsOneWidget);
    expect(find.byType(AddEditProductScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the stock chips and the Filter sheet give the side panel\'s results', (tester) async {
    for (final status in ['All Statuses', 'In Stock', 'Depleted']) {
      await _store(tester, size: _wide);
      await _tapIn(tester, find.byType(ProductCatalogSidePanel), status);
      final expected = _tabletNames(tester);
      await _store(tester);
      await _tapIn(tester, ph5Key('phoneList-quickChips'), status == 'All Statuses' ? 'All' : status);
      expect(_rowNames(tester), expected, reason: status);
    }
    await _store(tester, size: _wide);
    await _tapIn(tester, find.byType(ProductCatalogSidePanel), 'Veterinary');
    await _tapIn(tester, find.byType(ProductCatalogSidePanel), 'Feeds');
    final expected = _tabletNames(tester);
    await _store(tester);
    await ph5OpenSheet(tester, 'Filter');
    await _tapIn(tester, find.byType(BottomSheet), 'Feeds');
    await _tapIn(tester, find.byType(BottomSheet), 'Apply');
    expect(_rowNames(tester), expected);
  }, skip: _skip);

  ph5TestWidgets('"3 products, Tsh X stock value" and a Summary sheet with the five cards\' figures', (tester) async {
    await _store(tester, size: _wide);
    final cards = {
      for (final l in ['Total Products', 'In Stock', 'Low Stock', 'Depleted', 'Store Stock Value']) l: _cardValue(tester, l),
    };
    await _store(tester);
    final value = ph7Products.fold<double>(0, (t, p) => t + p.store * p.buy);
    expect(find.text('3 products, ${Money.format(value)} stock value'), findsOneWidget);
    await ph5OpenSummary(tester);
    for (final e in cards.entries) {
      expect(ph5SheetValue(tester, e.key), e.value, reason: e.key);
    }
  }, skip: _skip);

  ph5TestWidgets('rows: the name and the stored quantity, the stored value and the expiry, a status chip; no buttons', (tester) async {
    await _store(tester);
    final dairy = ph5Key('phoneList-row-p8');
    expect(find.descendant(of: dairy, matching: find.text('Dairy meal 70kg')), findsOneWidget);
    expect(find.descendant(of: dairy, matching: find.text('15 pcs')), findsOneWidget);
    expect(find.descendant(of: dairy, matching: find.text(Money.format(15 * 52000))), findsOneWidget);
    expect(find.descendant(of: dairy, matching: find.text('Expiry: ${AppDateFormat.date.format(ph7Expiry(120))}')), findsOneWidget);
    expect(find.descendant(of: dairy, matching: find.text('In Stock')), findsOneWidget);
    expect(find.descendant(of: ph5Key('phoneList-scroll'), matching: find.byType(IconButton)), findsNothing);
    expect(ph5HasDayHeaders(tester), isFalse);
  }, skip: _skip);

  ph5TestWidgets('the details page: the card\'s content; Edit, Release, the batches and Delete for an admin', (tester) async {
    await _store(tester);
    await tester.tap(ph5Key('phoneList-row-p8'));
    await ph5Settle(tester);
    expect(ph5Texts(ph5Page).contains('Sellable: 0 pcs • Batch: BN-001'), isTrue);
    for (final action in ['Release', 'Add New Batch', 'View Batches']) {
      expect(find.descendant(of: ph5Page, matching: find.text(action)), findsOneWidget, reason: action);
    }
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsOneWidget);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')), findsOneWidget);
    await tester.tap(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')));
    await ph5Settle(tester);
    expect(find.text('Confirm Delete'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('an assistant\'s page: the batches only (no Edit, Release or Delete, as today\'s card)', (tester) async {
    await _store(tester, admin: false);
    await tester.tap(ph5Key('phoneList-row-p8'));
    await ph5Settle(tester);
    expect(find.descendant(of: ph5Page, matching: find.text('Add New Batch')), findsOneWidget);
    for (final gone in ['Release']) {
      expect(find.descendant(of: ph5Page, matching: find.text(gone)), findsNothing);
    }
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsNothing);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')), findsNothing);
  }, skip: _skip);
}
