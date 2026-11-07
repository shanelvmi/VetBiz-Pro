// PH8b-2 P3 (docs/design/phone_facilities.md): Add and Edit Facility on a
// phone are the PH6 form shell as a full page (showAdaptiveForm): one
// column, 48 px fields in today's order, FormActionBar (Cancel, Save) pinned
// and lifted over the keyboard, PhoneDiscardScope asking before a typed form
// is left, today's validators and FacilityTypeField with Other's words, the
// logo through today's picking path (too large is refused with today's
// message). What they save is ph8b_saved_facility_test.dart's.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/ph7a_fakes.dart' show FakeImagePicker;
import 'helpers/ph8b2_facility_page.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';

// True until the phone forms are built (P3).
const _skip = false;

final _en = ph8b2En;
const _bar = ValueKey('formActionBar');
const _primary = ValueKey('formActionBar-primary');

Future<void> _openAdd(WidgetTester tester) => ph8b2Tap(tester, find.byKey(const ValueKey('phoneList-fab')));

Future<void> _openEdit(WidgetTester tester) async {
  await ph8b2OpenDetails(tester);
  await _editFromPage(tester);
}

/// From the facility's page: its menu, then Edit.
Future<void> _editFromPage(WidgetTester tester) async {
  await ph8b2Tap(tester, find.byKey(ph8b2Menu));
  await ph8b2Tap(tester, find.text(_en.facilities_editTitle).last);
}

/// The [labels] shown, in the form's order (the tree's, so a scrolling page
/// counts the fields below the fold too).
List<String> _order(WidgetTester tester, List<String> labels) {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final data = (e.widget as Text).data;
    if (data != null && labels.contains(data) && !out.contains(data)) out.add(data);
  }
  return out;
}

