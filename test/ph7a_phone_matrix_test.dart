// PH7a: Products (and its details page), Stock Store (and its details page),
// View Batches, Add Batch, Add Product and Edit Product on phones at
// 360x740, 390x844 and 740x360, in Light, Dark and Kiswahili, with a very
// long Kiswahili product name and an 8-digit price: no overflow, 48 px
// targets, no text under 12 px. Each row reads naturally (R11). The cost
// (R12): a cold open on a phone opens the computer's listeners and reads,
// and coming back from a details page reads nothing (printed for the
// ledger).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/products/add_batch_screen.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_fakes.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// The screens done so far: the others stay skipped until theirs is.
const Set<String> _done = {'Products', 'Stock Store', 'View Batches', 'Add Batch', 'Add Product', 'Edit Product'};

/// A page whose button opens View Batches, as the details pages do.
class _BatchesHost extends StatelessWidget {
  const _BatchesHost();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => showViewBatchesScreen(context, product: ph7LongProduct),
          child: const Text('BATCHES'),
        ),
      );
}

void main() {
  // name: (screen, the row whose details page is checked too, or a button
  // that opens it).
  final screens = <String, (Widget Function(dynamic fs), String?, String?)>{
    'Products': ((fs) => ProductsScreen(firestore: fs, asTab: true), 'p7', null),
    'Stock Store': ((fs) => const StockStoreScreen(), 'p7', null),
    'View Batches': ((fs) => const Ph7Listening(child: _BatchesHost()), null, 'BATCHES'),
    'Add Batch': ((fs) => AddBatchScreen(product: ph7LongProduct), null, null),
    'Add Product': (
      (fs) => AddEditProductScreen(firestore: fs, storage: FakeStorage(), currentUserInfo: testUserInfo),
      null,
      null
    ),
    'Edit Product': (
      (fs) => AddEditProductScreen(product: ph7LongProduct, firestore: fs, storage: FakeStorage(), currentUserInfo: testUserInfo),
      null,
      null
    ),
  };

  for (final e in screens.entries) {
    final (build, row, button) = e.value;
    group('${e.key} phone matrix', () {
      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '${e.key} ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh5(tester, (fs) => build(fs), size: size.size, look: look, pushed: e.key == 'Stock Store', seed: ph7SeedProducts);
            if (button != null) {
              await tester.tap(find.text(button));
              await ph5Settle(tester);
            }
            await checkCase(tester, phone: true, where: '$where list');
            if (row != null) {
              await tester.tap(ph5Key('phoneList-row-$row'));
              await ph5Settle(tester);
              await checkCase(tester, phone: true, where: '$where details');
            }
          }, skip: !_done.contains(e.key));
        }
      }
    });
  }

  group('each row reads naturally (R11)', () {
    final labels = <String, (Widget Function(dynamic fs), String)>{
      'Products': ((fs) => ProductsScreen(firestore: fs, asTab: true), 'Albendazole 10%, 40 pcs, ${Money.unitPrice(15000)}, In Stock'),
      'Stock Store': ((fs) => const StockStoreScreen(), 'Dairy meal 70kg, 15 pcs, ${Money.format(15 * 52000)}, In Stock'),
    };
    for (final e in labels.entries) {
      ph5TestWidgets(e.key, (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPh5(tester, (fs) => e.value.$1(fs), pushed: true, seed: ph7SeedProducts);
        expect(find.bySemanticsLabel(e.value.$2), findsOneWidget);
        semantics.dispose();
      }, skip: !_done.contains(e.key));
    }
  });

  group('cost (R12), counted on the fake Firestore', () {
    for (final (name, build) in [
      ('Products', (dynamic fs) => ProductsScreen(firestore: fs) as Widget),
      ('Stock Store', (dynamic fs) => const StockStoreScreen() as Widget),
    ]) {
      ph5TestWidgets('$name: a phone opens with the computer\'s listeners and reads; back from details reads nothing', (tester) async {
        final counts = <String, (int, int, int)>{};
        for (final size in const [Size(1200, 800), Size(390, 844)]) {
          final db = CountingFirestore();
          await tester.runAsync(() => ph7SeedProducts(db.inner));
          await pumpPh5(tester, build, size: size, pushed: true, firestore: db);
          counts['${size.width.toInt()}'] = (db.listeners, db.gets, db.reads);
          if (size.width < 600) {
            db.resetCounts();
            await tester.tap(ph5Key('phoneList-row-p7'));
            await ph5Settle(tester);
            final details = (db.listens, db.gets, db.reads);
            db.resetCounts();
            await tester.tap(find.byType(BackButton).first);
            await ph5Settle(tester);
            expect((db.gets, db.reads, db.listens), (0, 0, 0), reason: 'back from the details page');
            // ignore: avoid_print
            print('PH7a $name details page opens (listens, gets, reads): $details');
          }
          await tester.pumpWidget(const SizedBox());
        }
        // ignore: avoid_print
        print('PH7a $name cold open (listeners, gets, reads): computer ${counts['1200']}, phone ${counts['390']}');
        expect(counts['390'], counts['1200']);
      }, skip: !_done.contains(name));
    }
  });
}
