// E2 (docs/design/delete_restore.md section 5 and the owner's conditions):
// deleting a sale and restoring it from Trash give back exactly the books
// that were there before: stock, debt, client balance, oldest unpaid date.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
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
  test(skip: pendingE2, 'delete puts the stock back on its batches, removes the debt, lowers the balance, keeps the payment', () async {
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

  test(skip: pendingE2, 'delete is one step: a trash copy that says its stock was returned, and its activity entry', () async {
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

  test(skip: pendingE2, 'a second delete of the same sale writes nothing', () async {
    final fs = await creditSale();
    await deleteSale(fs, 's1');
    final afterFirst = storedData(fs);

    await deleteSale(fs, 's1');

    expect(storedData(fs), afterFirst);
  });


}
