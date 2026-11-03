// PH8a (4): the Settings pages. Recorded from the code before PH8a: each page
// at 768x1024, 1024x768 and 1200x800 (the ph8a- names in
// test/fixtures/ph5a_wide_fingerprints.json), and what Business profile and
// Business hours save for fixed inputs (test/fixtures/ph8a_saved_forms.json).
// After PH8a the wide pages still match, and they save the same on a wide
// window and on a phone.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/printer_settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/ph8a_saved.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

// The phone cases run once the phone pages exist.
const _skipPhone = true;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, root.first)}');

Future<Map<String, String>> ph8UserInfo() async => {'userId': testUserId, 'userName': 'Asha Mushi'};

/// Something in each Trash tab, deleted two days ago (28 days before the
/// purge, whatever the day the test runs).
Future<void> seedTrash(FirebaseFirestore fs) async {
  final deleted = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2)));
  await facilityCollection(fs, Collections.trashProducts).doc('p1').set(
      {'name': 'Albendazole 10% Chupa ya Lita Moja', 'deletedAt': deleted, 'deletedBy': 'Asha', 'sellPrice': 15000});
  await facilityCollection(fs, Collections.trashClients)
      .doc('c1')
      .set({'name': 'Amina Juma', 'phone': '0712111111', 'deletedAt': deleted, 'deletedBy': 'Asha'});
  await facilityCollection(fs, Collections.trashSales)
      .doc('s1')
      .set({'clientName': 'Amina Juma', 'totalAmount': 45000, 'deletedAt': deleted, 'deletedBy': 'Asha'});
  await facilityCollection(fs, Collections.trashTransactions).doc('t1').set(
      {'description': 'Fuel', 'type': 'expense', 'amount': 20000, 'deletedAt': deleted, 'deletedBy': 'Asha'});
}

/// A facility with a type. (No saved hours: whether they arrive before the
/// page reads them would depend on timing; the defaults are shown and saved.)
Future<void> seedFacility(FirebaseFirestore fs) async {
  await facilityDoc(fs).set({'type': 'Agrovet'}, SetOptions(merge: true));
}

/// The cache-busting time on the logo's URL moves with the clock.
Map<String, dynamic> _maskLogo(Map<String, dynamic> facility) => {
      ...facility,
      if (facility['logoUrl'] is String) 'logoUrl': (facility['logoUrl'] as String).replaceAll(RegExp(r'cb=\d+'), 'cb=<time>'),
    };

Future<Map<String, dynamic>> _facility(WidgetTester tester, FirebaseFirestore fs) async =>
    (await tester.runAsync(() async => (await facilityDoc(fs).get()).data()!))!;

/// Business profile: a new logo picked and saved.
Future<void> saveLogo(WidgetTester tester, {required Size size, required String uploadLabel}) async {
  final storage = FakeStorage();
  final app = await pumpPh5(
      tester, (fs) => BusinessProfileScreen(firestore: fs, storage: storage, pickLogo: () async => Uint8List(2048)),
      size: size, pushed: true, seed: seedFacility);
  await tester.tap(find.text(uploadLabel).last);
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
  final facility = _maskLogo(await _facility(tester, app.fs));
  expectSameSaved('business_profile', [
    {'logoUrl': facility['logoUrl']},
    for (final u in storage.uploads) u.toJson(),
  ]);
}

/// Business hours: Saturday closed and Allow anytime on, then saved.
Future<void> saveHours(WidgetTester tester, {required Size size, required String saveLabel}) async {
  final app = await pumpPh5(tester, (fs) => BusinessHoursScreen(firestore: fs), size: size, pushed: true, seed: seedFacility);
  final switches = find.byType(Switch);
  await tester.ensureVisible(switches.at(1));
  await tester.tap(switches.at(1));
  await tester.pump();
  await tester.ensureVisible(switches.last);
  await tester.tap(switches.last);
  await tester.pump();
  final save = find.text(saveLabel).last;
  await tester.ensureVisible(save);
  await tester.tap(save);
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
  expectSameSaved('business_hours', [
    {'businessHours': (await _facility(tester, app.fs))['businessHours']},
  ]);
}

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    for (final (name, build, type) in <(String, Widget Function(FirebaseFirestore), Type)>[
      ('business-profile', (fs) => BusinessProfileScreen(firestore: fs, storage: FakeStorage()), BusinessProfileScreen),
      ('business-hours', (fs) => BusinessHoursScreen(firestore: fs), BusinessHoursScreen),
      ('printer', (fs) => const PrinterSettingsScreen(), PrinterSettingsScreen),
      ('export', (fs) => ExportDataScreen(firestore: fs), ExportDataScreen),
      ('manage-account', (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth()), ManageAccountScreen),
      ('settings', (fs) => SettingsScreen(firestore: fs, auth: Ph8Auth()), SettingsScreen),
    ]) {
      ph5TestWidgets('ph8a-$name-$at: as before PH8a', (tester) async {
        await pumpPh5(tester, build, size: size, pushed: true, seed: seedFacility);
        _expect(tester, 'ph8a-$name-$at', find.byType(type));
      });
    }

    ph5TestWidgets('ph8a-trash-$at: every tab as before PH8a', (tester) async {
      await pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
          size: size, pushed: true, seed: seedTrash);
      for (final (i, tab) in ['products', 'clients', 'services', 'sales', 'transactions'].indexed) {
        await tester.tap(find.byType(Tab).at(i));
        await ph5Settle(tester);
        _expect(tester, 'ph8a-trash-$tab-$at', find.byType(TrashScreen));
      }
    });
  }

  for (final (size, skip) in [(const Size(1200, 800), false), (const Size(390, 844), _skipPhone)]) {
    final at = '${size.width.toInt()}';
    ph5TestWidgets('Business profile at $at saves the logo as before PH8a', (tester) async {
      await saveLogo(tester, size: size, uploadLabel: 'Upload Logo');
    }, skip: skip);
    ph5TestWidgets('Business hours at $at saves as before PH8a', (tester) async {
      await saveHours(tester, size: size, saveLabel: 'Save Business Hours');
    }, skip: skip);
  }
}
