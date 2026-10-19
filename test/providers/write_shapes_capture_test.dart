// E4d-1: the REAL write shapes of the money and stock flows, captured from
// the provider code itself (fake_cloud_firestore), for the rules emulator to
// replay as each role that makes them
// (firestore_rules_tests/fixtures/app_write_shapes.json).
//
// A flow is recorded as what it changed: every document before and after.
// That is exactly what the rules see (request.resource.data is the document
// after the write, increments applied), so the replay commits all of a
// flow's changes in ONE batch, as the app's transaction or batch does.
// Activity log entries are left out: their rule checks request.time, and it
// is not part of E4d.
//
// The fixture is rewritten with:
//   flutter test test/providers/write_shapes_capture_test.dart --dart-define=WRITE_SHAPES=true
// Otherwise this test fails when the flows' shape (which documents, which
// fields) no longer matches the fixture.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/models/sale.dart';
import 'package:vetbiz_pro/models/service.dart';
import 'package:vetbiz_pro/models/transaction.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';

import '../helpers/fake_firestore.dart';

const _fixture = 'firestore_rules_tests/fixtures/app_write_shapes.json';
const _write = bool.fromEnvironment('WRITE_SHAPES');

// E4d-2 adds the receipt counters, the stock additions log and the
// transactions Trash.
const _collections = [
  Collections.products, Collections.sales, Collections.services, Collections.debts, Collections.clients,
  Collections.payments, Collections.transactions, Collections.trashSales, Collections.trashServices,
  Collections.trashClients, Collections.counters, Collections.stockAdditions, Collections.trashTransactions,
];
const _everyone = ['owner', 'coadmin', 'assistant'];
const _admins = ['owner', 'coadmin'];

Object? _encode(Object? v) {
  if (v is Timestamp) return {r'$ts': v.toDate().toUtc().toIso8601String()};
  if (v is DateTime) return {r'$ts': v.toUtc().toIso8601String()};
  if (v is Map) return {for (final e in v.entries) e.key.toString(): _encode(e.value)};
  if (v is List) return v.map(_encode).toList();
  return v;
}

/// Every stored document the flows touch, by path under the facility.
Future<Map<String, Map<String, Object?>>> _snapshot(FakeFirebaseFirestore fs) async {
  final out = <String, Map<String, Object?>>{};
  for (final name in _collections) {
    for (final doc in (await facilityCollection(fs, name).get()).docs) {
      out['$name/${doc.id}'] = _encode(doc.data()) as Map<String, Object?>;
      if (name == Collections.products) {
        for (final b in (await doc.reference.collection(Collections.batches).get()).docs) {
          out['$name/${doc.id}/${Collections.batches}/${b.id}'] = _encode(b.data()) as Map<String, Object?>;
        }
      }
    }
  }
  return out;
}

// Auto ids (an add() inside the provider) are random: named by order.
// Fixed ids the app chooses that happen to look like one are kept.
const _fixedIds = {'expenseReceiptNumber'};
String _stablePath(String path, Map<String, String> autoIds) => path.split('/').map((s) {
      if (!_fixedIds.contains(s) && RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(s)) {
        return autoIds.putIfAbsent(s, () => 'auto${autoIds.length + 1}');
      }
      return s;
    }).join('/');

final _flows = <Map<String, Object?>>[];

/// [roles] make this write in the app; [refused] are refused it (E4d-2: the
/// app hides the button and the provider throws), and the rules suite
/// replays it as them expecting a refusal.
Future<void> _record(FakeFirebaseFirestore fs, String name, List<String> roles, Future<void> Function() run,
    {List<String> refused = const []}) async {
  final before = await _snapshot(fs);
  await run();
  await settle();
  final after = await _snapshot(fs);
  final autoIds = <String, String>{};
  final changes = <Map<String, Object?>>[];
  for (final path in {...before.keys, ...after.keys}) {
    final b = before[path], a = after[path];
    if (jsonEncode(b) == jsonEncode(a)) continue;
    final increments = <String, num>{
      if (a != null && b != null)
        for (final k in a.keys)
          if (a[k] is num && b[k] is num && a[k] != b[k]) k: (a[k] as num) - (b[k] as num),
    };
    changes.add({'path': _stablePath(path, autoIds), 'before': b, 'after': a, if (increments.isNotEmpty) 'increments': increments});
  }
  changes.sort((x, y) => (x['path'] as String).compareTo(y['path'] as String));
  // No separate seed: the replay seeds each change's "before" (the rules
  // read only those documents, plus the users and the facility).
  _flows.add({'name': name, 'roles': roles, 'refused': refused, 'changes': changes});
}

// The writes are done; only the activity entry is left, which asks
// Firebase for the app (ActivityLogger): none in a unit test.
Future<void> _ignoringActivityLog(Future<void> Function() run) async {
  try {
    await run();
  } catch (e) {
    if (!'$e'.contains('no-app')) rethrow;
  }
}

