// BUG-1 (RUNBOOK2 ledger): after a sale or a service was deleted and
// restored, every total came back but the Sales (and Services) list kept
// showing 3 records instead of 4 until the next sign-in. The list pages are
// fetched once and kept in the app's own SaleProvider/ServiceProvider for
// the session, and nothing told them about a restore.
//
// These use the real providers on the fake Firestore and restore through the
// same calls the app makes: the Trash screen (TrashService.restore with the
// trash document's data) and the Undo on the delete message (the provider's
// restoreSale/restoreService, which the screen's Undo runs).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/client_provider.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/providers/sale_provider.dart';
import 'package:vetbiz_pro/providers/service_provider.dart';

import '../helpers/fake_firestore.dart';

const _bug1 = 'BUG-1: un-skipped by the fix';

final _yesterday = DateTime.now().subtract(const Duration(days: 1));

/// The n-th record's time: s1 is the oldest, s4 the newest.
DateTime _at(int n) => _yesterday.add(Duration(hours: n));

/// Four cash sales, s1 (oldest) to s4, and the Sales list opened as the
/// Sales screen opens it.
Future<SaleProvider> fourSales(FakeFirebaseFirestore fs) async {
  await seedProduct(fs, id: 'p1', batchQty: {'b1': 50});
  final sales = newSaleProvider(fs)..init(testFacilityId);
  for (var n = 1; n <= 4; n++) {
    await sales.addSale(testSale(id: 's$n', items: [saleItem('p1', 1)]).copyWith(timestamp: _at(n)), testFacilityId);
  }
  await settleLists();
  await sales.salesListController.openSession(sales.updateSalesListFilters(
      searchTerm: '', statusFilter: 'All', sellerFilter: 'All', dateFilter: 'All time'));
  return sales;
}

List<String> salesShown(SaleProvider p) => [for (final s in p.salesListController.items) s.id];

/// Four services, each with a stock item and an item bought outside, and
/// the Services list opened as the Services screen opens it.
Future<ServiceProvider> fourServices(FakeFirebaseFirestore fs) async {
  await seedProduct(fs, id: 'p1', batchQty: {'b1': 50});
  final services = newServiceProvider(fs);
  for (var n = 1; n <= 4; n++) {
    await services.addService(testService(
      id: 'v$n',
      items: [serviceItem('Dewormer', productId: 'p1'), serviceItem('Syringe', price: 300)],
    ).copyWith(serviceDate: _at(n)));
  }
  await settleLists();
  await services.servicesListController.openSession(services.updateServicesListFilters(
      searchTerm: '', statusFilter: 'All', categoryFilter: 'All', dateFilter: 'Last 30 days'));
  return services;
}

List<String> servicesShown(ServiceProvider p) => [for (final s in p.servicesListController.items) s.id];