void main() {
  for (final (name, open, reopen, title, primary) in [
    ('Add', _openAdd, _openAdd, _en.facilities_addTitle, _en.common_add),
    ('Edit', _openEdit, _editFromPage, _en.facilities_editTitle, _en.common_save),
  ]) {
    ph5TestWidgets('$name: a full page with the pinned bar (Cancel, $primary), not a dialog', (tester) async {
      await pumpPh8b2(tester);
      await open(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsWidgets);
      expect(find.descendant(of: find.byKey(_bar), matching: find.text(primary)), findsOneWidget);
      expect(find.descendant(of: find.byKey(_bar), matching: find.text(_en.common_cancel)), findsOneWidget);
      for (final f in [...tester.widgetList(find.byType(TextField)), ...tester.widgetList(find.byType(DropdownButtonFormField<String>))]) {
        expect(tester.getSize(find.byWidget(f)).height, greaterThanOrEqualTo(48));
      }
    }, skip: _skip);

    ph5TestWidgets('$name: the bar rises above a 300 px keyboard', (tester) async {
      await pumpPh8b2(tester);
      await open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await ph8b2Settle(tester);
      expect(tester.getRect(find.byKey(_primary)).bottom, lessThanOrEqualTo(844 - 300));
      expect(tester.getRect(find.byKey(_primary)).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }, skip: _skip);

    ph5TestWidgets('$name: a clean form leaves without asking; Cancel too', (tester) async {
      await pumpPh8b2(tester);
      await open(tester);
      await tester.pageBack();
      await ph8b2Settle(tester);
      expect(find.byKey(_bar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await reopen(tester);
      await ph8b2Tap(tester, find.descendant(of: find.byKey(_bar), matching: find.text(_en.common_cancel)));
      expect(find.byKey(_bar), findsNothing);
    }, skip: _skip);

    ph5TestWidgets('$name: with typed data, Back asks; Keep editing stays; Discard leaves', (tester) async {
      await pumpPh8b2(tester);
      await open(tester);
      await tester.enterText(find.widgetWithText(TextField, _en.common_facilityName), 'Kituo Kipya');
      await tester.pageBack();
      await ph8b2Settle(tester);
      expect(find.text(_en.phoneForm_discardTitle('other')), findsOneWidget);
      await ph8b2Tap(tester, find.text(_en.phoneForm_keepEditing));
      expect(find.byKey(_bar), findsOneWidget);
      expect(find.text('Kituo Kipya'), findsOneWidget);
      await tester.pageBack();
      await ph8b2Settle(tester);
      await ph8b2Tap(tester, find.text(_en.phoneForm_discard));
      expect(find.byKey(_bar), findsNothing);
    }, skip: _skip);
  }

  ph5TestWidgets('Add: today\'s fields in today\'s order; Other adds its words under the type', (tester) async {
    await pumpPh8b2(tester);
    await _openAdd(tester);
    expect(_order(tester, [_en.facilities_logoOptional, _en.common_facilityName, _en.facilities_typeOfFacility]),
        [_en.facilities_logoOptional, _en.common_facilityName, _en.facilities_typeOfFacility]);
    expect(find.widgetWithText(TextField, _en.facilityType_detailLabel), findsNothing);
    await ph8b2Tap(tester, find.byKey(const ValueKey<String?>('facility-type-null')));
    await ph8b2Tap(tester, find.text('Other').last);
    expect(find.widgetWithText(TextField, _en.facilityType_detailLabel), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Edit: today\'s fields in today\'s order', (tester) async {
    await pumpPh8b2(tester);
    await _openEdit(tester);
    final labels = [
      _en.facilities_tapToChangeLogo,
      _en.common_facilityName,
      _en.facilities_typeOfFacility,
      _en.facilities_businessEmailOptional,
      _en.facilities_businessPhoneOptional,
      _en.facilities_addressOptional,
      _en.facilities_descriptionOptional,
      _en.facilities_taglineOptional,
      _en.facilities_licenseOptional,
      _en.facilities_tinOptional,
      _en.facilities_ownershipOptional,
      _en.common_status,
      _en.facilities_restockQuestion,
    ];
    expect(_order(tester, labels), labels);
  }, skip: _skip);

  ph5TestWidgets('Add: today\'s validators (name and type required; Other needs its words)', (tester) async {
    await pumpPh8b2(tester);
    await _openAdd(tester);
    await ph8b2Tap(tester, find.byKey(_primary));
    expect(find.text(_en.facilities_nameAndTypeRequired), findsOneWidget);
    expect(find.text(_en.facilityType_required), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, _en.common_facilityName), 'Kituo Kipya');
    await ph8b2Tap(tester, find.byKey(const ValueKey<String?>('facility-type-null')));
    await ph8b2Tap(tester, find.text('Other').last);
    await ph8b2Tap(tester, find.byKey(_primary));
    expect(find.text(_en.facilityType_detailLabel), findsWidgets);
    expect(find.text(_en.facilities_nameAndTypeRequired), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('a logo too large is refused with today\'s message', (tester) async {
    final functions = Ph8bFunctions();
    await pumpPh5(
      tester,
      (fs) => FacilityScreen(
        firestore: fs,
        auth: Ph8bAuth(),
        storage: FakeStorage(),
        membership: MembershipService(functions: functions),
        functions: functions,
        imagePicker: FakeImagePicker(Uint8List(AppLimits.maxUploadBytes + 1)),
      ),
      pushed: true,
      seed: ph8bSeedFacilities,
    );
    await _openEdit(tester);
    await ph8b2Tap(tester, find.byIcon(Icons.camera_alt));
    expect(find.text(_en.error_photoTooLarge), findsOneWidget);
    expect(find.text(_en.facilities_removeLogo), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Edit: Remove logo is offered for a facility with one, and goes once chosen', (tester) async {
    await pumpPh8b2(tester,
        extra: (fs) => fs.collection('facilities').doc(testFacilityId).update({'logoUrl': 'https://storage.test/old.png'}));
    await _openEdit(tester);
    expect(find.text(_en.facilities_removeLogo), findsOneWidget);
    await ph8b2Tap(tester, find.text(_en.facilities_removeLogo));
    expect(find.text(_en.facilities_removeLogo), findsNothing);
  }, skip: _skip);
}