/// A repayment as AddPaymentScreen._save writes it
/// (lib/screens/debtors/add_payment_screen.dart, the batch): the payment,
/// the client's balance down, the debt down (deleted at 0), and the record
/// through Sale.applyPayment / Service.copyWith(totalPaid), with toMap().
Future<void> _repay(FakeFirebaseFirestore fs, {required String debtId, required double amount, required String paymentId}) async {
  final debtRef = facilityCollection(fs, Collections.debts).doc(debtId);
  final debt = (await debtRef.get()).data()!;
  final batch = fs.batch();
  batch.set(facilityCollection(fs, Collections.payments).doc(paymentId), {
    'clientId': debt['clientId'], 'clientName': debt['clientName'], 'clientNameLower': '${debt['clientName']}'.toLowerCase(),
    'debtId': debtId, 'saleId': debt['saleId'], 'serviceId': debt['serviceId'], 'items': const [],
    'amount': amount, 'timestamp': FieldValue.serverTimestamp(), 'paidById': testUserId,
    'source': 'debt_repayment', 'paymentMethod': 'Cash',
  });
  batch.update(facilityCollection(fs, Collections.clients).doc(debt['clientId'] as String), {'balance': FieldValue.increment(-amount)});
  final remaining = (debt['amountOwed'] as num) - amount;
  remaining <= 0 ? batch.delete(debtRef) : batch.update(debtRef, {'amountOwed': remaining});
  if (debt['saleId'] != null) {
    final ref = facilityCollection(fs, Collections.sales).doc(debt['saleId'] as String);
    batch.update(ref, Sale.fromFirestore((await ref.get()).data(), ref.id).applyPayment(amount).toMap());
  } else {
    final ref = facilityCollection(fs, Collections.services).doc(debt['serviceId'] as String);
    final service = Service.fromFirestore((await ref.get()).data()!, ref.id);
    batch.update(ref, service.copyWith(totalPaid: service.totalPaid + amount, updatedAt: DateTime.now()).toMap());
  }
  await batch.commit();
}

