// E2 (docs/design/delete_restore.md section 5 and the owner's conditions):
// deleting a service and restoring it from Trash give back its stock, debt,
// client balance, oldest unpaid date and its expense.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/restore_outcome.dart';

import '../helpers/fake_firestore.dart';

// Skipped until the E2 commit that implements it.
const pendingE2 = 'E2: not implemented yet';

Future<Map<String, Object?>> books(FakeFirebaseFirestore fs, {required String serviceId}) async {
  final client = (await facilityCollection(fs, Collections.clients).doc('c1').get()).data();
  final service = (await facilityCollection(fs, Collections.services).doc(serviceId).get()).data()
    ?..remove('updatedAt');
  return {
    'service': service,
    'product': await sellableQty(fs, 'p1'),
    'batch': await sellableQty(fs, 'p1', 'b1'),
    'balance': client?['balance'],
    'oldestUnpaidDebtDate': client?['oldestUnpaidDebtDate'],
    'debt': (await facilityCollection(fs, Collections.debts).doc('service_$serviceId').get()).data(),
    'expense': (await facilityCollection(fs, Collections.transactions).doc('service_$serviceId').get()).data(),
    'transactions': await countDocs(fs, Collections.transactions),
    'payments': await countDocs(fs, Collections.payments),
  };
}

Future<RestoreResult> restoreService(FakeFirebaseFirestore fs, String id) async {
  final result = await restoreFromTrash(fs, Collections.trashServices, Collections.services, id);
  await settle();
  return result;
}

/// A credit service to c1 using one unit of p1 (batch b1: 5) and gloves
/// bought outside (500): total 10000, 4000 paid up front.
Future<FakeFirebaseFirestore> creditService() async {
  final fs = newFakeFirestore();
  await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
  await seedClient(fs, id: 'c1', name: 'Juma', phone: '0712000000');
  await newServiceProvider(fs).addService(testService(
    id: 'v1',
    items: [serviceItem('p1', productId: 'p1', price: 800), serviceItem('Gloves', price: 500)],
    paid: 4000,
    clientId: 'c1',
    clientName: 'Juma',
  ));
  await settle();
  return fs;
}

