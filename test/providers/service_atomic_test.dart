// E1b (docs/design/atomic_sales.md section 5): a service and everything it
// changes succeed or fail together, and a retry with the same service id
// cannot record it twice.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';

import '../helpers/fake_firestore.dart';

void main() {
  test('addService twice with the same service id leaves one service, one debt, one expense, one stock deduction',
      () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedClient(fs, id: 'c1');
    final provider = newServiceProvider(fs);
    final service = testService(
      id: 'retry1',
      items: [serviceItem('Dewormer', productId: 'p1'), serviceItem('Gloves')],
      paid: 4000,
      clientId: 'c1',
      clientName: 'Juma',
    );

    final first = await provider.addService(service);
    await settle();
    final second = await provider.addService(service);
    await settle();

    expect(await countDocs(fs, Collections.services), 1, reason: 'services');
    expect(await countDocs(fs, Collections.debts), 1, reason: 'debts');
    expect(await countDocs(fs, Collections.transactions), 1, reason: 'expenses');
    expect(await countDocs(fs, Collections.payments), 1, reason: 'payments');
    expect(await countDocs(fs, Collections.activityLogs), 1, reason: 'activity entries');
    expect(await sellableQty(fs, 'p1'), 4, reason: 'product deducted once');
    expect(await sellableQty(fs, 'p1', 'b1'), 4, reason: 'batch deducted once');
    final client = await facilityCollection(fs, Collections.clients).doc('c1').get();
    expect(client.data()?['balance'], 6000, reason: 'balance raised once');
    expect(first, 'retry1');
    expect(second, 'retry1');
  });

  test('a credit service leaves debts/service_{id} with the unpaid amount and the client balance equal to it',
      () async {
    final fs = newFakeFirestore();
    await seedClient(fs, id: 'c1', name: 'Juma', phone: '0712000000');
    final service = testService(id: 'credit1', paid: 4000, clientId: 'c1', clientName: 'Juma');

    await newServiceProvider(fs).addService(service);
    await settle();

    final debt = await facilityCollection(fs, Collections.debts).doc('service_credit1').get();
    expect(debt.exists, isTrue, reason: 'debts/service_credit1');
    expect(debt.data()?['amountOwed'], 6000);
    expect(debt.data()?['serviceId'], 'credit1');
    expect(debt.data()?['clientId'], 'c1');
    expect(debt.data()?['clientPhone'], '0712000000');
    expect(debt.data()?['source'], 'Service');
    expect(await countDocs(fs, Collections.debts), 1);

    final client = await facilityCollection(fs, Collections.clients).doc('c1').get();
    expect(client.data()?['balance'], 6000);
    expect(client.data()?['oldestUnpaidDebtDate'], isA<Timestamp>());

    final payment = await facilityCollection(fs, Collections.payments).doc('service_credit1').get();
    expect(payment.data()?['amount'], 4000);
    expect(payment.data()?['serviceId'], 'credit1');
  });

  test('a service with an external item has its expense at transactions/service_{id}', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});

    await newServiceProvider(fs).addService(testService(
      id: 'exp1',
      items: [serviceItem('Dewormer', productId: 'p1', price: 800), serviceItem('Gloves', price: 500)],
    ));
    await settle();

    final expense = await facilityCollection(fs, Collections.transactions).doc('service_exp1').get();
    expect(expense.exists, isTrue, reason: 'transactions/service_exp1');
    expect(expense.data()?['amount'], 500, reason: 'only the item bought outside');
    expect(expense.data()?['type'], 'expense');
    expect(expense.data()?['category'], 'Vet Service Expenses');
    expect(expense.data()?['serviceId'], 'exp1');
    expect(expense.data()?['description'], 'Items used for Deworming: Gloves');
    expect(expense.data()?['recordedBy'], testUserName);
    expect(await countDocs(fs, Collections.transactions), 1);
    expect(await sellableQty(fs, 'p1'), 4, reason: 'the stock item: one unit, no expense');
  });

  test('not enough stock leaves zero writes', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedProduct(fs, id: 'p2', legacyQty: 0);
    await seedClient(fs, id: 'c1');
    final before = storedData(fs);
    final service = testService(
      id: 'short1',
      items: [serviceItem('Dewormer', productId: 'p1'), serviceItem('Vaccine', productId: 'p2'), serviceItem('Gloves')],
      paid: 0,
      clientId: 'c1',
      clientName: 'Juma',
    );

    String? result;
    try {
      result = await newServiceProvider(fs).addService(service);
    } catch (_) {
      result = null;
    }
    await settle();

    expect(result, isNull);
    expect(storedData(fs), before);
  });

  test('not enough stock throws InsufficientStockException, as a sale does', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', legacyQty: 0);

    await expectLater(
      newServiceProvider(fs).addService(testService(id: 'short2', items: [serviceItem('Dewormer', productId: 'p1')])),
      throwsA(isA<InsufficientStockException>()),
    );
  });

  test('a retry of a service that was saved returns it and writes nothing', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
    await seedClient(fs, id: 'c1');
    final provider = newServiceProvider(fs);
    final service = testService(
      id: 'saved1',
      items: [serviceItem('Dewormer', productId: 'p1'), serviceItem('Gloves')],
      paid: 1000,
      clientId: 'c1',
      clientName: 'Juma',
    );
    await provider.addService(service);
    await settle();
    final afterFirst = storedData(fs);

    final retried = await provider.addService(service);
    await settle();

    expect(retried, 'saved1');
    expect(storedData(fs), afterFirst);
  });

  test('the activity entry is activity_logs/service_{id} and passes the existing rule', () async {
    final fs = newFakeFirestore();
    final startedAt = DateTime.now().subtract(const Duration(seconds: 1));

    await newServiceProvider(fs).addService(testService(id: 'log1'));
    await settle();

    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs.map((d) => d.id), ['service_log1']);
    final data = logs.docs.single.data();
    // firestore.rules activity_logs create: userId == request.auth.uid
    // and timestamp == request.time (a server timestamp).
    expect(data['userId'], testUserId);
    expect(data['timestamp'], isA<Timestamp>());
    expect((data['timestamp'] as Timestamp).toDate().isAfter(startedAt), isTrue);
    expect(data['actionType'], ActivityType.services.key);
    expect(data['userName'], testUserName);
    expect(data.keys.toSet().difference({'userId', 'userName', 'actionType', 'description', 'timestamp'}),
        isEmpty);
    expect(data['description'], startsWith('Recorded service for Walk-in - '));
  });
}
