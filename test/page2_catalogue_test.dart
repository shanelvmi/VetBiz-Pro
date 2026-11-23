// PAGE2: one shared products catalogue a session. ProductProvider holds one
// listener per selected facility (facility activation starts it on every
// device now); Products, Stock Store, Stock Alerts and Add Sale read from it,
// so opening them one after another opens no second listener and reads no
// product again (only changed products, as deltas). It is released when the
// facility changes or the person signs out (ProductProvider.clear; the
// activation side is ph4b_live_attention_test). On PC/tablet Products and
// Stock Store page it with ListPageBar (10/25/50, default 25) and search it
// in memory 300 ms after typing stops.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _wide = Size(1600, 900);

/// [count] in-stock products "Product 000".. (on the shelf and in the store).
List<Ph7Product> _many(int count) => [
      for (var i = 0; i < count; i++)
        Ph7Product('m${i.toString().padLeft(3, '0')}', 'Product ${i.toString().padLeft(3, '0')}', shelf: 50, store: 10),
    ];

Future<(CountingFirestore, Ph5App)> _openProducts(WidgetTester tester,
    {List<Ph7Product>? products, Size size = _wide, MatrixLook look = MatrixLook.light, double textScale = 1}) async {
  final db = CountingFirestore();
  await tester.runAsync(() => ph7SeedProducts(db.inner, products));
  final app = await pumpPh5(tester, (fs) => ProductsScreen(firestore: fs),
      size: size, pushed: true, firestore: db, look: look, textScale: textScale);
  return (db, app);
}

Future<void> _push(WidgetTester tester, Ph5App app, Widget screen) async {
  app.navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen));
  await ph5Settle(tester);
}

Future<void> _search(WidgetTester tester, Type screen, String text) async {
  await tester.enterText(find.descendant(of: find.byType(screen), matching: find.byType(TextField)).first, text);
  await tester.pump(const Duration(milliseconds: 350));
  await ph5Settle(tester);
}

