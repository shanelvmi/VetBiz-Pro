// The harness itself: a cash sale through SaleProvider with an in-memory
// Firestore deducts the stock and records the sale.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';

import '../helpers/fake_firestore.dart';

void main() {
  test('a cash sale through the harness deducts stock and records one sale', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});

    final saleId = await newSaleProvider(fs)
        .addSale(testSale(id: 'harness1', items: [saleItem('p1', 2)]), testFacilityId);

    expect(saleId, isNotNull);
    expect(await countDocs(fs, Collections.sales), 1);
    expect(await sellableQty(fs, 'p1'), 3);
    expect(await sellableQty(fs, 'p1', 'b1'), 3);
  });
}
