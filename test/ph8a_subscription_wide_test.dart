// PH8a (3): Subscription. Recorded from the code before PH8a: the screen and
// its history page at 768x1024, 1024x768 and 1200x800 (the ph8a- names in
// test/fixtures/ph5a_wide_fingerprints.json), and the payment claim it saves
// for fixed inputs (test/fixtures/ph8a_saved_forms.json, "subscription").
// After PH8a the wide screens still match, and the claim saved on a wide
// window and on a phone is the same.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_history_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8a_saved.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

// The phone case was skipped until the phone form existed.
const _skipPhone = false;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, root.first)}');

/// The prices, three past claims (approved, rejected with a reason, and [pending] when
/// asked) on fixed days, and the person's name.
Future<void> seedSubscription(FirebaseFirestore fs, {bool pending = false}) async {
  await fs.collection(Collections.users).doc(testUserId).set({'fullName': 'Asha Mushi'}, SetOptions(merge: true));
  await fs.collection(Collections.platformConfig).doc('settings').set(
      {'dailyPriceTsh': 1500, 'weeklyPriceTsh': 9000, 'monthlyPriceTsh': 30000, 'yearlyPriceTsh': 300000});
  final claims = facilityCollection(fs, Collections.paymentSubmissions);
  Map<String, Object?> claim(String status, int day, {String? note}) => {
        'planId': 'monthly',
        'planLabel': 'Monthly',
        'amount': 30000,
        'method': 'M-Pesa',
        'reference': 'REF$day',
        'status': status,
        'submittedAt': Timestamp.fromDate(DateTime(2026, 10, day, 9, 30)),
        'submittedByName': 'Asha Mushi',
        if (note != null) 'reviewNote': note,
      };
  await claims.doc('s1').set(claim('approved', 1));
  await claims.doc('s2').set(claim('rejected', 5, note: 'The reference does not match any payment'));
  if (pending) await claims.doc('s3').set(claim('pending', 9));
}

/// The claims saved, oldest first, without the seeded ones.
Future<List<Map<String, dynamic>>> savedClaims(WidgetTester tester, FirebaseFirestore fs) async =>
    (await tester.runAsync(() async {
      final docs = (await facilityCollection(fs, Collections.paymentSubmissions).get()).docs;
      return [for (final d in docs) if (!d.id.startsWith('s')) d.data()];
    }))!;

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    final modal = size.width >= 900;

    for (final pending in [false, true]) {
      final name = 'ph8a-subscription${pending ? '-pending' : ''}-$at';
      ph5TestWidgets('$name: as before PH8a', (tester) async {
        await pumpPh5(tester, (fs) => SubscriptionScreen(isModal: modal, firestore: fs, auth: Ph8Auth()),
            size: size, pushed: !modal, seed: (fs) => seedSubscription(fs, pending: pending));
        _expect(tester, name, find.byType(SubscriptionScreen));
      });
    }

    ph5TestWidgets('ph8a-subscription-history-$at: as before PH8a', (tester) async {
      await pumpPh5(
          tester,
          (fs) => SubscriptionHistoryScreen(facilityId: testFacilityId, primaryColor: const Color(0xFF2F5D62), firestore: fs),
          size: size,
          pushed: true,
          seed: seedSubscription);
      _expect(tester, 'ph8a-subscription-history-$at', find.byType(SubscriptionHistoryScreen));
    });
  }

  for (final (size, skip) in [(const Size(1200, 800), false), (const Size(390, 844), _skipPhone)]) {
    ph5TestWidgets('the claim saved at ${size.width.toInt()} is the one saved before PH8a', (tester) async {
      final app = await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
          size: size, pushed: true, seed: seedSubscription);
      final reference = find.byType(TextField).first;
      await tester.ensureVisible(reference);
      await tester.enterText(reference, '  MP26110312345  ');
      await tester.pump();
      final submit = find.text('Submit Payment for Review');
      // FIN1 (the flake at 390): the prices arrive, and the claim is written
      // (the screen clears the reference only after the add succeeded), in
      // real time; wait for each instead of a fixed budget of it.
      await ph5SettleUntil(tester, () => submit.evaluate().isNotEmpty);
      await tester.ensureVisible(submit.last);
      await tester.tap(submit.last);
      await ph5SettleUntil(tester, () => tester.widget<TextField>(reference).controller!.text.isEmpty);
      while (tester.takeException() != null) {}
      expectSameSaved('subscription', await savedClaims(tester, app.fs));
    }, skip: skip);
  }
}
