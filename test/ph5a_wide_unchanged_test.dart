// PH5a: tablets and computers keep today's Sales and Services exactly. At
// 768x1024, 1024x768 and 1200x800 the whole widget tree under the screen
// (every widget's type, its text with the dates masked, every box's size and
// position) is compared with the fingerprint recorded from the code before
// PH5a (test/fixtures/ph5a_wide_fingerprints.json), once with the list and
// once with a row's details panel open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

final _sales = [
  Ph5Sale('s1', ph5When(0, minutes: 5), client: matrixLongClientName, amount: matrixBigAmount, paid: 0, receipt: 1),
  Ph5Sale('s2', ph5When(0, minutes: 30), client: 'Amina Juma', amount: 45000, paid: 20000, receipt: 2),
  Ph5Sale('s3', ph5When(1), amount: 12500, receipt: 3),
  Ph5Sale('s4', ph5When(3, minutes: 90), client: 'Baraka Mushi', amount: 8000, paid: 8000, seller: 'Juma', receipt: 4),
];

final _services = [
  Ph5Service('v1', ph5When(0, minutes: 5), client: matrixLongClientName, amount: matrixBigAmount, paid: 0, receipt: 1),
  Ph5Service('v2', ph5When(1), client: 'Amina Juma', amount: 45000, paid: 20000, category: 'Vaccination', method: 'mpesa', receipt: 2),
  Ph5Service('v3', ph5When(4), amount: 15000, receipt: 3),
];

/// The first line of every error the frame raised, and none left behind.
String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void main() {
  final screens = <String, (Widget Function(dynamic fs), Type, bool, String)>{
    'sales': ((fs) => SalesScreen(firestore: fs), SalesScreen, true, 'SL-000002'),
    'sales-tab': ((fs) => SalesScreen(firestore: fs, asTab: true), SalesScreen, false, 'SL-000002'),
    'services': ((fs) => ServicesScreen(firestore: fs), ServicesScreen, true, 'Vaccination visit'),
  };
  for (final e in screens.entries) {
    final (build, type, pushed, rowText) = e.value;
    for (final size in ph5WideSizes) {
      final where = '${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('$where: the list and the details panel as before PH5a', (tester) async {
        await pumpPh5(
          tester,
          (fs) => build(fs),
          size: size,
          pushed: pushed,
          seed: (fs) async {
            await ph5SeedSales(fs, _sales);
            await ph5SeedServices(fs, _services);
          },
        );
        // Today's wide layouts may overflow with the matrix's long names
        // (their phone layouts are PH5a's; the wide ones stay as they are):
        // the error is part of what must not change.
        expectSameFingerprint('$where-list', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
        await tester.tap(find.text(rowText).first);
        await ph5Settle(tester);
        expectSameFingerprint('$where-details', '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      }, skip: _skip);
    }
  }
}
