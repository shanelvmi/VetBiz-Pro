// PH8b-2 P3 (docs/design/phone_facilities.md, Saves): on a phone Add and
// Edit Facility save exactly what today's dialogs save. For fixed inputs (a
// name, each type with Other's words, contacts, ownership, status, restock
// frequency, a logo) this records what Add sends (the addFacility call's
// payload, then the new facility document's writes and the upload's path,
// size and content type) and what Edit writes (the facility document, the
// logo upload or delete, the syncFacilityDetails call), and compares it
// with test/fixtures/ph8b_saved_facility.json, recorded once from today's
// dialogs at 1200x800 with --dart-define=PH8B_RECORD=true. The wide cases
// keep proving the dialogs unchanged; the phone cases drive the phone forms
// with the same labels.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/facility_types.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/l10n/stored_labels.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/ph7a_fakes.dart' show FakeImagePicker;
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/updates_harness.dart' show testPng;

// True until the phone forms exist (P3).
const _skipPhone = false;

const _fixture = 'test/fixtures/ph8b_saved_facility.json';
final _en = lookupAppLocalizations(const Locale('en'));
final _cacheBust = RegExp(r'&cb=\d+');

Object? _normalize(Object? node) {
  if (node is Map) {
    return Map.fromEntries([for (final e in node.entries) MapEntry('${e.key}', _normalize(e.value))]
      ..sort((a, b) => a.key.compareTo(b.key)));
  }
  if (node is List) return [for (final v in node) _normalize(v)];
  if (node is Timestamp || node is DateTime || node is FieldValue) return '<time>';
  if (node is String) return node.replaceAll(_cacheBust, '&cb=<time>');
  return node;
}

class _Run {
  final Ph5App app;
  final Ph8bFunctions functions;
  final FakeStorage storage;
  _Run(this.app, this.functions, this.storage);

  Future<Object?> saved(WidgetTester tester, String facilityId) async {
    final doc = await tester.runAsync(() => app.fs.collection(Collections.facilities).doc(facilityId).get());
    return jsonDecode(jsonEncode(_normalize({
      'calls': [for (final (name, payload) in functions.calls) {'name': name, 'payload': payload}],
      'facility': doc!.data(),
      'uploads': [for (final u in storage.uploads) u.toJson()],
      'deletes': storage.deletes,
    })));
  }
}

Future<_Run> _pump(WidgetTester tester, {required bool phone, Future<void> Function(FirebaseFirestore fs)? extra}) async {
  final functions = Ph8bFunctions();
  final storage = FakeStorage();
  final app = await pumpPh5(
    tester,
    (fs) => FacilityScreen(
      firestore: fs,
      auth: Ph8bAuth(),
      storage: storage,
      membership: MembershipService(functions: functions),
      functions: functions,
      imagePicker: FakeImagePicker(testPng),
    ),
    size: phone ? const Size(390, 844) : const Size(1200, 800),
    pushed: true,
    seed: (fs) async {
      await ph8bSeedFacilities(fs);
      await fs.collection(Collections.platformConfig).doc('settings').set({'maxFacilitiesPerAdmin': 9});
      await extra?.call(fs);
    },
  );
  return _Run(app, functions, storage);
}

void _drop(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  _drop(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  unawaited(Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5));
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  unawaited(Scrollable.ensureVisible(tester.element(field.first), alignment: 0.5));
  await tester.pump();
  await tester.enterText(field.first, text);
  await _settle(tester);
}

Future<void> _choose(WidgetTester tester, Finder dropdown, String option) async {
  await _tap(tester, dropdown);
  await _tap(tester, find.text(option).last);
}

Future<void> _save(WidgetTester tester, {required bool phone, required String wideLabel}) => _tap(
    tester, phone ? find.byKey(const ValueKey('formActionBar-primary')) : find.widgetWithText(ElevatedButton, wideLabel));

/// Opens Edit for the facility named [name]: wide, its row then More
/// Actions; phone, its row (the details page) then the page's menu.
Future<void> _openEdit(WidgetTester tester, String name, {required bool phone}) async {
  if (phone) {
    await _tap(tester, find.text(name));
    await _tap(tester, find.byKey(const ValueKey('facility-details-menu')));
  } else {
    await _tap(tester, find.text(name));
    await _tap(tester, find.text(_en.facilities_moreActions));
  }
  await _tap(tester, find.text(_en.facilities_editTitle).last);
}

