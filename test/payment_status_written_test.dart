// E4d-3 (2): a payment refreshes the stored paymentStatus that the Sales and
// Services Paid/Partial/Unpaid filters query. AddPaymentScreen writes
// Service.copyWith(totalPaid).toMap() and Sale.applyPayment(amount).toMap();
// paymentStatus was only in searchFields(), so after a payment the record
// kept its old status. lib/data/payment_status.dart says both toMap()s write it.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/payment_status.dart';

import 'helpers/fake_firestore.dart';

const String? _skip = null;

void main() {
  test('a service payment writes the new paymentStatus (as AddPaymentScreen writes it)', () {
    final service = testService(id: 'v1', total: 10000, paid: 4000, clientId: 'c2', clientName: 'Neema');
    Object? paying(double amount) =>
        service.copyWith(totalPaid: service.totalPaid + amount, updatedAt: DateTime.now()).toMap()['paymentStatus'];
    expect([paying(1000), paying(6000)], [PaymentStatus.partial, PaymentStatus.paid]);
    expect(testService(id: 'v2', total: 5000, paid: 0).toMap()['paymentStatus'], PaymentStatus.unpaid);
  }, skip: _skip);

  test('a sale payment writes the new paymentStatus (as AddPaymentScreen writes it)', () {
    final sale = testSale(id: 's1', items: [saleItem('p1', 3)], paid: 2000, clientId: 'c1', clientName: 'Juma');
    expect([sale.applyPayment(1000).toMap()['paymentStatus'], sale.applyPayment(4000).toMap()['paymentStatus']],
        [PaymentStatus.partial, PaymentStatus.paid]);
    expect(testSale(id: 's2', items: [saleItem('p1', 1)], paid: 0).toMap()['paymentStatus'], PaymentStatus.unpaid);
  }, skip: _skip);

  test('toMap and searchFields agree on paymentStatus (one rule, PaymentStatus.of)', () {
    final service = testService(id: 'v1', total: 10000, paid: 4000);
    final sale = testSale(id: 's1', items: [saleItem('p1', 3)], paid: 6000);
    expect(service.toMap()['paymentStatus'], service.searchFields()['paymentStatus']);
    expect(sale.toMap()['paymentStatus'], sale.searchFields()['paymentStatus']);
  }, skip: _skip);
}
