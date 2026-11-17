// POL3: the Platform Admin Promotions screen had no fingerprint yet, so it is
// recorded on the code before POL3 (the pol3- names in
// test/fixtures/ph5a_wide_fingerprints.json) at 768x1024, 1024x768 and
// 1200x800, with a live, an ended and a switched-off promotion. The
// fingerprint holds the widget types, the texts and every box's size and
// place, not colours, gradients or shadows, so flattening the "% OFF" badge
// leaves it unchanged. Sign-in and register are already fingerprinted at the
// same sizes (lg1-login, ui8-login, fin1-register).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/platform_admin/promotions_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart' show MatrixLook;
import 'helpers/tree_fingerprint.dart';

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

/// A live, an ended and a switched-off promotion, newest first.
Future<void> seedPromotions(FirebaseFirestore fs) async {
  final promotions = fs.collection(Collections.promotions);
  await promotions.doc('live').set({
    'label': 'Harvest offer',
    'active': true,
    'discountPercent': 10,
    'appliesToPlans': <String>[],
    'targetExpiringOnly': false,
    'createdAt': Timestamp.fromDate(ph5When(1)),
  });
  await promotions.doc('ended').set({
    'label': 'Nanenane sale',
    'active': true,
    'discountPercent': 12.5,
    'appliesToPlans': <String>[],
    'targetExpiringOnly': true,
    'endsAt': Timestamp.fromDate(ph5When(3)),
    'createdAt': Timestamp.fromDate(ph5When(20)),
  });
  await promotions.doc('off').set({
    'label': 'Month-end push',
    'active': false,
    'discountPercent': 5,
    'appliesToPlans': <String>[],
    'targetExpiringOnly': false,
    'createdAt': Timestamp.fromDate(ph5When(40)),
  });
}

/// Promotions as the Platform Admin console opens it at [size].
Future<void> pumpPromotions(WidgetTester tester, Size size, {MatrixLook look = MatrixLook.light}) async {
  final modal = size.width >= 900;
  await pumpPh5(tester, (fs) => PromotionsScreen(isModal: modal, firestore: fs),
      size: size, look: look, pushed: !modal, seed: seedPromotions);
  await ph5SettleUntil(tester, () => find.text('Month-end push').evaluate().isNotEmpty);
}

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    ph5TestWidgets('pol3-promotions-$at: the layout as before POL3', (tester) async {
      await pumpPromotions(tester, size);
      expect(find.text('Harvest offer'), findsOneWidget);
      expect(find.text('Nanenane sale'), findsOneWidget);
      final errors = _errors(tester);
      expect(errors, isEmpty, reason: 'no overflow or other error');
      expectSameFingerprint('pol3-promotions-$at', '$errors${treeFingerprint(tester, find.byType(PromotionsScreen).first)}');
    });
  }
}
