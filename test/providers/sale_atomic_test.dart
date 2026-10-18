// E1a (docs/design/atomic_sales.md section 5): a sale and everything it
// changes succeed or fail together, and a retry with the same sale id
// cannot record it twice.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/data/collections.dart';

import '../helpers/fake_firestore.dart';

// Skipped only until the transaction commit: on the old code the first two
// fail (two sales; no debts/sale_{id}). The third fails only in the fake,
// which keeps the writes of a transaction that throws (real Firestore rolls
// them back, so on real Firestore the old code passes it, as the design says).
const _untilE1a = 'E1a: fails on the old addSale until the transaction commit';

void main() {
  test('addSale twice with the same sale id leaves one sale, one payment, one stock deduction',
      () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    final provider = newSaleProvider(fs);
    final sale = testSale(id: 'retry1', items: [saleItem('p1', 2)]);

    final first = await provider.addSale(sale, testFacilityId);
    final second = await provider.addSale(sale, testFacilityId);
    await settle();

    expect(await countDocs(fs, Collections.sales), 1, reason: 'sales');
    expect(await countDocs(fs, Collections.payments), 1, reason: 'payments');
    expect(await countDocs(fs, Collections.activityLogs), 1, reason: 'activity entries');
    expect(await sellableQty(fs, 'p1'), 3, reason: 'product deducted once');
    expect(await sellableQty(fs, 'p1', 'b1'), 3, reason: 'batch deducted once');
    expect(first, 'retry1');
    expect(second, 'retry1');
  }, skip: _untilE1a);

  test('a credit sale leaves debts/sale_{id} with the unpaid amount and the client balance equal to it',
      () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedClient(fs, id: 'c1', name: 'Juma', phone: '0712000000');
    final sale = testSale(
        id: 'credit1', items: [saleItem('p1', 2)], paid: 1000, clientId: 'c1', clientName: 'Juma');

    await newSaleProvider(fs).addSale(sale, testFacilityId);
    await settle();

    final debt = await facilityCollection(fs, Collections.debts).doc('sale_credit1').get();
    expect(debt.exists, isTrue, reason: 'debts/sale_credit1');
    expect(debt.data()?['amountOwed'], 3000);
    expect(debt.data()?['saleId'], 'credit1');
    expect(debt.data()?['clientId'], 'c1');
    expect(debt.data()?['clientPhone'], '0712000000');
    expect(debt.data()?['source'], 'Sale');
    expect(await countDocs(fs, Collections.debts), 1);

    final client = await facilityCollection(fs, Collections.clients).doc('c1').get();
    expect(client.data()?['balance'], 3000);
    expect(client.data()?['oldestUnpaidDebtDate'], isA<Timestamp>());

    final payment = await facilityCollection(fs, Collections.payments).doc('sale_credit1').get();
    expect(payment.data()?['amount'], 1000);
    expect(payment.data()?['saleId'], 'credit1');
  }, skip: _untilE1a);

  test('not enough stock for item 2 leaves zero writes', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedProduct(fs, id: 'p2', batchQty: {'b2': 1});
    // Parsed, so only values count, not the order keys are listed in.
    final before = jsonDecode(fs.dump());
    final sale = testSale(id: 'short1', items: [saleItem('p1', 2), saleItem('p2', 3)]);

    String? result;
    try {
      result = await newSaleProvider(fs).addSale(sale, testFacilityId);
    } catch (_) {
      result = null;
    }
    await settle();

    expect(result, isNull);
    expect(jsonDecode(fs.dump()), before);
  }, skip: _untilE1a);

  test('the activity entry passes the existing rule (own uid, server clock)', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    final startedAt = DateTime.now().subtract(const Duration(seconds: 1));

    await newSaleProvider(fs)
        .addSale(testSale(id: 'log1', items: [saleItem('p1', 1)]), testFacilityId);
    await settle();

    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs, isNotEmpty);
    for (final doc in logs.docs) {
      final data = doc.data();
      // firestore.rules activity_logs create: userId == request.auth.uid
      // and timestamp == request.time (a server timestamp).
      expect(data['userId'], testUserId);
      expect(data['timestamp'], isA<Timestamp>());
      expect((data['timestamp'] as Timestamp).toDate().isAfter(startedAt), isTrue);
      expect(data['actionType'], ActivityType.sales.key);
      expect(data['userName'], testUserName);
      expect(data.keys.toSet().difference({'userId', 'userName', 'actionType', 'description', 'timestamp'}),
          isEmpty);
    }
    expect(logs.docs.first.data()['description'], startsWith('Recorded sale to Walk-in - '));
  });
}
