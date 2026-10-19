// E4d-2, owner decision: Edit Service, Edit Transaction and deleting a
// transaction are admin-only. Assistants record, take payments and see
// everything; the owner corrects. The provider refuses an assistant's call
// before it writes anything (AdminOnlyException, shown through
// FriendlyError); the screens hide the buttons and firestore.rules refuses
// the writes (firestore_rules_tests, C4 update, C6 services, C7).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/admin_only_refusal.dart';
import 'package:vetbiz_pro/models/transaction.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';

import '../helpers/fake_firestore.dart';

TransactionProvider _transactions(FirebaseFirestore fs, {required bool admin}) =>
    TransactionProvider(firestore: fs, currentUserInfo: testUserInfo, isAdmin: () => admin);

TransactionModel _expense({double amount = 3000, String description = 'Fuel'}) => TransactionModel(
      id: 't1', date: DateTime(2026, 10, 1), description: description, amount: amount,
      type: 'expense', category: 'Transport', recordedBy: testUserName, receiptNumber: 7,
    );

Future<void> _seedExpense(FakeFirebaseFirestore fs) =>
    facilityCollection(fs, Collections.transactions).doc('t1').set({..._expense().toMap(), ..._expense().searchFields()});

// The writes are done; only the activity entry is left, which asks
// Firebase for the app (ActivityLogger.logActivity): none in a unit test.
Future<void> _ignoringActivityLog(Future<void> call) async {
  try {
    await call;
  } catch (e) {
    if (!'$e'.contains('no-app')) rethrow;
  }
}

Future<void> _seedServiceOnCredit(FakeFirebaseFirestore fs) async {
  await seedClient(fs, id: 'c2', name: 'Neema', phone: '0713000000');
  await newServiceProvider(fs).addService(testService(id: 'v2', total: 5000, paid: 0, clientId: 'c2', clientName: 'Neema'));
  await settle();
}

void main() {
  group('Edit Service (ServiceProvider.updateService)', () {
    test('an assistant is refused and nothing is written: no service, debt, balance or stock change', () async {
      final fs = newFakeFirestore();
      await _seedServiceOnCredit(fs);
      final before = storedData(fs);
      await expectLater(
        newServiceProvider(fs, admin: false)
            .updateService(testService(id: 'v2', total: 8000, paid: 0, clientId: 'c2', clientName: 'Neema')),
        throwsA(isA<AdminOnlyException>()),
      );
      await settle();
      expect(storedData(fs), before);
    });

    test('an admin edits it as before: the service and its debt follow', () async {
      final fs = newFakeFirestore();
      await _seedServiceOnCredit(fs);
      await _ignoringActivityLog(newServiceProvider(fs)
          .updateService(testService(id: 'v2', total: 8000, paid: 0, clientId: 'c2', clientName: 'Neema')));
      await settle();
      expect((await facilityCollection(fs, Collections.services).doc('v2').get()).data()!['totalAmount'], 8000);
      expect((await facilityCollection(fs, Collections.debts).doc('service_v2').get()).data()!['amountOwed'], 8000);
    });
  });

  group('Edit Transaction and delete (TransactionProvider)', () {
    test('an assistant\'s edit is refused and the transaction is unchanged', () async {
      final fs = newFakeFirestore();
      await _seedExpense(fs);
      final before = storedData(fs);
      await expectLater(_transactions(fs, admin: false).updateTransaction(_expense(amount: 1), testFacilityId),
          throwsA(isA<AdminOnlyException>()));
      expect(storedData(fs), before);
    });

    test('an assistant\'s delete is refused: still there, nothing in Trash', () async {
      final fs = newFakeFirestore();
      await _seedExpense(fs);
      final before = storedData(fs);
      await expectLater(_transactions(fs, admin: false).deleteTransaction(testFacilityId, 't1'),
          throwsA(isA<AdminOnlyException>()));
      expect(storedData(fs), before);
    });

    test('an admin edits and deletes as before (the delete goes to Trash)', () async {
      final fs = newFakeFirestore();
      await _seedExpense(fs);
      final admin = _transactions(fs, admin: true);
      await _ignoringActivityLog(admin.updateTransaction(_expense(amount: 3500), testFacilityId));
      expect((await facilityCollection(fs, Collections.transactions).doc('t1').get()).data()!['amount'], 3500);
      await _ignoringActivityLog(admin.deleteTransaction(testFacilityId, 't1'));
      expect((await facilityCollection(fs, Collections.transactions).doc('t1').get()).exists, isFalse);
      expect((await facilityCollection(fs, Collections.trashTransactions).doc('t1').get()).exists, isTrue);
    });
  });

  test('the refusal reads as one friendly sentence, in the chosen language', () {
    expect(FriendlyError.messageFor(const AdminOnlyException()), 'Only an admin can edit or delete this record.');
    addTearDown(() => L10n.setLocale(const Locale('en')));
    L10n.setLocale(const Locale('sw'));
    expect(FriendlyError.messageFor(const AdminOnlyException()), lookupAppLocalizations(const Locale('sw')).error_adminOnly);
  });
}
