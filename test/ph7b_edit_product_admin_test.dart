// PH7b (0): Edit Product is admin-only, because firestore.rules lets an
// assistant update a product only in its stock fields. The Edit buttons are
// hidden from assistants on every width (the Products grid and list, the
// phone's details page, View Batches; the Stock Store hid them already), and
// ProductProvider.updateProduct refuses a non-admin with the friendly
// admin-only message before anything is written. Batches and stock moves by
// assistants keep working.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/admin_only_refusal.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _wide = Size(1200, 2400);

Finder _editIn(Finder root) => find.descendant(of: root, matching: find.byTooltip('Edit'));

void main() {
  group('the guard', () {
    Future<(FakeFirebaseFirestore, ProductProvider)> provider({required bool admin}) async {
      final fs = FakeFirebaseFirestore();
      await ph7SeedProducts(fs, [ph7Products[6]]);
      return (fs, ProductProvider(firestore: fs, currentUserInfo: testUserInfo, isAdmin: () => admin));
    }

    test('an assistant\'s edit is refused before anything is written, with the admin-only message', () async {
      final (fs, products) = await provider(admin: false);
      final before = (await facilityCollection(fs, Collections.products).doc('p7').get()).data();
      await expectLater(products.updateProduct(ph7LongProduct.copyWith(name: 'Renamed')), throwsA(isA<AdminOnlyException>()));
      final after = (await facilityCollection(fs, Collections.products).doc('p7').get()).data();
      expect(after, before);
      expect(FriendlyError.messageFor(const AdminOnlyException()),
          'Only an admin can edit or delete this record.');
    });

    test('without isAdmin nobody may edit (the helpers ServiceProvider makes only move stock)', () async {
      final fs = FakeFirebaseFirestore();
      await expectLater(ProductProvider(firestore: fs).updateProduct(ph7LongProduct), throwsA(isA<AdminOnlyException>()));
    });

    test('an admin\'s edit is written as before', () async {
      final (fs, products) = await provider(admin: true);
      await products.updateProduct(ph7LongProduct.copyWith(name: 'Renamed'));
      final after = (await facilityCollection(fs, Collections.products).doc('p7').get()).data()!;
      expect(after['name'], 'Renamed');
    });

    test('an assistant still adjusts a batch (stock fields only), as today', () async {
      final (fs, products) = await provider(admin: false);
      await products.adjustExistingBatch(
          facilityId: testFacilityId, productId: 'p7', batchId: 'p7-b1', mode: 'set', stockQty: 5, sellableQty: 7);
      final p = (await facilityCollection(fs, Collections.products).doc('p7').get()).data()!;
      expect([p['stockQty'], p['sellableQty']], [5, 7]);
    });
  });

  group('the buttons', () {
    for (final admin in [true, false]) {
      final who = admin ? 'an admin' : 'an assistant';
      final count = admin ? findsWidgets : findsNothing;

      ph5TestWidgets('Products on a tablet, $who: Edit on the grid cards and the list rows ${admin ? 'shown' : 'hidden'}', (tester) async {
        await pumpPh5(tester, (fs) => ProductsScreen(firestore: fs), size: _wide, pushed: true, admin: admin, seed: ph7SeedProducts);
        expect(find.descendant(of: find.byType(ProductsScreen), matching: find.text('Edit')), count);
        expect(find.text('Sell'), findsWidgets, reason: 'Sell stays for everyone');
        await tester.tap(find.byIcon(Icons.view_list_rounded));
        await ph5Settle(tester);
        expect(_editIn(find.byType(ProductsScreen)), count);
      });

      ph5TestWidgets('Products on a phone, $who: the details page ${admin ? 'has' : 'has no'} Edit', (tester) async {
        await pumpPh5(tester, (fs) => ProductsScreen(firestore: fs), admin: admin, seed: ph7SeedProducts);
        await tester.tap(ph5Key('phoneList-row-p1'));
        await ph5Settle(tester);
        expect(_editIn(ph5Page), admin ? findsOneWidget : findsNothing);
      });

      ph5TestWidgets('View Batches, $who: Edit Details ${admin ? 'shown' : 'hidden'}', (tester) async {
        await pumpPh5(tester, (fs) => ViewBatchesScreen(product: ph7LongProduct, isModal: true),
            size: _wide, admin: admin, seed: ph7SeedProducts);
        expect(find.text('Edit Details'), admin ? findsOneWidget : findsNothing);
      });
    }
  });
}