void main() {
  // --- Delete ---
  test(skip: pendingE2, 'delete puts the stock back, removes the debt and the expense, keeps the payment; the copy keeps the expense',
      () async {
    final fs = await creditService();

    await newServiceProvider(fs).deleteService('v1');
    await settle();

    final deleted = await books(fs, serviceId: 'v1');
    expect(deleted['service'], isNull);
    expect(deleted['product'], 5);
    expect(deleted['batch'], 5);
    expect(deleted['debt'], isNull);
    expect(deleted['expense'], isNull, reason: 'the expense leaves the books while in Trash');
    expect(deleted['balance'], 0);
    expect(deleted['oldestUnpaidDebtDate'], isNull);
    expect(deleted['payments'], 1, reason: 'the upfront payment stays counted (condition 3)');
    final copy = (await facilityCollection(fs, Collections.trashServices).doc('v1').get()).data()!;
    expect(copy['stockReturned'], isTrue);
    expect(copy['deletedBy'], testUserEmail);
    expect((copy['trashedExpense'] as Map)['amount'], 500);
    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs.where((d) => d.id.startsWith('delete_service_v1_')).length, 1);
  });

  test(skip: pendingE2, 'test 5: a service not in the cached list gets its stock back on delete', () async {
    final fs = await creditService();
    expect(await sellableQty(fs, 'p1'), 4);

    // A provider whose list has not loaded yet.
    final provider = newServiceProvider(fs);
    await provider.deleteService('v1');
    await settle();

    expect(await sellableQty(fs, 'p1'), 5);
    expect(await sellableQty(fs, 'p1', 'b1'), 5);
  });

  // --- Restore ---
  test(skip: pendingE2, 'test 4: a service with a stock item and an external item deleted and restored gives back stock, debt, balance and expense',
      () async {
    final fs = await creditService();
    final before = await books(fs, serviceId: 'v1');
    expect(before['expense'], isNotNull);

    await newServiceProvider(fs).deleteService('v1');
    await settle();
    final deleted = await books(fs, serviceId: 'v1');
    expect(deleted['product'], 5, reason: 'stock back');
    expect(deleted['debt'], isNull);
    expect(deleted['expense'], isNull, reason: 'the expense leaves the books while in Trash');
    expect(deleted['balance'], 0);
    expect(deleted['payments'], 1, reason: 'the upfront payment stays counted (condition 3)');
    final copy = (await facilityCollection(fs, Collections.trashServices).doc('v1').get()).data()!;
    expect(copy['stockReturned'], isTrue);
    expect((copy['trashedExpense'] as Map)['amount'], 500);

    final result = await restoreService(fs, 'v1');
    expect(result, RestoreResult.restored);
    expect(await books(fs, serviceId: 'v1'), before);
  });

  test(skip: pendingE2, 'restore twice: one service, stock taken once, one expense, balance raised once', () async {
    final fs = await creditService();
    final before = await books(fs, serviceId: 'v1');
    await newServiceProvider(fs).deleteService('v1');
    await settle();

    await restoreService(fs, 'v1');
    final afterFirst = storedData(fs);
    final second = await restoreService(fs, 'v1');

    expect(second, RestoreResult.alreadyRestored);
    expect(storedData(fs), afterFirst);
    expect(await books(fs, serviceId: 'v1'), before);
  });

  test(skip: pendingE2, 'condition 1: not enough stock to restore a service: refused naming the item, nothing written', () async {
    final fs = await creditService();
    await newServiceProvider(fs).deleteService('v1');
    await settle();
    final productRef = facilityCollection(fs, Collections.products).doc('p1');
    await productRef.update({'sellableQty': 0});
    await productRef.collection(Collections.batches).doc('b1').update({'sellableQty': 0});
    final before = storedData(fs);

    await expectLater(
      restoreService(fs, 'v1'),
      throwsA(isA<RestoreRefusedException>()
          .having((e) => e.reason, 'reason', RestoreRefusal.notEnoughStock)
          .having((e) => e.productName, 'productName', 'p1')
          .having((e) => e.needed, 'needed', 1)
          .having((e) => e.available, 'available', 0)),
    );
    await settle();
    expect(storedData(fs), before);
  });

  test(skip: pendingE2, 'condition 4: the product of a stock item no longer exists: refused, nothing written', () async {
    final fs = await creditService();
    await newServiceProvider(fs).deleteService('v1');
    await settle();
    final productRef = facilityCollection(fs, Collections.products).doc('p1');
    await productRef.collection(Collections.batches).doc('b1').delete();
    await productRef.delete();
    final before = storedData(fs);

    await expectLater(
      restoreService(fs, 'v1'),
      throwsA(isA<RestoreRefusedException>().having((e) => e.reason, 'reason', RestoreRefusal.productGone)),
    );
    await settle();
    expect(storedData(fs), before);
  });

  test(skip: pendingE2, 'test 6 and condition 5: a service trashed by the old code (no trashedExpense) gets its expense recomputed',
      () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedClient(fs, id: 'c1', name: 'Juma');
    final service = testService(
      id: 'v1',
      items: [serviceItem('p1', productId: 'p1', price: 800), serviceItem('Gloves', price: 500)],
      paid: 10000,
      clientId: 'c1',
      clientName: 'Juma',
    );
    await facilityCollection(fs, Collections.trashServices).doc('v1').set({
      ...service.copyWith(receiptNumber: 3).toMap(),
      'deletedAt': Timestamp.fromDate(DateTime(2026, 1, 3)),
      'deletedBy': testUserEmail,
    });

    final result = await restoreService(fs, 'v1');

    expect(result, RestoreResult.restoredFromOldCopy);
    final expense = (await facilityCollection(fs, Collections.transactions).doc('service_v1').get()).data();
    expect(expense?['amount'], 500, reason: 'Service.externalExpenseTotal');
    expect(expense?['serviceId'], 'v1');
    expect(expense?['type'], 'expense');
    expect(await sellableQty(fs, 'p1'), 4);
    final restored = (await facilityCollection(fs, Collections.services).doc('v1').get()).data()!;
    expect(restored['clientNameLower'], 'juma');
    expect(restored.containsKey('trashedExpense'), isFalse);
  });
}
