// E4d-3 (1): an edit keeps what its screen does not own. Edit Service built
// a new Service without the receipt number and wrote 'receiptNumber': null;
// Edit Transaction's set() replaced the document without receiptNumber and,
// on a service expense, serviceId. A service outside the cached pages had
// its stock taken again and its debt added to the client's balance again.
// The providers now read the stored document (docs/design/e4d3_writer_audit.md).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/service.dart';
import 'package:vetbiz_pro/models/transaction.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';

import '../helpers/fake_firestore.dart';

const _skip = 'E4d-3: the fix lands in the next commit';

// The writes are done; only the activity entry is left, which asks
// Firebase for the app (ActivityLogger.logActivity): none in a unit test.
Future<void> _ignoringActivityLog(Future<void> call) async {
  try {
    await call;
  } catch (e) {
    if (!'$e'.contains('no-app')) rethrow;
  }
}

/// Everything stored, without the times an edit sets (updatedAt) and the
/// activity entries.
Object? _withoutEditTimes(Object? node) {
  if (node is! Map) return node;
  return {
    for (final e in node.entries)
      if (e.key != 'updatedAt' && e.key != Collections.activityLogs) e.key: _withoutEditTimes(e.value),
  };
}

/// The Service AddEditServiceScreen builds on Save when nothing is changed
/// (_recordService): the form's fields, no receipt number (the form has
/// none), profits left at 0, items without their batch allocations.
Service _asEditScreenBuilds(Service s, {double? total}) => Service(
      id: s.id, category: s.category, name: s.name, description: s.description,
      totalAmount: total ?? s.totalAmount, totalPaid: s.totalPaid, clientId: s.clientId, clientName: s.clientName,
      serviceDate: s.serviceDate, providedByName: s.providedByName, updatedAt: DateTime.now(),
      itemsUsed: [
        for (final i in s.itemsUsed) {'itemName': i['itemName'], 'price': i['price'], 'productId': i['productId']},
      ],
      paymentMethod: s.totalPaid > 0 ? s.paymentMethod : null, transactionId: s.transactionId,
    );

Future<Service> _storedService(FakeFirebaseFirestore fs, String id) async =>
    Service.fromFirestore((await facilityCollection(fs, Collections.services).doc(id).get()).data()!, id);

/// A credit service to Neema, with one unit of p1, partly paid.
Future<void> _seedService(FakeFirebaseFirestore fs) async {
  await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
  await seedClient(fs, id: 'c2', name: 'Neema', phone: '0713000000');
  await newServiceProvider(fs).addService(testService(id: 'v1', total: 10000, paid: 4000, clientId: 'c2',
      clientName: 'Neema', items: [serviceItem('Dawa', productId: 'p1')]));
  await settle();
}

TransactionProvider _transactions(FakeFirebaseFirestore fs) =>
    TransactionProvider(firestore: fs, currentUserInfo: testUserInfo, isAdmin: () => true);

/// The TransactionModel AddTransactionScreen builds on Save (edit branch):
/// same id, date and recordedBy, the form's fields, no receipt number.
TransactionModel _asEditTransactionBuilds(Map<String, dynamic> stored, String id, {double? amount, String? note}) {
  final t = TransactionModel.fromFirestore(stored, id);
  return TransactionModel(
    id: t.id, date: t.date, description: t.description, amount: amount ?? t.amount, type: t.type,
    category: t.category, recordedBy: t.recordedBy, paymentMethod: t.paymentMethod, note: note ?? t.note,
  );
}

