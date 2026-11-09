// PH7a (docs/design/phone_list_pattern.md): Products on a phone, the Products
// tab (no back arrow). The title and one overflow menu (R1), Add Product
// floating for admins only, through the guard (R2), the stock chips and the
// Filter sheet against the tablet's side panel and sort (R3), "N products,
// Tsh X stock value" and a Summary sheet with the five cards (R4), name
// order with no day headers (R5), rows with the photo (R6), the details page
// from the card's content and actions (R7), pull to refresh (R8), the states
// (R9) and paging (R10).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/widgets/product_catalog_side_panel.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

// Tall, so every card of the tablet's lazy grid is built.
const _wide = Size(1200, 2400);

Future<Ph5App> _products(WidgetTester tester,
        {Size size = const Size(390, 844),
        List<Ph7Product>? products,
        bool admin = true,
        bool locked = false,
        CountingFirestore? firestore,
        bool settle = true}) =>
    pumpPh5(tester, (fs) => ProductsScreen(firestore: fs),
        size: size,
        pushed: size.width >= 600,
        admin: admin,
        locked: locked,
        firestore: firestore,
        settle: settle,
        seed: (fs) => ph7SeedProducts(fs, products));

final _names = {for (final p in ph7Products) p.id: p.name};
Set<String> _rowNames(WidgetTester tester) => {for (final id in ph5RowIds(tester)) _names[id]!};

/// The products the tablet shows now (grid or list).
Set<String> _tabletNames(WidgetTester tester) => {
      for (final p in ph7Products)
        if (find.descendant(of: find.byType(ProductsScreen), matching: find.text(p.name)).evaluate().isNotEmpty) p.name,
    };

Future<void> _tapIn(WidgetTester tester, Finder within, String text) async {
  final f = find.descendant(of: within, matching: find.text(text)).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await ph5Settle(tester);
}

/// A tablet metric card's value beside its label.
String _cardValue(WidgetTester tester, String label) {
  final labelText = find.descendant(of: find.byType(GridView), matching: find.text(label)).first;
  final card = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  return (ph5Texts(card)..remove(label)).single;
}