void main() {
  test('capture the app\'s write shapes for sales, services, debts, payments, clients, stock and Trash', () async {
    final fs = newFakeFirestore();
    await seedProduct(fs, id: 'p1', batchQty: {'b1': 10, 'b2': 10});
    await seedClient(fs, id: 'c1');
    await seedClient(fs, id: 'c2', name: 'Neema', phone: '0713000000');
    await seedClient(fs, id: 'c3', name: 'Baraka', phone: '0714000000');
    final sales = newSaleProvider(fs);
    final services = newServiceProvider(fs);

    await _record(fs, 'addSale cash, walk-in', _everyone,
        () => sales.addSale(testSale(id: 'cash1', items: [saleItem('p1', 2)]), testFacilityId));
    await _record(fs, 'addSale credit, nothing paid', _everyone,
        () => sales.addSale(testSale(id: 'credit1', items: [saleItem('p1', 1)], paid: 0, clientId: 'c1', clientName: 'Juma'), testFacilityId));
    await _record(fs, 'addSale partly paid', _everyone,
        () => sales.addSale(testSale(id: 'part1', items: [saleItem('p1', 3)], paid: 2000, clientId: 'c1', clientName: 'Juma'), testFacilityId));
    await _record(fs, 'payment on a sale debt, partial', _everyone,
        () => _repay(fs, debtId: 'sale_part1', amount: 1000, paymentId: 'pay1'));
    await _record(fs, 'payment on a sale debt, settles it', _everyone,
        () => _repay(fs, debtId: 'sale_part1', amount: 3000, paymentId: 'pay2'));
    await _record(fs, 'addService stock item + external item, partly paid', _everyone,
        () => services.addService(testService(id: 'v1', total: 10000, paid: 4000, clientId: 'c2', clientName: 'Neema',
            items: [serviceItem('Dawa', productId: 'p1'), serviceItem('Gloves', price: 700)])));
    await _record(fs, 'payment on a service debt, partial', _everyone,
        () => _repay(fs, debtId: 'service_v1', amount: 1000, paymentId: 'pay3'));
    // Edit Service (admin-only since E4d-2): the total goes up, so the debt
    // is rewritten with a HIGHER amountOwed. No external item, so no
    // expense transaction is deleted.
    await services.addService(testService(id: 'v2', total: 5000, paid: 0, clientId: 'c2', clientName: 'Neema'));
    await settle();
    await _record(fs, 'updateService raises the unpaid amount (Edit Service)', _admins, refused: ['assistant'],
        () => _ignoringActivityLog(
            () => services.updateService(testService(id: 'v2', total: 8000, paid: 0, clientId: 'c2', clientName: 'Neema'))));
    await _record(fs, 'deleteSale credit (to Trash)', _admins, () => sales.deleteSale('credit1', testFacilityId));
    await _record(fs, 'restoreSale credit (from Trash)', _admins,
        () => restoreFromTrash(fs, Collections.trashSales, Collections.sales, 'credit1'));
    await _record(fs, 'deleteService (to Trash)', _admins, () => services.deleteService('v1'));
    await _record(fs, 'restoreService (from Trash)', _admins,
        () => restoreFromTrash(fs, Collections.trashServices, Collections.services, 'v1'));
    await _record(fs, 'deleteClient with no debt (to Trash)', _admins,
        () => newClientProvider(fs).deleteClient(testFacilityId, 'c3'));

    // ---- E4d-2 ----
    await _record(fs, 'payment on a service debt, settles it', _everyone,
        () => _repay(fs, debtId: 'service_v2', amount: 8000, paymentId: 'pay4'));
    // Edit Service on a service with an external item: its expense is
    // deleted and written again (_handleServiceTransaction).
    await services.addService(testService(id: 'v3', total: 6000, paid: 6000, items: [serviceItem('Gloves', price: 700)]));
    await settle();
    await _record(fs, 'updateService with an external item (Edit Service)', _admins, refused: ['assistant'],
        () => _ignoringActivityLog(() => services.updateService(
            testService(id: 'v3', total: 6000, paid: 6000, items: [serviceItem('Gloves', price: 900)]))));

    final transactions = TransactionProvider(firestore: fs, currentUserInfo: testUserInfo, isAdmin: () => true);
    TransactionModel expense(String description, double amount) => TransactionModel(
        id: '', date: DateTime.now(), description: description, amount: amount, type: 'expense',
        category: 'Transport', recordedBy: testUserName);
    await _record(fs, 'addTransaction, the first expense (its counter is created)', _everyone,
        () => _ignoringActivityLog(() => transactions.addTransaction(expense('Fuel', 3000), testFacilityId)));
    await _record(fs, 'addTransaction, the next expense (its counter goes up)', _everyone,
        () => _ignoringActivityLog(() => transactions.addTransaction(expense('Water', 1000), testFacilityId)));
    // As AddTransactionScreen builds it: same id, date and recordedBy, the
    // form's fields, and no receiptNumber (the edit drops it).
    final fuel = (await facilityCollection(fs, Collections.transactions).where('description', isEqualTo: 'Fuel').get()).docs.single;
    final edited = TransactionModel(
        id: fuel.id, date: (fuel.data()['date'] as Timestamp).toDate(), description: 'Fuel to the farm', amount: 3500,
        type: 'expense', category: 'Transport', recordedBy: fuel.data()['recordedBy'] as String);
    await _record(fs, 'updateTransaction (Edit Transaction)', _admins, refused: ['assistant'],
        () => _ignoringActivityLog(() => transactions.updateTransaction(edited, testFacilityId)));
    await _record(fs, 'deleteTransaction (to Trash)', _admins, refused: ['assistant'],
        () => _ignoringActivityLog(() => transactions.deleteTransaction(testFacilityId, fuel.id)));

    final products = ProductProvider(firestore: fs);
    await _record(fs, 'addProduct with its first batch (Add Product)', _admins, refused: ['assistant'],
        () => products.addProduct(Product(
            id: '', name: 'Dewormer', batchNo: 'D1', expiry: DateTime(2030, 6, 1), buyPrice: 1500, sellPrice: 2500,
            stockQty: 10, unit: 'pcs', type: 'Medicine', category: 'Dewormers', facilityId: testFacilityId)));
    await _record(fs, 'addBatch to an existing product (Add Batch)', _everyone,
        () => products.addBatch(facilityId: testFacilityId, productId: 'p1', batchNo: 'B9',
            expiry: DateTime(2031, 1, 1), buyPrice: 1100, stockQty: 5));

    // One document change per line, so a diff shows what moved.
    final shape = [
      '{"note": "Generated by test/providers/write_shapes_capture_test.dart; do not edit by hand. Paths are under facilities/{facility}.",',
      ' "flows": [',
      for (var i = 0; i < _flows.length; i++) ...[
        '  {"name": ${jsonEncode(_flows[i]['name'])}, "roles": ${jsonEncode(_flows[i]['roles'])}, "refused": ${jsonEncode(_flows[i]['refused'])}, "changes": [',
        for (final (j, c) in (_flows[i]['changes'] as List).indexed)
          '   ${jsonEncode(c)}${j == (_flows[i]['changes'] as List).length - 1 ? '' : ','}',
        '  ]}${i == _flows.length - 1 ? '' : ','}',
      ],
      ' ]}',
    ].join('\n');
    final file = File(_fixture);
    if (_write) {
      file.writeAsStringSync('$shape\n');
      return;
    }
    // Structure only (which flows, documents, fields): values hold clocks.
    Object? structure(Object? json) => (json as Map)['flows'] is List
        ? [
            for (final f in (json['flows'] as List).cast<Map>())
              [f['name'], f['roles'], f['refused'], for (final c in (f['changes'] as List).cast<Map>()) [c['path'], (c['before'] as Map?)?.keys.toList()?..sort(), (c['after'] as Map?)?.keys.toList()?..sort()]]
          ]
        : null;
    expect(file.existsSync(), isTrue, reason: 'run with --dart-define=WRITE_SHAPES=true to create $_fixture');
    expect(structure(jsonDecode(shape)), structure(jsonDecode(file.readAsStringSync())),
        reason: 'the app\'s write shapes changed: rerun with --dart-define=WRITE_SHAPES=true and replay them in the rules suite');
  });
}