void main() {
  group('Edit Service keeps what the screen does not own', () {
    test('an edit that changes nothing leaves every stored document as it was, except updatedAt (a cached service)', () async {
      final fs = newFakeFirestore();
      await _seedService(fs);
      expect((await _storedService(fs, 'v1')).receiptNumber, 1);
      final services = newServiceProvider(fs);
      await settle();
      expect(services.services.any((s) => s.id == 'v1'), isTrue, reason: 'v1 must be in the cache');
      final before = _withoutEditTimes(storedData(fs));
      await _ignoringActivityLog(services.updateService(_asEditScreenBuilds(await _storedService(fs, 'v1'))));
      await settle();
      expect(_withoutEditTimes(storedData(fs)), before);
    }, skip: _skip);

    test('...also for a service outside the cached pages: no second stock take, no second debt on the balance', () async {
      final fs = newFakeFirestore();
      await _seedService(fs);
      // 25 services saved later fill the live page (AppLimits.pageSize).
      for (var i = 0; i < 25; i++) {
        await facilityCollection(fs, Collections.services).doc('later$i').set(
            {...testService(id: 'later$i').toMap(), 'updatedAt': DateTime(2031, 1, 1 + i)});
      }
      final services = newServiceProvider(fs);
      await settle();
      expect(services.services.any((s) => s.id == 'v1'), isFalse, reason: 'v1 must be outside the cache');
      final before = _withoutEditTimes(storedData(fs));
      await _ignoringActivityLog(services.updateService(_asEditScreenBuilds(await _storedService(fs, 'v1'))));
      await settle();
      expect(_withoutEditTimes(storedData(fs)), before);
      expect(await sellableQty(fs, 'p1'), 4);
    }, skip: _skip);

    test('an edit that changes the amount keeps the receipt number', () async {
      final fs = newFakeFirestore();
      await _seedService(fs);
      await _ignoringActivityLog(
          newServiceProvider(fs).updateService(_asEditScreenBuilds(await _storedService(fs, 'v1'), total: 12000)));
      await settle();
      final stored = await _storedService(fs, 'v1');
      expect([stored.totalAmount, stored.receiptNumber], [12000, 1]);
    }, skip: _skip);
  });

  group('Edit Transaction keeps what the screen does not own', () {
    Future<Map<String, dynamic>> stored(FakeFirebaseFirestore fs, String id) async =>
        (await facilityCollection(fs, Collections.transactions).doc(id).get()).data()!;

    Future<String> seedExpense(FakeFirebaseFirestore fs) async {
      await _ignoringActivityLog(_transactions(fs).addTransaction(
          TransactionModel(id: '', date: DateTime(2026, 10, 1), description: 'Fuel', amount: 3000, type: 'expense',
              category: 'Transport', recordedBy: testUserName, paymentMethod: 'Cash', note: 'Pikipiki'),
          testFacilityId));
      return (await facilityCollection(fs, Collections.transactions).get()).docs.single.id;
    }

    test('an edit that changes nothing leaves every stored field as it was (receipt number included)', () async {
      final fs = newFakeFirestore();
      final id = await seedExpense(fs);
      final before = await stored(fs, id);
      expect(before['receiptNumber'], 1);
      await _ignoringActivityLog(_transactions(fs).updateTransaction(_asEditTransactionBuilds(before, id), testFacilityId));
      expect(await stored(fs, id), before);
    }, skip: _skip);

    test('...and a service expense keeps its serviceId', () async {
      final fs = newFakeFirestore();
      await newServiceProvider(fs).addService(testService(id: 'v3', total: 6000, items: [serviceItem('Gloves', price: 700)]));
      await settle();
      final before = await stored(fs, 'service_v3');
      expect(before['serviceId'], 'v3');
      await _ignoringActivityLog(
          _transactions(fs).updateTransaction(_asEditTransactionBuilds(before, 'service_v3'), testFacilityId));
      expect(await stored(fs, 'service_v3'), before);
    }, skip: _skip);

    test('an edit that changes the amount keeps the receipt number', () async {
      final fs = newFakeFirestore();
      final id = await seedExpense(fs);
      await _ignoringActivityLog(
          _transactions(fs).updateTransaction(_asEditTransactionBuilds(await stored(fs, id), id, amount: 3500), testFacilityId));
      final after = await stored(fs, id);
      expect([after['amount'], after['receiptNumber']], [3500, 1]);
    }, skip: _skip);

    test('clearing the note removes it (the screen owns the note)', () async {
      final fs = newFakeFirestore();
      final id = await seedExpense(fs);
      final edited = _asEditTransactionBuilds(await stored(fs, id), id);
      await _ignoringActivityLog(_transactions(fs).updateTransaction(
          TransactionModel(id: id, date: edited.date, description: edited.description, amount: edited.amount,
              type: edited.type, category: edited.category, recordedBy: edited.recordedBy, paymentMethod: 'Cash'),
          testFacilityId));
      expect((await stored(fs, id)).containsKey('note'), isFalse);
    });
  });
}
