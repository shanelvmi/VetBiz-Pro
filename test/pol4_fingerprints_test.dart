// POL4: the screens of group 3 that had no wide fingerprint yet (the Sales
// and Services archives, with a row's details panel open, and the two
// receipt previews) are recorded on the code before POL4 (the pol4- names in
// test/fixtures/ph5a_wide_fingerprints.json) at 768x1024, 1024x768 and
// 1200x800. The Sales and Services lists, Add Sale and Record Visit are
// already fingerprinted (ph5a_wide_unchanged, ph6_wide_forms_unchanged).
// The fingerprint holds the widget types, the texts and every box's size and
// place, not colours or shadows: a pill that becomes a dot changes it, and
// the commit that does so re-records it and says why.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/sale.dart';
import 'package:vetbiz_pro/models/service.dart';
import 'package:vetbiz_pro/screens/sales/receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_archive_screen.dart';
import 'package:vetbiz_pro/screens/services/service_receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/services/services_archive_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';

/// Inside the archive's default window (180 to 270 days back).
final _sales = [
  Ph5Sale('s1', ph5When(200), client: 'Amina Juma', amount: 45000, paid: 20000, receipt: 2),
  Ph5Sale('s2', ph5When(210), amount: 12500, paid: 0, receipt: 3),
  Ph5Sale('s3', ph5When(220), client: 'Baraka Mushi', amount: 8000, paid: 8000, seller: 'Juma', receipt: 4),
];

final _services = [
  Ph5Service('v1', ph5When(200), client: 'Amina Juma', amount: 45000, paid: 20000, category: 'Vaccination', method: 'mpesa', receipt: 2),
  Ph5Service('v2', ph5When(210), amount: 15000, paid: 0, receipt: 3),
  Ph5Service('v3', ph5When(220), client: 'Baraka Mushi', amount: 9000, paid: 9000, category: 'Consultation', receipt: 4),
];

/// Seeds [_sales] and [_services] as the archive holds them: written as the
/// lists store them, then moved to the archive collections.
Future<void> seedPol4Archives(FirebaseFirestore fs) async {
  await ph5SeedSales(fs, _sales);
  await ph5SeedServices(fs, _services);
  final f = fs.collection(Collections.facilities).doc(testFacilityId);
  for (final (from, to) in [
    (Collections.sales, Collections.archivedSales),
    (Collections.services, Collections.archivedServices),
  ]) {
    for (final doc in (await f.collection(from).get()).docs) {
      await f.collection(to).doc(doc.id).set(doc.data());
      await doc.reference.delete();
    }
  }
}

/// A part-paid sale and an unpaid service (the receipt panels' two
/// non-paid wordings).
final pol4Sale = Sale(
  id: 's1',
  clientName: 'Amina Juma',
  timestamp: DateTime(2026, 10, 26, 9),
  updatedAt: DateTime(2026, 10, 26, 9),
  items: [SaleItem(productId: 'p1', name: 'Albendazole', quantity: 2, unitPrice: 22500, unit: 'pcs')],
  totalAmount: 45000,
  totalPaid: 20000,
  facilityId: testFacilityId,
  soldById: 'u1',
  soldByName: 'Asha',
  receiptNumber: 2,
);

final pol4Service = Service(
  id: 'v1',
  category: 'Consultation',
  name: 'Farm visit',
  description: '',
  clientName: 'Baraka Mushi',
  totalAmount: 15000,
  totalPaid: 0,
  serviceDate: DateTime(2026, 10, 26, 9),
  providedByName: 'Asha',
  receiptNumber: 3,
  itemsUsed: const [],
);

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void main() {
  final archives = <String, (Widget Function(FirebaseFirestore fs), Type, String)>{
    'sales-archive': ((fs) => SalesArchiveScreen(firestore: fs), SalesArchiveScreen, 'Amina Juma'),
    'services-archive': ((fs) => ServicesArchiveScreen(firestore: fs), ServicesArchiveScreen, 'Amina Juma'),
  };
  for (final e in archives.entries) {
    final (build, type, rowText) = e.value;
    for (final size in ph5WideSizes) {
      final where = 'pol4-${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: the archive and its details panel', (tester) async {
        await pumpPh5(tester, build, size: size, pushed: true, seed: seedPol4Archives);
        await ph5SettleUntil(tester, () => find.text(rowText).evaluate().isNotEmpty, what: 'the archived rows');
        expectSameFingerprint('$where-list', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
        await tester.tap(find.text(rowText).first);
        await ph5Settle(tester);
        expectSameFingerprint('$where-details', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      });
    }
  }

  final receipts = <String, (Widget Function(FirebaseFirestore fs), Type)>{
    'receipt-sale': ((_) => ReceiptPreviewScreen(sale: pol4Sale), ReceiptPreviewScreen),
    'receipt-service': ((_) => ServiceReceiptPreviewScreen(service: pol4Service), ServiceReceiptPreviewScreen),
  };
  for (final e in receipts.entries) {
    final (build, type) = e.value;
    for (final size in ph5WideSizes) {
      final where = 'pol4-${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: the receipt preview and its panels', (tester) async {
        await pumpPh5(tester, build, size: size, pushed: true, look: MatrixLook.light);
        expectSameFingerprint(where, '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      });
    }
  }
}
