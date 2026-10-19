// E4d-3 (3), C10: every stockAdditions entry names its author, userId = the
// signed-in person's uid, which firestore.rules checks against
// request.auth.uid. The writers are addProduct, addBatch and moveToSellable
// (docs/design/e4d3_writer_audit.md); the daily report reads only productId
// and sellableDelta.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/services/daily_report_service.dart';

import '../helpers/fake_firestore.dart';

const String? _skip = null;

// moveToSellable takes a BuildContext it does not use.
class _NoContext extends Fake implements BuildContext {}

// The writes are done; only the activity entry is left, which asks
// Firebase for the app (ActivityLogger.logActivity): none in a unit test.
Future<void> _ignoringActivityLog(Future<void> call) async {
  try {
    await call;
  } catch (e) {
    if (!'$e'.contains('no-app')) rethrow;
  }
}

Future<List<Map<String, dynamic>>> _additions(FakeFirebaseFirestore fs) async =>
    [for (final d in (await facilityCollection(fs, Collections.stockAdditions).get()).docs) d.data()];

Product _dewormer({String id = '', int stockQty = 10}) => Product(
    id: id, name: 'Dewormer', batchNo: 'D1', expiry: DateTime(2030, 6, 1), buyPrice: 1500, sellPrice: 2500,
    stockQty: stockQty, unit: 'pcs', type: 'Medicine', category: 'Dewormers', facilityId: testFacilityId);

void main() {
  late FakeFirebaseFirestore fs;
  late ProductProvider products;
  setUp(() {
    fs = newFakeFirestore();
    products = ProductProvider(firestore: fs, currentUserInfo: testUserInfo);
  });

  test('addProduct: the starting stock entry names its author', () async {
    await products.addProduct(_dewormer());
    expect((await _additions(fs)).map((a) => a['userId']), [testUserId]);
  }, skip: _skip);

  test('addBatch: the delivery entry names its author', () async {
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 2});
    await products.addBatch(facilityId: testFacilityId, productId: 'p1', batchNo: 'B9', expiry: DateTime(2031, 1, 1),
        buyPrice: 1100, stockQty: 5);
    expect((await _additions(fs)).map((a) => a['userId']), [testUserId]);
  }, skip: _skip);

  test('moveToSellable: the release entry names its author', () async {
    await products.addProduct(_dewormer());
    final productId = (await facilityCollection(fs, Collections.products).get()).docs.single.id;
    await _ignoringActivityLog(products.moveToSellable(_dewormer(id: productId), 4, _NoContext()));
    final additions = await _additions(fs);
    expect(additions.map((a) => [a['sellableDelta'], a['userId']]), containsAll([[4, testUserId]]));
    expect(additions.every((a) => a['userId'] == testUserId), isTrue);
  }, skip: _skip);

  test('the daily report sums the entries as before: the author is ignored', () async {
    await products.addProduct(_dewormer());
    final productId = (await facilityCollection(fs, Collections.products).get()).docs.single.id;
    await _ignoringActivityLog(products.moveToSellable(_dewormer(id: productId), 4, _NoContext()));
    await products.addBatch(facilityId: testFacilityId, productId: productId, batchNo: 'D2',
        expiry: DateTime(2031, 1, 1), buyPrice: 1500, stockQty: 3, destination: 'sellable');
    expect(DailyReportService.sellableAddedByProduct(await _additions(fs)), {productId: 7});
    expect(DailyReportService.sellableAddedByProduct([
      {'productId': 'p1', 'sellableDelta': 2},
      {'productId': 'p1', 'sellableDelta': 3, 'userId': testUserId},
      {'sellableDelta': 9, 'userId': testUserId},
    ]), {'p1': 5});
  });
}
