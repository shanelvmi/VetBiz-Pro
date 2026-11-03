// PH7a: tablets and computers keep today's Products, Stock Store, Stock
// alerts, the batches screens and the product form exactly. At 768x1024,
// 1024x768 and 1200x800 the whole widget tree of each is compared with the
// fingerprint recorded from the code before PH7a
// (test/fixtures/ph5a_wide_fingerprints.json, the ph7a- names): the lists in
// both views and their bell's alerts, View Batches and its two dialogs, Add
// Batch, Add Product and Edit Product.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, root.first)}');

/// The long-named product, as the lists hand it to the batches screens and
/// the form (one batch on file, in both the store and on the shelf).
final ph7LongProduct = Product(
  id: 'p7',
  name: ph7Products[6].name,
  buyPrice: ph7Products[6].buy,
  sellPrice: ph7Products[6].sell,
  stockQty: ph7Products[6].store,
  sellableQty: ph7Products[6].shelf,
  unit: 'pcs',
  type: ph7Products[6].type,
  category: ph7Products[6].category,
  facilityId: testFacilityId,
  batchNo: ph7Products[6].batchNo,
  expiry: ph7Expiry(ph7Products[6].expiryDays!),
  hasEverHadStock: true,
);

/// Starts the live products listener, as Products does when it opens.
class Ph7Listening extends StatefulWidget {
  final Widget child;
  const Ph7Listening({super.key, required this.child});

  @override
  State<Ph7Listening> createState() => _Ph7ListeningState();
}

class _Ph7ListeningState extends State<Ph7Listening> {
  @override
  void initState() {
    super.initState();
    Provider.of<ProductProvider>(context, listen: false).listenToProducts(testFacilityId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    final modal = size.width >= 900;

    for (final (name, build, type) in [
      ('products', (dynamic fs) => ProductsScreen(firestore: fs) as Widget, ProductsScreen),
      ('stockstore', (dynamic fs) => const StockStoreScreen() as Widget, StockStoreScreen),
    ]) {
      ph5TestWidgets('ph7a-$name-$at: the grid, the list view and the bell as before PH7a', (tester) async {
        await pumpPh5(tester, build, size: size, pushed: true, seed: ph7SeedProducts);
        _expect(tester, 'ph7a-$name-$at-grid', find.byType(type));
        await tester.tap(find.byIcon(Icons.view_list_rounded));
        await ph5Settle(tester);
        _expect(tester, 'ph7a-$name-$at-list', find.byType(type));
        await tester.tap(find.byTooltip('Stock Alerts'));
        await ph5Settle(tester);
        _expect(tester, 'ph7a-$name-$at-bell', find.byType(StockAlertsScreen));
      }, skip: _skip);
    }

    ph5TestWidgets('ph7a-stock-alerts-$at: the page as before PH7a', (tester) async {
      await pumpPh5(tester, (fs) => const Ph7Listening(child: StockAlertsScreen()),
          size: size, pushed: true, seed: ph7SeedProducts);
      _expect(tester, 'ph7a-stock-alerts-$at', find.byType(StockAlertsScreen));
    }, skip: _skip);

    ph5TestWidgets('ph7a-view-batches-$at: the batches and the adjust and delete dialogs as before PH7a', (tester) async {
      await pumpPh5(tester, (fs) => ViewBatchesScreen(product: ph7LongProduct, isModal: modal),
          size: size, seed: ph7SeedProducts);
      _expect(tester, 'ph7a-view-batches-$at', find.byType(ViewBatchesScreen));
      await tester.tap(find.byTooltip('Adjust quantity'));
      await ph5Settle(tester);
      _expect(tester, 'ph7a-view-batches-$at-adjust', find.byType(AlertDialog));
      await tester.tap(find.text('Cancel'));
      await ph5Settle(tester);
      await tester.tap(find.byTooltip('Delete batch'));
      await ph5Settle(tester);
      _expect(tester, 'ph7a-view-batches-$at-delete', find.byType(AlertDialog));
    }, skip: _skip);

    ph5TestWidgets('ph7a-add-batch-$at: the form as before PH7a', (tester) async {
      await pumpPh5(tester, (fs) => AddBatchScreen(product: ph7LongProduct, isModal: modal), size: size);
      _expect(tester, 'ph7a-add-batch-$at', find.byType(AddBatchScreen));
    }, skip: _skip);

    for (final (name, product) in [('add-product', null), ('edit-product', ph7LongProduct)]) {
      ph5TestWidgets('ph7a-$name-$at: the form as before PH7a', (tester) async {
        await pumpPh5(
            tester,
            (fs) => AddEditProductScreen(
                product: product, isModal: modal, firestore: fs, storage: FakeStorage(), currentUserInfo: testUserInfo),
            size: size,
            seed: ph7SeedProducts);
        _expect(tester, 'ph7a-$name-$at', find.byType(AddEditProductScreen));
      }, skip: _skip);
    }
  }
}
