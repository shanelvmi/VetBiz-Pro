// E3 (RUNBOOK2 section 4): deleting a client moves them to Trash in one
// step, is refused while they still owe money, and a restore brings them
// back exactly as they were, balance included, without touching debts.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/client_delete_refusal.dart';
import 'package:vetbiz_pro/models/restore_outcome.dart';

import '../helpers/fake_firestore.dart';

const _skip = 'E3: until the delete to Trash lands';

/// Client c1 as the app stores one, with [balance] (negative: credit).
Future<FakeFirebaseFirestore> withClient({double balance = 0}) async {
  final fs = newFakeFirestore();
  await facilityCollection(fs, Collections.clients).doc('c1').set({
    'name': 'Juma',
    'nameLower': 'juma',
    'phone': '0712000000',
    'phoneKey': '712000000',
    'balance': balance,
    'types': ['Farmer'],
    'notes': 'Dairy cows',
  });
  return fs;
}

Future<void> deleteClient(FakeFirebaseFirestore fs, String id) async {
  await newClientProvider(fs).deleteClient(testFacilityId, id);
  await settle();
}

Future<RestoreResult> restoreClient(FakeFirebaseFirestore fs, String id) async {
  final result = await restoreFromTrash(fs, Collections.trashClients, Collections.clients, id);
  await settle();
  return result;
}

Future<Map<String, dynamic>?> clientData(FakeFirebaseFirestore fs) async =>
    (await facilityCollection(fs, Collections.clients).doc('c1').get()).data();

Future<Map<String, dynamic>?> trashCopy(FakeFirebaseFirestore fs) async =>
    (await facilityCollection(fs, Collections.trashClients).doc('c1').get()).data();

void main() {
  test('delete moves the client to Trash with deletedAt, deletedBy, and one activity entry', () async {
    final fs = await withClient();
    final before = await clientData(fs);

    await deleteClient(fs, 'c1');

    expect(await clientData(fs), isNull);
    final copy = await trashCopy(fs);
    expect(copy, isNotNull, reason: 'the delete leaves a trash copy');
    expect(copy!['deletedBy'], testUserEmail);
    expect(copy['deletedAt'], isNotNull);
    expect(Map.of(copy)..remove('deletedAt')..remove('deletedBy'), before);
    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs.where((d) => d.id.startsWith('delete_client_c1_')).length, 1);
  }, skip: _skip);

  test('a client with a balance above zero is refused, naming the amount, and nothing is written', () async {
    final fs = await withClient(balance: 5000);
    final before = storedData(fs);

    await expectLater(
      newClientProvider(fs).deleteClient(testFacilityId, 'c1'),
      throwsA(isA<ClientDeleteRefusedException>().having((e) => e.owed, 'owed', 5000)),
    );
    await settle();

    expect(storedData(fs), before);
  }, skip: _skip);

  test('a client with a debts document is refused even at balance 0, and nothing is written', () async {
    final fs = await withClient();
    await facilityCollection(fs, Collections.debts).doc('sale_s1').set({'clientId': 'c1', 'amountOwed': 3000});
    final before = storedData(fs);

    await expectLater(
      newClientProvider(fs).deleteClient(testFacilityId, 'c1'),
      throwsA(isA<ClientDeleteRefusedException>().having((e) => e.owed, 'owed', 3000)),
    );
    await settle();

    expect(storedData(fs), before);
  }, skip: _skip);

  test('a second delete of the same client writes nothing and keeps the first trash copy', () async {
    final fs = await withClient();
    await deleteClient(fs, 'c1');
    final afterFirst = storedData(fs);
    expect(await trashCopy(fs), isNotNull, reason: 'the first delete leaves a trash copy');

    await deleteClient(fs, 'c1');

    expect(storedData(fs), afterFirst);
  }, skip: _skip);

  test('restore brings the client back exactly, with the same balance, and touches no debt', () async {
    final fs = await withClient(balance: -1500);
    await facilityCollection(fs, Collections.debts).doc('sale_other').set({'clientId': 'c2', 'amountOwed': 700});
    final before = await clientData(fs);
    await deleteClient(fs, 'c1');

    final result = await restoreClient(fs, 'c1');

    expect(result, RestoreResult.restored);
    expect(await clientData(fs), before);
    expect((await clientData(fs))!['balance'], -1500);
    expect(await trashCopy(fs), isNull);
    expect(await countDocs(fs, Collections.debts), 1);
    final logs = await facilityCollection(fs, Collections.activityLogs).get();
    expect(logs.docs.where((d) => d.id.startsWith('restore_client_c1_')).length, 1);
  }, skip: _skip);

  test('a second restore (a retry, a double tap) writes nothing', () async {
    final fs = await withClient();
    await deleteClient(fs, 'c1');
    await restoreClient(fs, 'c1');
    final afterFirst = storedData(fs);

    final result = await restoreClient(fs, 'c1');

    expect(result, RestoreResult.alreadyRestored);
    expect(storedData(fs), afterFirst);
  }, skip: _skip);
}
