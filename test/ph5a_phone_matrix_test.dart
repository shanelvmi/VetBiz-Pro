// PH5a: Sales and Services on phones at 360x740, 390x844 and 740x360, in
// Light, Dark and Kiswahili, with a very long Kiswahili client name and an
// 8-digit amount: no overflow, 48 px targets, no text under 12 px, on the
// list and on the details page (R11). And the cost (R12): a cold open on a
// phone reads what it reads on a computer, and coming back from a details
// page reads nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _seed(dynamic fs) async {
  await ph5SeedSales(fs, [
    Ph5Sale('s1', ph5When(0, minutes: 5), client: matrixLongClientName, amount: matrixBigAmount, paid: 1000, receipt: 1),
    Ph5Sale('s2', ph5When(1), amount: matrixBigAmount, paid: 0, receipt: 2),
    Ph5Sale('s3', ph5When(6), client: 'Amina Juma', amount: 4500, receipt: 3),
  ]);
  await ph5SeedServices(fs, [
    Ph5Service('v1', ph5When(0, minutes: 5), client: matrixLongClientName, amount: matrixBigAmount, paid: 1000, receipt: 1),
    Ph5Service('v2', ph5When(2), amount: 15000, paid: 0, category: 'Preventive', receipt: 2),
  ]);
}

void main() {
  final screens = {
    'Sales': ((dynamic fs) => SalesScreen(firestore: fs, asTab: true), false, 's1'),
    'Services': ((dynamic fs) => ServicesScreen(firestore: fs), true, 'v1'),
  };

  for (final e in screens.entries) {
    final (build, pushed, id) = e.value;
    group('${e.key} phone matrix', () {
      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '${e.key} ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh5(tester, (fs) => build(fs), size: size.size, look: look, pushed: pushed, seed: _seed);
            await checkCase(tester, phone: true, where: '$where list');
            await tester.tap(_key('phoneList-row-$id'));
            await ph5Settle(tester);
            await checkCase(tester, phone: true, where: '$where details');
          }, skip: _skip);
        }
      }
    });
  }

  group('cost (R12), counted on the fake Firestore', () {
    for (final e in screens.entries) {
      final (build, pushed, id) = e.value;
      ph5TestWidgets('${e.key}: a phone opens with the computer\'s listeners and reads; back from details reads nothing',
          (tester) async {
        final counts = <String, (int, int, int)>{};
        for (final size in const [Size(1200, 800), Size(390, 844)]) {
          final db = CountingFirestore();
          await tester.runAsync(() => _seed(db.inner));
          await pumpPh5(tester, (fs) => build(fs), size: size, pushed: pushed, firestore: db);
          counts['${size.width.toInt()}'] = (db.listeners, db.gets, db.reads);
          if (size.width < 600) {
            db.resetCounts();
            await tester.tap(_key('phoneList-row-$id'));
            await ph5Settle(tester);
            await tester.tap(find.byType(BackButton).first);
            await ph5Settle(tester);
            expect((db.gets, db.reads), (0, 0), reason: 'back from the details page');
          }
          await tester.pumpWidget(const SizedBox());
        }
        // ignore: avoid_print
        print('PH5a ${e.key} cold open (listeners, gets, reads): computer ${counts['1200']}, phone ${counts['390']}');
        expect(counts['390'], counts['1200']);
      }, skip: _skip);
    }
  });
}
