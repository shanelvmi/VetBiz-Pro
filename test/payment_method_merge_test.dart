import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/payment_methods.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/providers/payment_provider.dart';
import 'package:vetbiz_pro/services/daily_report_service.dart';

// R3, D5: one name, "Mixx by Yas". A record stored as 'Tigo Pesa' is shown,
// filtered and grouped as Mixx by Yas; the stored key never changes.
void main() {
  const tigo = 'Tigo Pesa';
  const mixx = 'Mixx by Yas';

  test('a stored Tigo Pesa key is shown as Mixx by Yas; others are unchanged', () {
    expect(PaymentMethod.shownKey(tigo), mixx);
    for (final k in ['Cash', 'M-Pesa', mixx, 'HaloPesa', 'Airtel Money', 'Bank Transfer', 'On Credit', 'Barter', '']) {
      expect(PaymentMethod.shownKey(k), k);
    }
    expect(PaymentMethod.storedKeysFor(mixx), [mixx, tigo]);
    expect(PaymentMethod.storedKeysFor('Cash'), ['Cash']);
    expect(PaymentMethod.shownChoices([tigo, 'Cash', mixx, tigo]), ['Cash', mixx]);
    // Never offered as its own choice.
    expect(PaymentMethod.recordable, isNot(contains(PaymentMethod.tigoPesa)));
    expect(PaymentMethod.subscription, isNot(contains(PaymentMethod.tigoPesa)));
  });

  test('an old report that stored both keys shows one Mixx by Yas row, summed', () {
    final sales = {'Cash': 500.0, tigo: 1000.0, mixx: 2500.0};
    expect(PaymentMethod.mergeShown(sales), {'Cash': 500.0, mixx: 3500.0});
    expect(PaymentMethod.combineShown([sales, {tigo: 100.0}, {'M-Pesa': 50.0}]),
        {'Cash': 500.0, mixx: 3600.0, 'M-Pesa': 50.0});
    expect(sales.keys, contains(tigo), reason: 'the input map is not changed');
  });

  test('the breakdown, its PDF and the full view read every by-method map merged', () {
    for (final path in [
      'lib/screens/reports/report_full_view_screen.dart',
      'lib/screens/reports/report_tabbed_content.dart',
      'lib/services/daily_report_pdf_service.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(RegExp(r'(?<!mergeShown\()report\.\w+ByPaymentMethod\.entries').hasMatch(src), isFalse,
          reason: '$path iterates a by-method map without merging it');
      expect(src.contains('combined[entry.key]'), isFalse, reason: '$path sums by stored key');
      expect(src.contains('PaymentMethod.combineShown(['), isTrue, reason: path);
    }
  });

  group('with one Tigo Pesa and one Mixx by Yas payment today', () {
    late FakeFirebaseFirestore fs;
    const facilityId = 'facility1';

    CollectionReference<Map<String, dynamic>> payments() =>
        fs.collection(Collections.facilities).doc(facilityId).collection(Collections.payments);

    setUp(() async {
      fs = FakeFirebaseFirestore();
      final earlier = Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 5)));
      await payments().doc('p1').set({'source': 'sale', 'amount': 1000, 'paymentMethod': tigo, 'timestamp': earlier});
      await payments().doc('p2').set({'source': 'sale', 'amount': 2500, 'paymentMethod': mixx, 'timestamp': earlier});
      await payments().doc('p3').set({'source': 'sale', 'amount': 700, 'paymentMethod': 'Cash', 'timestamp': earlier});
    });

    test('the daily report groups them as one Mixx by Yas row and one count, keys unchanged', () async {
      final report = await DailyReportService(firestore: fs)
          .generateDraftReport(facilityId: facilityId, generatedByName: 'Asha');

      expect(report.salesByPaymentMethod, {mixx: 3500.0, 'Cash': 700.0});
      final methods = report.paymentReconciliation.map((p) => p.method).toList();
      expect(methods, ['Cash', mixx], reason: 'one reconciliation row for the review screen');
      expect(report.paymentReconciliation.firstWhere((p) => p.method == mixx).expected, 3500.0);
      // The payment records keep what they stored.
      expect((await payments().doc('p1').get()).data()!['paymentMethod'], tigo);
    });

    test('the Payments filter on Mixx by Yas finds both; Cash finds only cash', () async {
      final both = await PaymentProvider.whereShownMethod(payments(), mixx).get();
      expect(both.docs.map((d) => d.id).toSet(), {'p1', 'p2'});
      final cash = await PaymentProvider.whereShownMethod(payments(), 'Cash').get();
      expect(cash.docs.map((d) => d.id).toList(), ['p3']);
    });
  });
}