void _expectSame(String name, Object? now) {
  final file = File(_fixture);
  final recorded = file.existsSync() ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>) : <String, dynamic>{};
  if (const bool.fromEnvironment('PH8B_RECORD')) {
    recorded[name] = now;
    final sorted = Map.fromEntries(recorded.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    return;
  }
  expect(now, recorded[name], reason: '$name: what the form saves changed');
}

void main() {
  for (final phone in [false, true]) {
    final where = phone ? 'phone' : 'wide';
    final skip = phone && _skipPhone;

    for (final type in kFacilityTypes) {
      final logo = type == kFacilityTypes.first || type == kFacilityTypeOther;
      final name = 'add-${type.toLowerCase().replaceAll(' ', '-')}';
      ph5TestWidgets('$where: Add, $type${logo ? ' with a logo' : ''}, saves as today', (tester) async {
        final run = await _pump(tester, phone: phone);
        await _tap(tester, phone ? find.byKey(const ValueKey('phoneList-fab')) : find.text(_en.facilities_addTitle));
        if (logo) await _tap(tester, find.byIcon(Icons.add_a_photo_outlined));
        await _type(tester, _en.common_facilityName, 'Mpya Vet Centre');
        await _choose(tester, find.byKey(const ValueKey<String?>('facility-type-null')), _en.facilityTypeLabel(type));
        if (type == kFacilityTypeOther) await _type(tester, _en.facilityType_detailLabel, 'Kituo cha mafunzo');
        await _save(tester, phone: phone, wideLabel: _en.common_add);
        _expectSame(name, await run.saved(tester, Ph8bFunctions.newFacilityId));
      }, skip: skip);
    }

    ph5TestWidgets('$where: Edit, every field, the type Other and a new logo, saves as today', (tester) async {
      final run = await _pump(tester, phone: phone);
      await _openEdit(tester, 'Kilimo Agrovet', phone: phone);
      await _tap(tester, find.byIcon(Icons.camera_alt));
      await _type(tester, _en.common_facilityName, 'Kilimo Agrovet Mpya');
      await _choose(tester, find.byKey(const ValueKey<String?>('facility-type-Agrovet')), 'Other');
      await _type(tester, _en.facilityType_detailLabel, 'Duka la pembejeo');
      await _type(tester, _en.facilities_businessEmailOptional, ' mpya@kilimo.co.tz ');
      await _type(tester, _en.facilities_businessPhoneOptional, '+255 754 999 000');
      await _type(tester, _en.facilities_addressOptional, 'Barabara ya Sokoine');
      await _type(tester, _en.facilities_descriptionOptional, 'Pembejeo na dawa za mifugo');
      await _type(tester, _en.facilities_taglineOptional, 'Afya ya mifugo yako');
      await _type(tester, _en.facilities_licenseOptional, 'LIC-99');
      await _type(tester, _en.facilities_tinOptional, '123-456-789');
      await _choose(tester, find.widgetWithText(DropdownButtonFormField<String>, _en.facilities_ownershipOptional), 'Rented');
      await _choose(tester, find.widgetWithText(DropdownButtonFormField<String>, _en.common_status), 'Inactive');
      await _choose(tester, find.widgetWithText(DropdownButtonFormField<String>, _en.facilities_restockQuestion), 'Monthly');
      await _save(tester, phone: phone, wideLabel: _en.common_save);
      _expectSame('edit-all', await run.saved(tester, testFacilityId));
    }, skip: skip);

    ph5TestWidgets('$where: Edit, Remove logo, Other to Vet Clinic, a field emptied, saves as today', (tester) async {
      final run = await _pump(tester,
          phone: phone,
          extra: (fs) => fs.collection(Collections.facilities).doc(ph8bOtherId).update({'logoUrl': 'https://storage.test/old.png'}));
      await _openEdit(tester, 'Shamba Hub', phone: phone);
      await _tap(tester, find.text(_en.facilities_removeLogo));
      await _choose(tester, find.byKey(const ValueKey<String?>('facility-type-Other')), 'Vet Clinic');
      await _type(tester, _en.facilities_addressOptional, '');
      await _save(tester, phone: phone, wideLabel: _en.common_save);
      _expectSame('edit-remove-logo', await run.saved(tester, ph8bOtherId));
    }, skip: skip);
  }
}
