// E2 (docs/design/delete_restore.md section 5 and the owner's conditions):
// deleting a sale and restoring it from Trash give back exactly the books
// that were there before: stock, debt, client balance, oldest unpaid date.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/restore_outcome.dart';
import 'package:vetbiz_pro/models/sale.dart';

import '../helpers/fake_firestore.dart';

// Skipped until the E2 commit that implements it.
const pendingE2 = 'E2: not implemented yet';

/// What a delete and a restore must leave as they found it.
Future<Map<String, Object?>> books(FakeFirebaseFirestore fs, {required String saleId, String? clientId}) async {
  final client =
      clientId == null ? null : (await facilityCollection(fs, Collections.clients).doc(clientId).get()).data();
  final debt = (await facilityCollection(fs, Collections.debts).doc('sale_$saleId').get()).data();
  // The sale itself, but for updatedAt (a restore is an update).
  final sale = (await facilityCollection(fs, Collections.sales).doc(saleId).get()).data()?..remove('updatedAt');
  return {
    'sale': sale,
    'product': await sellableQty(fs, 'p1'),
    'batch1': await sellableQty(fs, 'p1', 'b1'),
    'batch2': await sellableQty(fs, 'p1', 'b2'),
    'balance': client?['balance'],
    'oldestUnpaidDebtDate': client?['oldestUnpaidDebtDate'],
    'debt': debt,
    'debts': await countDocs(fs, Collections.debts),
    'payments': await countDocs(fs, Collections.payments),
    'sales': await countDocs(fs, Collections.sales),
  };
}

Future<void> deleteSale(FakeFirebaseFirestore fs, String id) async {
  await newSaleProvider(fs).deleteSale(id, testFacilityId);
  await settle();
}

Future<RestoreResult> restoreSale(FakeFirebaseFirestore fs, String id) async {
  final result = await restoreFromTrash(fs, Collections.trashSales, Collections.sales, id);
  await settle();
  return result;
}

/// A repayment on a sale's debt, written as AddPaymentScreen writes it:
/// a payment, the balance down, the debt down (deleted at 0), and the sale
/// through Sale.applyPayment.
Future<void> repay(FakeFirebaseFirestore fs, {required String saleId, required double amount}) async {
  final debtRef = facilityCollection(fs, Collections.debts).doc('sale_$saleId');
  final amountOwed = ((await debtRef.get()).data()!['amountOwed'] as num).toDouble();
  final saleRef = facilityCollection(fs, Collections.sales).doc(saleId);
  final sale = Sale.fromFirestore((await saleRef.get()).data(), saleId);
  final batch = fs.batch();
  batch.set(facilityCollection(fs, Collections.payments).doc(), {
    'clientId': sale.clientId,
    'debtId': debtRef.id,
    'saleId': saleId,
    'amount': amount,
    'timestamp': FieldValue.serverTimestamp(),
    'source': 'debt_repayment',
  });
  batch.update(facilityCollection(fs, Collections.clients).doc(sale.clientId), {
    'balance': FieldValue.increment(-amount),
  });
  final remaining = amountOwed - amount;
  if (remaining <= 0) {
    batch.delete(debtRef);
  } else {
    batch.update(debtRef, {'amountOwed': remaining});
  }
  batch.update(saleRef, sale.applyPayment(amount).toMap());
  await batch.commit();
}

/// A credit sale of 3 units of p1 (batches b1: 2, b2: 5) to client c1:
/// total 6000, [paid] up front.
Future<FakeFirebaseFirestore> creditSale({double paid = 1000}) async {
  final fs = newFakeFirestore();
  await seedProduct(fs, id: 'p1', batchQty: {'b1': 2, 'b2': 5});
  await seedClient(fs, id: 'c1', name: 'Juma', phone: '0712000000');
  await newSaleProvider(fs).addSale(
      testSale(id: 's1', items: [saleItem('p1', 3)], paid: paid, clientId: 'c1', clientName: 'Juma'),
      testFacilityId);
  await settle();
  return fs;
}