void main() {
  group('Sales list', () {
    test('a deleted sale leaves the list at once', () async {
      final fs = newFakeFirestore();
      final sales = await fourSales(fs);
      expect(salesShown(sales), ['s4', 's3', 's2', 's1']);

      await sales.deleteSale('s2', testFacilityId);
      await settleLists();
      expect(salesShown(sales), ['s4', 's3', 's1']);
    }, skip: _bug1);

    test('restored from the Trash screen: back at once, in its place', () async {
      final fs = newFakeFirestore();
      final sales = await fourSales(fs);
      await deleteAsOnScreen(sales.deleteSale('s2', testFacilityId), sales.salesListController.refreshSession);
      expect(salesShown(sales), ['s4', 's3', 's1']);

      await restoreFromTrashScreen(fs, Collections.trashSales, Collections.sales, 's2');
      expect(salesShown(sales), ['s4', 's3', 's2', 's1']);
    }, skip: _bug1);

    test('restored by Undo: back at once, in its place', () async {
      final fs = newFakeFirestore();
      final sales = await fourSales(fs);
      await deleteAsOnScreen(sales.deleteSale('s2', testFacilityId), sales.salesListController.refreshSession);
      expect(salesShown(sales), ['s4', 's3', 's1']);

      await sales.restoreSale('s2', testFacilityId);
      await settleLists();
      expect(salesShown(sales), ['s4', 's3', 's2', 's1']);
    }, skip: _bug1);
  });

  group('Services list (a stock item and an item bought outside)', () {
    test('a deleted service leaves the list at once', () async {
      final fs = newFakeFirestore();
      final services = await fourServices(fs);
      expect(servicesShown(services), ['v4', 'v3', 'v2', 'v1']);

      await services.deleteService('v2');
      await settleLists();
      expect(servicesShown(services), ['v4', 'v3', 'v1']);
    }, skip: _bug1);

    test('restored from the Trash screen: back at once, in its place', () async {
      final fs = newFakeFirestore();
      final services = await fourServices(fs);
      await deleteAsOnScreen(services.deleteService('v2'), services.servicesListController.refreshSession);
      expect(servicesShown(services), ['v4', 'v3', 'v1']);

      await restoreFromTrashScreen(fs, Collections.trashServices, Collections.services, 'v2');
      expect(servicesShown(services), ['v4', 'v3', 'v2', 'v1']);
    }, skip: _bug1);

    test('restored by Undo: back at once, in its place', () async {
      final fs = newFakeFirestore();
      final services = await fourServices(fs);
      await deleteAsOnScreen(services.deleteService('v2'), services.servicesListController.refreshSession);
      expect(servicesShown(services), ['v4', 'v3', 'v1']);

      await services.restoreService('v2', testFacilityId);
      await settleLists();
      expect(servicesShown(services), ['v4', 'v3', 'v2', 'v1']);
    }, skip: _bug1);
  });

  group('A credit sale: Active Debts and Payments', () {
    // A credit sale of 3 x 2000 to Juma, 1000 paid up front: 5000 owed.
    Future<(SaleProvider, ClientProvider, PaymentProvider)> creditSale(FakeFirebaseFirestore fs) async {
      await seedProduct(fs, id: 'p1', batchQty: {'b1': 10});
      await seedClient(fs, id: 'c1', name: 'Juma');
      final sales = newSaleProvider(fs)..init(testFacilityId);
      await sales.addSale(
          testSale(id: 's1', items: [saleItem('p1', 3)], paid: 1000, clientId: 'c1', clientName: 'Juma'),
          testFacilityId);
      await settleLists();
      final clients = newClientProvider(fs);
      await clients.debtorsListController.openSession(clients.updateDebtorsListFilters(
          facilityId: testFacilityId, searchTerm: '', statusFilter: 'All', overdueRangeFilter: 'All', overdueDays: 30));
      final payments = PaymentProvider(firestore: fs);
      final now = DateTime.now();
      await payments.ledgerController.openSession(
        querySignature: payments.updateLedgerFilters(
            facilityId: testFacilityId, searchTerm: '', typeFilter: null, methodFilter: null, initialClientId: null),
        rangeStart: DateTime(now.year, now.month, now.day),
        rangeEnd: now.add(const Duration(hours: 1)),
      );
      return (sales, clients, payments);
    }

    Map<String, double> debtors(ClientProvider p) => {for (final c in p.debtorsListController.items) c.id: c.balance};
    List<double> paymentsShown(PaymentProvider p) => [for (final e in p.ledgerController.entries) e.amount];

    for (final viaUndo in [false, true]) {
      test('delete, then restore ${viaUndo ? 'by Undo' : 'from the Trash screen'}: the debt and the payment are right',
          () async {
        final fs = newFakeFirestore();
        final (sales, clients, payments) = await creditSale(fs);
        expect(debtors(clients), {'c1': 5000});
        expect(paymentsShown(payments), [1000]);

        await sales.deleteSale('s1', testFacilityId);
        await settleLists();
        expect(debtors(clients), isEmpty, reason: 'the debt went with the sale');
        expect(paymentsShown(payments), [1000], reason: 'the upfront payment stays counted');

        if (viaUndo) {
          await sales.restoreSale('s1', testFacilityId);
          await settleLists();
        } else {
          await restoreFromTrashScreen(fs, Collections.trashSales, Collections.sales, 's1');
        }
        expect(debtors(clients), {'c1': 5000});
        expect(paymentsShown(payments), [1000]);
      }, skip: _bug1);
    }
  });
}
