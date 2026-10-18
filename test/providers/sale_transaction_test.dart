// E1a: what the one sale transaction writes, beyond the design's list.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';

import '../helpers/fake_firestore.dart';

void main() {
  test('receipt numbers follow on, one per sale, saved on the sale', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    final provider = newSaleProvider(fs);

    await provider.addSale(testSale(id: 'r1', items: [saleItem('p1', 1)]), testFacilityId);
    await provider.addSale(testSale(id: 'r2', items: [saleItem('p1', 1)]), testFacilityId);
    await settle();

    final sales = facilityCollection(fs, Collections.sales);
    expect((await sales.doc('r1').get()).data()?['receiptNumber'], 1);
    expect((await sales.doc('r2').get()).data()?['receiptNumber'], 2);
    final counter = await facilityCollection(fs, Collections.counters).doc('receiptNumber').get();
    expect(counter.data()?['value'], 2);
  });

  test('FIFO takes the soonest expiry first, across batches, and records it', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'soon': 2, 'later': 5});

    await newSaleProvider(fs)
        .addSale(testSale(id: 'fifo1', items: [saleItem('p1', 3)]), testFacilityId);
    await settle();

    expect(await sellableQty(fs, 'p1', 'soon'), 0);
    expect(await sellableQty(fs, 'p1', 'later'), 4);
    expect(await sellableQty(fs, 'p1'), 4);
    final sale = await facilityCollection(fs, Collections.sales).doc('fifo1').get();
    final allocations = (sale.data()?['items'] as List).first['batchAllocations'] as List;
    expect(allocations.map((a) => [a['batchId'], a['quantity']]), [
      ['soon', 2],
      ['later', 1],
    ]);
  });

  test('a product with no batches sells from its own sellableQty (legacy)', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'old', legacyQty: 4);

    await newSaleProvider(fs)
        .addSale(testSale(id: 'legacy1', items: [saleItem('old', 3)]), testFacilityId);
    await settle();

    expect(await sellableQty(fs, 'old'), 1);
  });

  test('not enough stock throws InsufficientStockException', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 1});

    expect(
      newSaleProvider(fs).addSale(testSale(id: 'short', items: [saleItem('p1', 2)]), testFacilityId),
      throwsA(isA<InsufficientStockException>()),
    );
  });

  test('a fully unpaid sale leaves a debt and no payment', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedClient(fs, id: 'c1', balance: 500);

    await newSaleProvider(fs).addSale(
        testSale(id: 'unpaid1', items: [saleItem('p1', 1)], paid: 0, clientId: 'c1', clientName: 'Juma'),
        testFacilityId);
    await settle();

    expect(await countDocs(fs, Collections.payments), 0);
    final debt = await facilityCollection(fs, Collections.debts).doc('sale_unpaid1').get();
    expect(debt.data()?['amountOwed'], 2000);
    final client = await facilityCollection(fs, Collections.clients).doc('c1').get();
    expect(client.data()?['balance'], 2500);
    expect(client.data()?['name'], 'Juma', reason: 'the rest of the client is kept');
    expect(client.data()?.containsKey('oldestUnpaidDebtDate'), isFalse,
        reason: 'they already owed, so the oldest unpaid date stays');
  });

  test('a walk-in cash sale leaves no debt and touches no client', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});

    await newSaleProvider(fs)
        .addSale(testSale(id: 'walkin1', items: [saleItem('p1', 1)]), testFacilityId);
    await settle();

    expect(await countDocs(fs, Collections.debts), 0);
    expect(await countDocs(fs, Collections.clients), 0);
    final payment = await facilityCollection(fs, Collections.payments).doc('sale_walkin1').get();
    expect(payment.data()?['amount'], 2000);
  });

  test('the expired-stock note is saved with the sale as activity_logs/sale_{id}_expired', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    const note = 'Sale included expired stock (1 pcs of p1), confirmed by Asha Seller';

    await newSaleProvider(fs).addSale(
        testSale(id: 'exp1', items: [saleItem('p1', 1)]), testFacilityId,
        expiredStockNote: note);
    await settle();

    final logs = facilityCollection(fs, Collections.activityLogs);
    final expired = await logs.doc('sale_exp1_expired').get();
    expect(expired.data()?['description'], note);
    expect(expired.data()?['userId'], testUserId);
    expect((await logs.doc('sale_exp1').get()).exists, isTrue);
  });
}
