// UI2 (1): the left strips removed at every width. The pages that had one
// keep their other fingerprints (ph7a-stock-alerts-, ph8b-team-); this adds
// the one state none of them shows: Add Product's "already exists" notice,
// recorded at 768x1024, 1024x768 and 1200x800 before the strip went.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    ph5TestWidgets('ui2-add-product-duplicate-$at: the notice for a name already in use', (tester) async {
      await pumpPh5(
          tester,
          (fs) => Ph7Listening(
              child: AddEditProductScreen(
                  isModal: size.width >= 900, firestore: fs, storage: FakeStorage(), currentUserInfo: testUserInfo)),
          size: size,
          seed: ph7SeedProducts);
      await tester.enterText(find.byType(TextFormField).first, 'Penstrep');
      await ph5Settle(tester);
      expect(find.textContaining('Penstrep'), findsWidgets);
      expectSameFingerprint('ui2-add-product-duplicate-$at', treeFingerprint(tester, find.byType(AddEditProductScreen).first));
    });
  }
}
