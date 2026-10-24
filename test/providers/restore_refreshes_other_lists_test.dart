// BUG-1 (RUNBOOK2 ledger), the other things that go to Trash: a product, a
// transaction and a client, deleted and restored through the same calls the
// app makes (the Trash screen's TrashService.restore, the Undo's
// TrashService.restoreById), must leave and come back to their lists at
// once, in their place, with the real providers on the fake Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/client_provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';

import '../helpers/fake_firestore.dart';

final _yesterday = DateTime.now().subtract(const Duration(days: 1));

/// The facility the screens pass to ProductProvider.deleteProduct.
class _TestFacility extends FacilityProvider {
  @override
  String? get selectedFacilityId => testFacilityId;
}

Future<void> restoreByUndo(FakeFirebaseFirestore fs, String trash, String live, String id) async {
  await restoreFromTrash(fs, trash, live, id);
  await settleLists();
}

void main() {
  group('Products list (live)', () {
    for (final viaUndo in [false, true]) {
      testWidgets('delete, then restore ${viaUndo ? 'by Undo' : 'from the Trash screen'}: back at once, in its place',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fs = newFakeFirestore();
        late BuildContext context;
        await tester.pumpWidget(ChangeNotifierProvider<FacilityProvider>(
          create: (_) => _TestFacility(),
          child: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          }),
        ));
        await tester.runAsync(() async {
          for (final id in ['p1', 'p2', 'p3', 'p4']) {
            await seedProduct(fs, id: id, legacyQty: 5);
          }
          final products = ProductProvider(firestore: fs, currentUserInfo: testUserInfo)..listenToProducts(testFacilityId);
          await settleLists();
          List<String> shown() => [for (final p in products.products) p.id];
          expect(shown(), ['p1', 'p2', 'p3', 'p4']);

          await products.deleteProduct(context, 'p2');
          await settleLists();
          expect(shown(), ['p1', 'p3', 'p4']);

          viaUndo
              ? await restoreByUndo(fs, Collections.trashProducts, Collections.products, 'p2')
              : await restoreFromTrashScreen(fs, Collections.trashProducts, Collections.products, 'p2');
          expect(shown(), ['p1', 'p2', 'p3', 'p4']);
        });
      });
    }
  });

  group('Transactions list (a live window and older pages) and Payments', () {
    // 30 transactions, t01 (oldest) to t30: the live window holds the newest
    // 25, so t02 is on an older page. t02 is other income, which the
    // Payments ledger lists too.
    Future<(TransactionProvider, PaymentProvider)> thirtyTransactions(FakeFirebaseFirestore fs) async {
      for (var n = 1; n <= 30; n++) {
        await facilityCollection(fs, Collections.transactions).doc('t${'$n'.padLeft(2, '0')}').set({
          'date': Timestamp.fromDate(_yesterday.add(Duration(minutes: n))),
          'description': 'Item $n',
          'amount': 100.0 * n,
          'type': n == 2 ? 'other income' : 'expense',
          'category': 'Other',
          'recordedBy': testUserName,
          'paymentMethod': 'Cash',
        });
      }
      final transactions = TransactionProvider(firestore: fs, currentUserInfo: testUserInfo, isAdmin: () => true)
        ..listenToTransactions(testFacilityId);
      await settleLists();
      await transactions.loadMoreTransactions();
      final payments = PaymentProvider(firestore: fs);
      await payments.ledgerController.openSession(
        querySignature: payments.updateLedgerFilters(
            facilityId: testFacilityId, searchTerm: '', typeFilter: null, methodFilter: null, initialClientId: null),
        rangeStart: DateTime(_yesterday.year, _yesterday.month, _yesterday.day),
        rangeEnd: DateTime.now(),
      );
      return (transactions, payments);
    }

    List<String> oldest(TransactionProvider p) => [for (final t in p.transactions.reversed.take(3)) t.id];
    List<String> ledger(PaymentProvider p) => [for (final e in p.ledgerController.entries) e.sortId];

    for (final viaUndo in [false, true]) {
      test('delete, then restore ${viaUndo ? 'by Undo' : 'from the Trash screen'}: back at once, in its place',
          () async {
        final fs = newFakeFirestore();
        final (transactions, payments) = await thirtyTransactions(fs);
        expect(transactions.transactions, hasLength(30));
        expect(oldest(transactions), ['t01', 't02', 't03']);
        expect(ledger(payments), ['t02']);

        await transactions.deleteTransaction(testFacilityId, 't02');
        await settleLists();
        expect(transactions.transactions.map((t) => t.id), isNot(contains('t02')));
        expect(ledger(payments), isEmpty);

        viaUndo
            ? await restoreByUndo(fs, Collections.trashTransactions, Collections.transactions, 't02')
            : await restoreFromTrashScreen(fs, Collections.trashTransactions, Collections.transactions, 't02');
        // The older pages start over from the live window; the restored one
        // is back in its place when they are loaded again.
        await transactions.loadMoreTransactions();
        await settleLists();
        expect(oldest(transactions), ['t01', 't02', 't03']);
        expect(transactions.transactions, hasLength(30));
        expect(ledger(payments), ['t02']);
      });
    }
  });

  group('Clients list', () {
    Future<ClientProvider> fourClients(FakeFirebaseFirestore fs) async {
      for (var n = 1; n <= 4; n++) {
        await facilityCollection(fs, Collections.clients).doc('c$n').set({
          'name': 'Client $n',
          'nameLower': 'client $n',
          'phone': '071200000$n',
          'balance': 0,
          'createdAt': Timestamp.fromDate(_yesterday.add(Duration(hours: n))),
        });
      }
      final clients = newClientProvider(fs);
      await clients.clientsListController.openSession(clients.updateClientsListFilters(
          facilityId: testFacilityId, searchTerm: '', typeFilter: 'All', statusFilter: 'All'));
      return clients;
    }

    List<String> shown(ClientProvider p) => [for (final c in p.clientsListController.items) c.id];

    test('a deleted client leaves the list at once', () async {
      final fs = newFakeFirestore();
      final clients = await fourClients(fs);
      expect(shown(clients), ['c4', 'c3', 'c2', 'c1']);

      await clients.deleteClient(testFacilityId, 'c2');
      await settleLists();
      expect(shown(clients), ['c4', 'c3', 'c1']);
    });

    for (final viaUndo in [false, true]) {
      test('restored ${viaUndo ? 'by Undo' : 'from the Trash screen'}: back at once, in its place', () async {
        final fs = newFakeFirestore();
        final clients = await fourClients(fs);
        await deleteAsOnScreen(clients.deleteClient(testFacilityId, 'c2'), clients.clientsListController.refreshSession);
        expect(shown(clients), ['c4', 'c3', 'c1']);

        viaUndo
            ? await restoreByUndo(fs, Collections.trashClients, Collections.clients, 'c2')
            : await restoreFromTrashScreen(fs, Collections.trashClients, Collections.clients, 'c2');
        expect(shown(clients), ['c4', 'c3', 'c2', 'c1']);
      });
    }
  });
}