void main() {
  // --- Delete ---
  test('delete puts the stock back on its batches, removes the debt, lowers the balance, keeps the payment', () async {
    final fs = await creditSale();
    expect(await sellableQty(fs, 'p1', 'b1'), 0);

    await deleteSale(fs, 's1');

    final deleted = await books(fs, saleId: 's1', clientId: 'c1');
    expect(deleted['sale'], isNull);
    expect(deleted['product'], 7);
    expect(deleted['batch1'], 2, reason: 'back on the batch it came from');
    expect(deleted['batch2'], 5);
    expect(deleted['debt'], isNull);
    expect(deleted['debts'], 0);
    expect(deleted['balance'], 0);
    expect(deleted['oldestUnpaidDebtDate'], isNull);
    expect(deleted['payments'], 1, reason: 'the upfront payment stays counted (condition 3)');
  });

  test('delete is one step: a trash copy that says its stock was returned, and its activity entry', () async {
    final fs = await creditSale();

    await deleteSale(fs, 's1');

    final copy = (await facilityCollection(fs, Collections.trashSales).doc('s1').get()).data();
    expect(copy, isNotNull);
    expect(copy!['stockReturned'], isTrue);
    expect(copy['deletedBy'], testUserEmail);
    expect(copy['receiptNumber'], isNotNull);
    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs.where((d) => d.id.startsWith('delete_sale_s1_')).length, 1);
  });

  test('a second delete of the same sale writes nothing', () async {
    final fs = await creditSale();
    await deleteSale(fs, 's1');
    final afterFirst = storedData(fs);

    await deleteSale(fs, 's1');

    expect(storedData(fs), afterFirst);
  });

  // --- Restore ---
  test(skip: pendingE2, 'a credit sale deleted and restored gives back its stock, debt, balance and oldest unpaid date', () async {
    final fs = await creditSale();
    final before = await books(fs, saleId: 's1', clientId: 'c1');
    expect(before['debt'], isNotNull);

    await deleteSale(fs, 's1');
    final deleted = await books(fs, saleId: 's1', clientId: 'c1');
    expect(deleted['product'], 7, reason: 'stock back on the shelf');
    expect(deleted['debt'], isNull, reason: 'debt removed');
    expect(deleted['balance'], 0, reason: 'balance lowered');
    expect(deleted['oldestUnpaidDebtDate'], isNull, reason: 'no unpaid debt left');
    expect(deleted['payments'], 1, reason: 'the upfront payment stays counted (condition 3)');

    final result = await restoreSale(fs, 's1');
    expect(result, RestoreResult.restored);
    expect(await books(fs, saleId: 's1', clientId: 'c1'), before);
  });

  test(skip: pendingE2, 'a cash sale deleted and restored gives back its stock and touches no client', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 2, 'b2': 5});
    await newSaleProvider(fs).addSale(testSale(id: 's1', items: [saleItem('p1', 3)]), testFacilityId);
    await settle();
    final before = await books(fs, saleId: 's1');

    await deleteSale(fs, 's1');
    expect(await sellableQty(fs, 'p1'), 7);
    await restoreSale(fs, 's1');

    expect(await books(fs, saleId: 's1'), before);
  });

  test(skip: pendingE2, 'condition 6: a partly repaid credit sale deleted and restored gives back the same debt, balance and oldest date',
      () async {
    final fs = await creditSale();
    await repay(fs, saleId: 's1', amount: 2000);
    final before = await books(fs, saleId: 's1', clientId: 'c1');
    expect(before['balance'], 3000, reason: '6000 - 1000 up front - 2000 repaid');
    expect((before['debt'] as Map)['amountOwed'], 3000);

    await deleteSale(fs, 's1');
    final deleted = await books(fs, saleId: 's1', clientId: 'c1');
    expect(deleted['balance'], 0);
    expect(deleted['debt'], isNull);
    expect(deleted['payments'], 2, reason: 'the upfront payment and the repayment stay');

    await restoreSale(fs, 's1');
    expect(await books(fs, saleId: 's1', clientId: 'c1'), before);
  });

  test(skip: pendingE2, 'restore twice (a retry after a lost answer): one sale, stock taken once, balance raised once', () async {
    final fs = await creditSale();
    final before = await books(fs, saleId: 's1', clientId: 'c1');
    await deleteSale(fs, 's1');

    await restoreSale(fs, 's1');
    final afterFirst = storedData(fs);
    final second = await restoreSale(fs, 's1');

    expect(second, RestoreResult.alreadyRestored);
    expect(storedData(fs), afterFirst, reason: 'the second restore writes nothing');
    expect(await books(fs, saleId: 's1', clientId: 'c1'), before);
  });

  test(skip: pendingE2, 'condition 1: not enough stock to restore: refused naming the product, nothing written', () async {
    final fs = await creditSale();
    await deleteSale(fs, 's1');
    // Sold out in between: 1 of the 7 left.
    final productRef = facilityCollection(fs, Collections.products).doc('p1');
    await productRef.update({'sellableQty': 1});
    await productRef.collection(Collections.batches).doc('b1').update({'sellableQty': 0});
    await productRef.collection(Collections.batches).doc('b2').update({'sellableQty': 1});
    final before = storedData(fs);

    await expectLater(
      restoreSale(fs, 's1'),
      throwsA(isA<RestoreRefusedException>()
          .having((e) => e.reason, 'reason', RestoreRefusal.notEnoughStock)
          .having((e) => e.productName, 'productName', 'p1')
          .having((e) => e.needed, 'needed', 3)
          .having((e) => e.available, 'available', 1)),
    );
    await settle();
    expect(storedData(fs), before);
  });

  test(skip: pendingE2, 'condition 2: the client no longer exists: refused, nothing written', () async {
    final fs = await creditSale();
    await deleteSale(fs, 's1');
    await facilityCollection(fs, Collections.clients).doc('c1').delete();
    final before = storedData(fs);

    await expectLater(
      restoreSale(fs, 's1'),
      throwsA(isA<RestoreRefusedException>().having((e) => e.reason, 'reason', RestoreRefusal.clientGone)),
    );
    await settle();
    expect(storedData(fs), before);
  });

  test(skip: pendingE2, 'condition 4: a product in the sale no longer exists: refused naming it, nothing written', () async {
    final fs = await creditSale();
    await deleteSale(fs, 's1');
    final productRef = facilityCollection(fs, Collections.products).doc('p1');
    for (final batch in (await productRef.collection(Collections.batches).get()).docs) {
      await batch.reference.delete();
    }
    await productRef.delete();
    final before = storedData(fs);

    await expectLater(
      restoreSale(fs, 's1'),
      throwsA(isA<RestoreRefusedException>()
          .having((e) => e.reason, 'reason', RestoreRefusal.productGone)
          .having((e) => e.productName, 'productName', 'p1')),
    );
    await settle();
    expect(storedData(fs), before);
  });

  test(skip: pendingE2, 'condition 5 and test 7: a trash copy from the old delete restores with its effects, search fields and updatedAt',
      () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 2, 'b2': 5});
    await seedClient(fs, id: 'c1', name: 'Juma');
    // What the old deleteSale wrote: the cached sale's toMap() and the two
    // trash fields; no stockReturned, no search fields. Its delete had put
    // the stock back, removed the debt and lowered the balance.
    final oldUpdatedAt = DateTime(2026, 1, 2);
    final sale = testSale(id: 's1', items: [saleItem('p1', 3)], paid: 1000, clientId: 'c1', clientName: 'Juma')
        .copyWith(updatedAt: oldUpdatedAt, receiptNumber: 7);
    await facilityCollection(fs, Collections.trashSales).doc('s1').set({
      ...sale.toMap(),
      'deletedAt': Timestamp.fromDate(DateTime(2026, 1, 3)),
      'deletedBy': testUserEmail,
    });

    final result = await restoreSale(fs, 's1');

    expect(result, RestoreResult.restoredFromOldCopy, reason: 'the screen adds "Check its stock afterwards."');
    final restored = (await facilityCollection(fs, Collections.sales).doc('s1').get()).data()!;
    expect(restored['clientNameLower'], 'juma');
    expect(restored['paymentStatus'], isNotNull);
    expect((restored['updatedAt'] as Timestamp).toDate(), isNot(oldUpdatedAt));
    expect(restored.containsKey('deletedAt'), isFalse);
    expect(restored.containsKey('stockReturned'), isFalse);
    expect(await sellableQty(fs, 'p1'), 4, reason: 'the stock is taken again');
    final debt = (await facilityCollection(fs, Collections.debts).doc('sale_s1').get()).data();
    expect(debt?['amountOwed'], 5000);
    final client = (await facilityCollection(fs, Collections.clients).doc('c1').get()).data()!;
    expect(client['balance'], 5000);
    expect(client['oldestUnpaidDebtDate'], isA<Timestamp>());
    expect(await countDocs(fs, Collections.trashSales), 0);
  });
}