void main() {
  ph5TestWidgets('the tab\'s bar: no back arrow, the title, search, one menu (Stock Alerts, smart defaults); no Refresh, no Add Product in the bar', (tester) async {
    await _products(tester);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Sellable Products'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    expect(find.text('Stock Alerts'), findsOneWidget);
    expect(find.text('Recalculate smart defaults from usage history'), findsOneWidget);
    await tester.tap(find.text('Stock Alerts'));
    await ph5Settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'the bell\'s alerts open as a sheet');
  }, skip: _skip);

  ph5TestWidgets('Add Product floats for an admin and opens the form; an assistant has none (and no smart defaults)', (tester) async {
    await _products(tester);
    expect(ph5FabExtended('Add Product'), isTrue);
    expect(find.text('Add Product'), findsOneWidget, reason: 'only the floating button');
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.byType(AddEditProductScreen), findsOneWidget);
    // The form's own phone layout is ph7a_product_form_phone_test.dart's.
    while (tester.takeException() != null) {}

    await _products(tester, admin: false);
    expect(ph5Key('phoneList-fab'), findsNothing);
    await tester.tap(find.byTooltip('Show menu'));
    await ph5Settle(tester);
    expect(find.text('Recalculate smart defaults from usage history'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('locked: the floating Add Product shows the locked message and no form', (tester) async {
    await _products(tester, locked: true);
    await tester.tap(ph5Key('phoneList-fab'));
    await ph5Settle(tester);
    expect(find.text('Subscription Expired'), findsOneWidget);
    expect(find.byType(AddEditProductScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('the stock chips give the side panel\'s results', (tester) async {
    for (final status in ['All Statuses', 'In Stock', 'Low Stock', 'Reorder Soon', 'Depleted', 'Expired']) {
      await _products(tester, size: _wide);
      await _tapIn(tester, find.byType(ProductCatalogSidePanel), status);
      final expected = _tabletNames(tester);
      await _products(tester);
      await _tapIn(tester, ph5Key('phoneList-quickChips'), status == 'All Statuses' ? 'All' : status);
      expect(_rowNames(tester), expected, reason: status);
    }
  }, skip: _skip);

  ph5TestWidgets('the Filter sheet (category, sort) gives the side panel\'s and the sort\'s results; applied filters are removable chips', (tester) async {
    await _products(tester, size: _wide);
    await _tapIn(tester, find.byType(ProductCatalogSidePanel), 'Veterinary');
    await _tapIn(tester, find.byType(ProductCatalogSidePanel), 'Antibiotic');
    final expected = _tabletNames(tester);
    await _products(tester);
    await ph5OpenSheet(tester, 'Filter');
    await _tapIn(tester, find.byType(BottomSheet), 'Antibiotic');
    await _tapIn(tester, find.byType(BottomSheet), 'Price (High-Low)');
    await _tapIn(tester, find.byType(BottomSheet), 'Apply');
    expect(_rowNames(tester), expected);
    expect(ph5Key('phoneList-filterDot'), findsOneWidget);
    // Highest price first: Oxytetracycline (12,000) before Penstrep (9,000).
    final y = [for (final id in ['p4', 'p5']) tester.getTopLeft(ph5Key('phoneList-row-$id')).dy];
    expect(y[0] < y[1], isTrue);
    expect(find.text('Category: Antibiotic'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').first);
    await ph5Settle(tester);
    expect(find.text('Category: Antibiotic'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('"7 products, Tsh X stock value" and a Summary sheet with the five cards\' figures', (tester) async {
    await _products(tester, size: _wide);
    final cards = {
      for (final l in ['Total Products', 'In Stock', 'Low Stock', 'Depleted', 'Shelf Stock Value']) l: _cardValue(tester, l),
    };
    await _products(tester);
    final value = ph7Products.fold<double>(0, (t, p) => t + p.shelf * p.buy);
    expect(find.text('7 products, ${Money.format(value)} stock value'), findsOneWidget);
    await ph5OpenSummary(tester);
    for (final e in cards.entries) {
      expect(ph5SheetValue(tester, e.key), e.value, reason: e.key);
    }
  }, skip: _skip);

  ph5TestWidgets('rows: the photo (or a stand-in), the name and the sellable quantity, the price and a status chip; name order; no buttons, no day headers', (tester) async {
    await _products(tester);
    expect(ph5HasDayHeaders(tester), isFalse);
    final albendazole = ph5Key('phoneList-row-p1');
    expect(find.descendant(of: albendazole, matching: ph5Key('productLeading-p1')), findsOneWidget);
    expect(find.descendant(of: ph5Key('phoneList-row-p3'), matching: find.text('VB')), findsOneWidget, reason: 'no photo: initials');
    expect(find.descendant(of: albendazole, matching: find.text('Albendazole 10%')), findsOneWidget);
    expect(find.descendant(of: albendazole, matching: find.text('40 pcs')), findsOneWidget);
    expect(find.descendant(of: albendazole, matching: find.text(Money.unitPrice(15000))), findsOneWidget);
    expect(find.descendant(of: albendazole, matching: find.text('In Stock')), findsOneWidget);
    for (final (id, chip) in [('p2', 'Low Stock'), ('p3', 'Reorder Soon'), ('p4', 'Expiring Soon'), ('p5', 'Expired'), ('p6', 'Depleted')]) {
      expect(find.descendant(of: ph5Key('phoneList-row-$id'), matching: find.text(chip)), findsOneWidget, reason: id);
    }
    for (final id in ph5RowIds(tester)) {
      expect(find.descendant(of: ph5Key('phoneList-row-$id'), matching: find.byType(IconButton)), findsNothing);
    }
    final y = [for (final id in ['p1', 'p2', 'p6']) tester.getTopLeft(ph5Key('phoneList-row-$id')).dy];
    expect(y[0] < y[1] && y[1] < y[2], isTrue, reason: 'Albendazole, Ivermectin, Newcastle');
  }, skip: _skip);

  ph5TestWidgets('search filters by name, brand or batch, and Close clears it', (tester) async {
    await _products(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.enterText(ph5Key('phoneList-searchField'), 'iver');
    await ph5Settle(tester);
    expect(ph5RowIds(tester), {'p2'});
    await tester.tap(find.byTooltip('Close'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(7));
  }, skip: _skip);

  ph5TestWidgets('the details page: the card\'s content and its actions; Delete asks, closes, offers Undo', (tester) async {
    final app = await _products(tester);
    await tester.tap(ph5Key('phoneList-row-p1'));
    await ph5Settle(tester);
    final page = ph5Texts(ph5Page);
    for (final t in [
      'Albendazole 10%',
      'For cattle, goats and sheep',
      'Stock: 0 pcs • Batch: BN-001',
      'Buy: ${Money.unitPrice(9000)}',
      'Watch-listed for daily reports',
    ]) {
      expect(page.contains(t), isTrue, reason: t);
    }
    for (final action in ['Sell', 'Add New Batch', 'View Batches', 'Remove from Watchlist']) {
      expect(find.descendant(of: ph5Page, matching: find.text(action)), findsOneWidget, reason: action);
    }
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsOneWidget);
    await tester.tap(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')));
    await ph5Settle(tester);
    expect(find.text('Confirm Delete'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await ph5Settle(tester);
    expect(ph5Page, findsNothing, reason: 'the page closes');
    expect(find.text('Undo'), findsOneWidget);
    expect(ph5RowIds(tester).contains('p1'), isFalse);
    expect(app.fs, isNotNull);
  }, skip: _skip);

  ph5TestWidgets('an assistant\'s page: Sell and the batches; no Edit (admin-only, PH7b), no Delete, no watchlist', (tester) async {
    await _products(tester, admin: false);
    await tester.tap(ph5Key('phoneList-row-p1'));
    await ph5Settle(tester);
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Edit')), findsNothing, reason: 'Edit Product is admin-only (PH7b)');
    expect(find.descendant(of: ph5Page, matching: find.byTooltip('Delete')), findsNothing);
    expect(find.descendant(of: ph5Page, matching: find.text('Remove from Watchlist')), findsNothing);
    expect(find.descendant(of: ph5Page, matching: find.text('Add New Batch')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('pull to refresh runs today\'s refresh (one get of the products)', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() => ph7SeedProducts(db.inner));
    await _products(tester, firestore: db);
    db.resetCounts();
    await ph5Pull(tester);
    expect(db.gets, 1);
  }, skip: _skip);

  ph5TestWidgets('paging: 12 rows, the next 12 near the end; Load more is the fallback', (tester) async {
    final many = [for (var i = 0; i < 30; i++) Ph7Product('m${i.toString().padLeft(2, '0')}', 'Product ${i.toString().padLeft(2, '0')}')];
    // Tall enough to build every row reached.
    await _products(tester, products: many, size: const Size(390, 2000));
    expect(ph5RowIds(tester), hasLength(12));
    await tester.fling(ph5List, const Offset(0, -3000), 3000);
    await ph5Settle(tester);
    expect(ph5RowIds(tester).length, greaterThan(12));
  }, skip: _skip);

  ph5TestWidgets('states: six skeleton rows, then the rows; empty with Add Product (admin only); error with Retry', (tester) async {
    final held = CountingFirestore()..holdListens = Completer<void>();
    await tester.runAsync(() => ph7SeedProducts(held.inner));
    await _products(tester, firestore: held, settle: false);
    await tester.pump();
    expect(find.descendant(of: ph5Key('phoneList-skeleton'), matching: ph5SkeletonRows), findsNWidgets(6));
    held.holdListens!.complete();
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(7));

    await _products(tester, products: const []);
    final empty = ph5Key('phoneList-empty');
    expect(find.descendant(of: empty, matching: find.text('No sellable products')), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Add Product')), findsOneWidget);
    await _products(tester, products: const [], admin: false);
    expect(find.descendant(of: ph5Key('phoneList-empty'), matching: find.text('Add Product')), findsNothing);

    final failing = CountingFirestore()..failListens = true;
    await tester.runAsync(() => ph7SeedProducts(failing.inner));
    await _products(tester, firestore: failing);
    expect(ph5Key('phoneList-error'), findsOneWidget);
    failing.failListens = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(7));
  }, skip: _skip);
}