void main() {
  ph5TestWidgets('Products, Stock Store, Stock Alerts and Add Sale in one session: one listener, no second read',
      (tester) async {
    final (db, app) = await _openProducts(tester);
    final listenersAfterProducts = db.listeners;
    final opened = db.listens;
    final productCount = ph7Products.length;
    expect(db.reads, lessThanOrEqualTo(productCount + 2), reason: 'the products once, plus the app\'s setup');

    db.resetCounts();
    await _push(tester, app, const StockStoreScreen());
    expect(find.byType(StockStoreScreen), findsOneWidget);
    expect(db.reads, 0, reason: 'Stock Store reads the shared catalogue');
    expect(db.listeners, listenersAfterProducts);

    await _push(tester, app, const StockAlertsScreen());
    expect(db.reads, 0, reason: 'Stock Alerts reads the shared catalogue');
    expect(db.listeners, listenersAfterProducts);

    await _push(tester, app, AddSaleScreen(firestore: app.fs));
    // ignore: avoid_print
    print('PAGE2 catalogue: Add Sale open (listeners, listens, gets, reads): '
        '(${db.listeners}, ${db.listens}, ${db.gets}, ${db.reads})');
    expect(db.listens, 0, reason: 'no screen opened a listener of its own (one was opened before: $opened)');
    expect(db.listeners, listenersAfterProducts);

    // A delta: one changed product is one read, every screen sees it.
    db.resetCounts();
    await tester.runAsync(() => facilityCollection(db.inner, Collections.products).doc('p1').update({'sellableQty': 39}));
    await ph5Settle(tester);
    expect(db.reads, 1);
  });

  test('one listener per facility; clear releases it; the next facility gets its own', () async {
    final db = CountingFirestore();
    await ph7SeedProducts(db.inner);
    final provider = ProductProvider(firestore: db, currentUserInfo: testUserInfo, isAdmin: () => true);
    provider.listenToProducts(testFacilityId);
    provider.listenToProducts(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(db.listeners, 1);
    expect(db.reads, ph7Products.length);
    provider.clear();
    expect(db.listeners, 0);
    expect(provider.products, isEmpty);
    provider.listenToProducts('facility2');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(db.listeners, 1);
    provider.dispose();
  });

  test('Stock Alerts numbers from the shared catalogue match a one-time read of the same products', () async {
    final db = CountingFirestore();
    await ph7SeedProducts(db.inner);
    final live = ProductProvider(firestore: db, currentUserInfo: testUserInfo, isAdmin: () => true)
      ..listenToProducts(testFacilityId);
    final once = ProductProvider(firestore: db, currentUserInfo: testUserInfo, isAdmin: () => true);
    await once.fetchProducts(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    Map<StockAlertKind, int> counts(List<dynamic> alerts) {
      final out = <StockAlertKind, int>{};
      for (final a in alerts.cast<StockAlert>()) {
        out[a.kind] = (out[a.kind] ?? 0) + 1;
      }
      return out;
    }

    final shared = counts(StockAlertsScreen.currentAlerts(live.products));
    expect(shared, counts(StockAlertsScreen.currentAlerts(once.products)));
    expect(shared[StockAlertKind.lowStock], isNotNull, reason: 'the seed has low-stock products');
    live.dispose();
    once.dispose();
  });

  // Through Browse Products (the phone sheet), as ph6_add_sale_phone_test does:
  // the inline suggestion list on a wide Add Sale trips Flutter's ListTile
  // "background may be invisible" debug assertion before PAGE2 too (noted in
  // docs/design-open-questions.md), so the wide tests stay off it.
  ph5TestWidgets('Add Sale: the product search is still instant, from memory', (tester) async {
    final (db, app) = await _openProducts(tester, size: const Size(390, 844));
    await _push(tester, app, AddSaleScreen(firestore: app.fs));
    await tester.tap(find.text('Browse Products').first);
    await ph5Settle(tester);
    db.resetCounts();
    final sheet = find.byType(BottomSheet);
    await tester.enterText(find.descendant(of: sheet, matching: find.byType(TextField)).first, 'vit');
    await tester.pump();
    expect(find.text('Vitamin B12'), findsWidgets);
    expect(find.text('Ivermectin 1%'), findsNothing);
    expect(db.reads, 0);
    expect(db.gets, 0);
  });

  ph5TestWidgets('Products PC/tablet: ListPageBar, 25 a page, Next and Previous over the catalogue', (tester) async {
    final (db, _) = await _openProducts(tester, products: _many(60));
    expect(page1Range(tester), 'Showing 1 to 25 of 60 products');
    db.resetCounts();
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 26 to 50 of 60 products');
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 51 to 60 of 60 products');
    expect(page1NextEnabled(tester), isFalse);
    await page1Previous(tester);
    expect(page1Range(tester), 'Showing 26 to 50 of 60 products');
    await page1PageSize(tester, 10);
    expect(page1Range(tester), 'Showing 1 to 10 of 60 products');
    expect(db.reads, 0, reason: 'paging is in memory');
  });

  ph5TestWidgets('Products search: waits for the typing to stop, names the text when nothing matches, Escape clears',
      (tester) async {
    await _openProducts(tester, products: _many(60));
    final field = find.descendant(of: find.byType(ProductsScreen), matching: find.byType(TextField)).first;
    await tester.enterText(field, 'Product 05');
    await tester.pump(const Duration(milliseconds: 100));
    expect(page1Range(tester), 'Showing 1 to 25 of 60 products', reason: 'not yet: 300 ms after the typing stops');
    await tester.pump(const Duration(milliseconds: 300));
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 10 of 10 products');
    await _search(tester, ProductsScreen, 'zebra');
    expect(find.text('No products match "zebra"'), findsOneWidget);
    await tester.showKeyboard(field);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25 of 60 products');
  });

  ph5TestWidgets('Stock Store PC/tablet: ListPageBar and the same search', (tester) async {
    final (_, app) = await _openProducts(tester, products: _many(30));
    await _push(tester, app, const StockStoreScreen());
    expect(page1Range(tester), 'Showing 1 to 25 of 30 products');
    await _search(tester, StockStoreScreen, 'Product 02');
    expect(page1Range(tester), 'Showing 1 to 10 of 10 products');
    await _search(tester, StockStoreScreen, 'zebra');
    expect(find.text('No products match "zebra"'), findsOneWidget);
  });

  test('the soft guard: above 5000 products it warns once a session', () async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = previous);
    final db = CountingFirestore();
    final products = facilityCollection(db.inner, Collections.products);
    for (var i = 0; i < 5001; i++) {
      await products.doc('x$i').set({'name': 'X $i', 'sellableQty': 1, 'stockQty': 0});
    }
    final provider = ProductProvider(firestore: db, currentUserInfo: testUserInfo, isAdmin: () => true)
      ..listenToProducts(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await products.doc('x0').update({'sellableQty': 2});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(logs.where((l) => l.contains('soft limit')).length, 1);
    provider.dispose();
  });

  for (final size in page1Widths) {
    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('${size.width.toInt()} ${look.name} text $scale: Products and Stock Store pages, no overflow',
          (tester) async {
        final (_, app) = await _openProducts(tester, products: _many(30), size: size, look: look, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(page1BarWidget(tester).itemCount, 25);
        await _push(tester, app, const StockStoreScreen());
        expect(tester.takeException(), isNull);
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
