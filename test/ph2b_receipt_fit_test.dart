import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/models/sale.dart';
import 'package:vetbiz_pro/models/service.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/screens/sales/receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/services/service_receipt_preview_screen.dart';

import 'helpers/screen_size_matrix.dart';

// PH2b S7 (phone_foundations.md risk 3): the 400 px receipt and its 24 px
// padding fit a 360 phone by scaling down (never up, never a sideways
// scroll); wide windows are unchanged. The printed output is not drawn
// through this scale (the RepaintBoundary inside it is captured at its own
// 400 px).
const _skip = false;

final _items = [
  for (var i = 1; i <= 12; i++)
    SaleItem(
      productId: 'p$i',
      name: '$matrixLongProductName $i',
      quantity: i,
      unitPrice: matrixBigAmount,
      unit: 'pcs',
    ),
];

final _sale = Sale(
  id: 's1',
  clientName: matrixLongClientName,
  timestamp: DateTime(2026, 10, 26, 9),
  updatedAt: DateTime(2026, 10, 26, 9),
  items: _items,
  totalAmount: matrixBigAmount * 78,
  totalPaid: matrixBigAmount,
  facilityId: 'f1',
  soldById: 'u1',
  soldByName: 'Asha',
  receiptNumber: 1,
);

final _service = Service(
  id: 'v1',
  category: 'Consultation',
  name: 'Ziara ya shambani na matibabu ya ng\'ombe wote wa maziwa',
  description: '',
  clientName: matrixLongClientName,
  totalAmount: matrixBigAmount * 13,
  totalPaid: 0,
  serviceDate: DateTime(2026, 10, 26, 9),
  providedByName: 'Asha',
  receiptNumber: 2,
  itemsUsed: [
    for (var i = 1; i <= 12; i++) {'itemName': '$matrixLongProductName $i', 'price': matrixBigAmount},
  ],
);

/// The thermal receipt drawn on screen: its outer clip (the torn edge).
Finder _receipt() => find.byType(ClipPath).first;

Future<void> _pump(WidgetTester tester, Widget screen, Size size, MatrixLook look) async {
  SharedPreferences.setMockInitialValues({});
  final facility = (await tester.runAsync(() async {
    final p = FacilityProvider(firestore: FakeFirebaseFirestore());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await p.setFacility(id: 'f1', name: matrixLongFacilityName, type: 'Agrovet');
    return p;
  }))!;
  await pumpAtSize(
    tester,
    screen: screen,
    size: size,
    look: look,
    wrap: (app) => ChangeNotifierProvider<FacilityProvider>.value(value: facility, child: app),
  );
}

void _expectNoSidewaysScroll(WidgetTester tester) {
  final sideways = find.ancestor(
    of: _receipt(),
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && (w.axisDirection == AxisDirection.left || w.axisDirection == AxisDirection.right),
    ),
  );
  expect(sideways, findsNothing);
}

void main() {
  final screens = <String, Widget Function()>{
    'sale receipt': () => ReceiptPreviewScreen(sale: _sale),
    'service receipt': () => ServiceReceiptPreviewScreen(service: _service),
  };

  for (final e in screens.entries) {
    for (final width in const [360.0, 390.0]) {
      for (final look in MatrixLook.values) {
        testWidgets('${e.key} fits at $width (${look.name})', (tester) async {
          await _pump(tester, e.value(), Size(width, 800), look);
          expect(tester.takeException(), isNull);
          _expectNoSidewaysScroll(tester);
          // Laid out at its own 400 px (as printed), not squeezed narrower.
          expect(tester.getSize(_receipt()).width, 400);
          final rect = tester.getRect(_receipt());
          // Scaled to the width less the 24 px padding each side, centred.
          expect(rect.width, closeTo(width - 48, 0.5));
          expect(rect.left, closeTo(24, 0.5));
          // ignore: avoid_print
          print('${e.key} at $width: scale ${(rect.width / 400).toStringAsFixed(3)}');
        }, skip: _skip);
      }
    }

    for (final width in const [768.0, 1024.0, 1200.0]) {
      testWidgets('${e.key} keeps scale 1.0 at $width', (tester) async {
        await _pump(tester, e.value(), Size(width, 900), MatrixLook.light);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_receipt()).width, 400);
        expect(tester.getRect(_receipt()).width, closeTo(400, 0.01));
      });
    }
  }
}
