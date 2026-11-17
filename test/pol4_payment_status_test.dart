// POL4 (owner note 1): one function maps a sale's or a service's payment
// status to one of the four states, and it is the mapping the Sales and
// Services lists drew before POL4 (paid success, part paid warning, unpaid
// danger); an unknown value is neutral. The stored values never change.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/payment_status.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';

void main() {
  test('the stored values are unchanged', () {
    expect(PaymentStatus.values, ['Paid', 'Partial', 'Unpaid']);
    expect(PaymentStatus.of(8000, 8000), 'Paid');
    expect(PaymentStatus.of(9000, 8000), 'Paid');
    expect(PaymentStatus.of(20000, 45000), 'Partial');
    expect(PaymentStatus.of(0, 12500), 'Unpaid');
  });

  test('paymentAppStatus: paid success, partial warning, unpaid danger, unknown neutral', () {
    expect(paymentAppStatus(PaymentStatus.paid), AppStatus.success);
    expect(paymentAppStatus(PaymentStatus.partial), AppStatus.warning);
    expect(paymentAppStatus(PaymentStatus.unpaid), AppStatus.danger);
    for (final unknown in ['', 'paid', 'Refunded', 'Cancelled', 'Partly paid']) {
      expect(paymentAppStatus(unknown), AppStatus.neutral, reason: unknown);
    }
    // The receipt panel's three wordings come from the same amounts:
    // balance 0 (paid in full), part paid, nothing paid (balance due).
    expect(paymentAppStatus(PaymentStatus.of(45000, 45000)), AppStatus.success);
    expect(paymentAppStatus(PaymentStatus.of(20000, 45000)), AppStatus.warning);
    expect(paymentAppStatus(PaymentStatus.of(0, 15000)), AppStatus.danger);
  });
}
