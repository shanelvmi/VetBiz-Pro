// E2 (docs/design/delete_restore.md section 5 and the owner's conditions):
// deleting a service and restoring it from Trash give back its stock, debt,
// client balance, oldest unpaid date and its expense.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';

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


}
