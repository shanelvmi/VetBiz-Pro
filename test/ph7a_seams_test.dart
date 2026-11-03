// PH7a seams: Add/Edit Product takes its Firestore, Storage, image picker
// and signed-in person (null: the app's own, so nothing changes in the app);
// View Batches, Add Batch and Stock Store read only through the providers,
// which already take a Firestore. Each builds in a test on a fake.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

final _product = Product(
  id: 'p1',
  name: 'Albendazole 10%',
  buyPrice: 9000,
  sellPrice: 15000,
  stockQty: 0,
  sellableQty: 40,
  unit: 'pcs',
  type: 'Oral Liquid',
  category: 'Anthelmintics',
  facilityId: testFacilityId,
  hasEverHadStock: true,
);

void main() {
  const wide = Size(1200, 800);

  ph5TestWidgets('Add Product builds on a fake Firestore and Storage', (tester) async {
    await pumpPh5(tester,
        (fs) => AddEditProductScreen(
            firestore: fs, storage: FakeStorage(), imagePicker: FakeImagePicker(), currentUserInfo: testUserInfo),
        size: wide);
    expect(tester.takeException(), isNull);
    expect(find.byType(AddEditProductScreen), findsOneWidget);
  });

  ph5TestWidgets('Edit Product reads its batches from the fake Firestore', (tester) async {
    await pumpPh5(tester,
        (fs) => AddEditProductScreen(
            product: _product, firestore: fs, storage: FakeStorage(), currentUserInfo: testUserInfo),
        size: wide, seed: (fs) => ph7SeedProducts(fs, [ph7Products.first]));
    expect(tester.takeException(), isNull);
    // One batch: its quantities fill the simple editor.
    expect(find.text('40'), findsWidgets);
  });

  ph5TestWidgets('View Batches builds through the product provider', (tester) async {
    await pumpPh5(tester, (fs) => ViewBatchesScreen(product: _product),
        size: wide, seed: (fs) => ph7SeedProducts(fs, [ph7Products.first]));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('BN-001'), findsOneWidget);
  });

  ph5TestWidgets('Add Batch builds', (tester) async {
    await pumpPh5(tester, (fs) => AddBatchScreen(product: _product), size: wide);
    expect(tester.takeException(), isNull);
    expect(find.byType(AddBatchScreen), findsOneWidget);
  });

  ph5TestWidgets('Stock Store builds through the product provider', (tester) async {
    await pumpPh5(tester, (fs) => const StockStoreScreen(), size: wide, pushed: true, seed: ph7SeedProducts);
    expect(tester.takeException(), isNull);
    expect(find.text('Dairy meal 70kg'), findsOneWidget);
  });
}
