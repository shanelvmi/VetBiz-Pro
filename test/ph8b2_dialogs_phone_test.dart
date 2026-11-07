// PH8b-2 P4 (docs/design/phone_facilities.md): on a phone today's Facilities
// dialogs are bottom sheets (showSheetOrDialog: the title, the body
// scrolling, the actions pinned side by side), with today's texts, results
// and saves: the facility limit, Delete blocked by assistants, Delete's typed
// confirmation (not dismissible, enabled only on the facility name typed
// exactly), the status toggle, the retention picker and its confirmation,
// the overdue picker. Wide screens keep today's dialogs (the ph8b-facilities-
// fingerprints in ph8b_wide_unchanged_test.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8b2_facility_page.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/phone_list_harness.dart';

// True until the sheets are built (P4).
const _skip = true;

final _en = ph8b2En;

/// A sheet is open, holding [title], and no dialog.
void _expectSheet(String title) {
  expect(find.byType(BottomSheet), findsOneWidget, reason: title);
  expect(find.byType(AlertDialog), findsNothing, reason: title);
  expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(title)), findsOneWidget, reason: title);
}

Future<Map<String, dynamic>> _facility(WidgetTester tester, FirebaseFirestore fs, String id) async =>
    (await tester.runAsync(() => fs.collection(Collections.facilities).doc(id).get()))!.data()!;

Future<void> _settings(WidgetTester tester, [String id = testFacilityId]) async {
  await ph8b2OpenDetails(tester, id);
  await ph8b2OpenTab(tester, 5);
}

Future<void> _openDelete(WidgetTester tester, String id) async {
  await ph8b2OpenDetails(tester, id);
  await ph8b2Tap(tester, find.byKey(ph8b2Menu));
  await ph8b2Tap(tester, find.text(_en.facilities_deleteTitle).last);
}

ElevatedButton _deleteButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, _en.common_delete));

void main() {
  ph5TestWidgets('the facility limit: a sheet with today\'s message and OK', (tester) async {
    await pumpPh8b2(tester, maxFacilities: 3);
    await ph8b2Tap(tester, find.byKey(const ValueKey('phoneList-fab')));
    _expectSheet(_en.facilities_limitTitle);
    expect(find.text(_en.facilities_limitMessage(3)), findsOneWidget);
    await ph8b2Tap(tester, find.text(_en.common_ok));
    expect(find.byType(BottomSheet), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Delete blocked by an assistant: a sheet with the count and OK', (tester) async {
    await pumpPh8b2(tester);
    await _openDelete(tester, ph8bClinicId);
    _expectSheet(_en.facilities_cannotDeleteTitle);
    expect(find.text(_en.facilities_cannotDeleteMessage(1)), findsOneWidget);
    await ph8b2Tap(tester, find.text(_en.common_ok));
    expect(find.byType(BottomSheet), findsNothing);
  }, skip: _skip);

  group('Delete\'s typed confirmation', () {
    ph5TestWidgets('a sheet that a tap outside does not close', (tester) async {
      await pumpPh8b2(tester);
      await _openDelete(tester, ph8bOtherId);
      _expectSheet(_en.facilities_deleteTitle);
      expect(find.text(_en.facilities_typeToConfirm('Shamba Hub')), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await ph8b2Settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      await ph8b2Tap(tester, find.text(_en.common_cancel));
      expect(find.byType(BottomSheet), findsNothing);
    }, skip: _skip);

    for (final phone in [true, false]) {
      ph5TestWidgets('${phone ? 'phone' : 'wide'}: Delete only on the name typed exactly (case and inner spaces)', (tester) async {
        final app = await pumpPh8b2(tester, size: phone ? const Size(390, 844) : const Size(1200, 1600));
        if (phone) {
          await _openDelete(tester, ph8bOtherId);
        } else {
          await ph8b2Tap(tester, find.text('Shamba Hub'));
          await ph8b2Tap(tester, find.text(_en.facilities_moreActions));
          await ph8b2Tap(tester, find.text(_en.facilities_deleteTitle).last);
        }
        final field = find.byType(TextField).last;
        // Today's comparison: the typed text, trimmed, against the stored name.
        for (final (typed, enabled) in [
          ('', false),
          ('shamba hub', false),
          ('SHAMBA HUB', false),
          ('Shamba  Hub', false),
          ('Shamba Hu', false),
          (' Shamba Hub ', true),
          ('Shamba Hub', true),
        ]) {
          await tester.enterText(field, typed);
          await tester.pump();
          expect(_deleteButton(tester).onPressed != null, enabled, reason: '"$typed"');
        }
        await ph8b2Tap(tester, find.widgetWithText(ElevatedButton, _en.common_delete));
        if (!phone) ph8b2DropOverflows(tester);
        expect(app.functions.calls.map((c) => '${c.$1} ${c.$2}'), ['deleteOwnFacility {facilityId: $ph8bOtherId}']);
      }, skip: _skip);
    }
  });

  ph5TestWidgets('the status toggle: a sheet; Deactivate saves Inactive as today', (tester) async {
    final app = await pumpPh8b2(tester);
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.facilities_deactivateThis));
    _expectSheet(_en.facilities_deactivateConfirmTitle);
    expect(find.text(_en.facilities_deactivateConfirm('Kilimo Agrovet')), findsOneWidget);
    await ph8b2Tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text(_en.team_deactivate)));
    expect((await _facility(tester, app.fs, testFacilityId))['status'], 'Inactive');
    expect(find.text(_en.facilities_reactivateThis), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the status toggle: Cancel changes nothing', (tester) async {
    final app = await pumpPh8b2(tester);
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.facilities_deactivateThis));
    await ph8b2Tap(tester, find.text(_en.common_cancel));
    expect((await _facility(tester, app.fs, testFacilityId))['status'], 'Active');
  }, skip: _skip);

  ph5TestWidgets('the retention picker: a sheet of radio rows, Cancel pinned; a longer window saves', (tester) async {
    final app = await pumpPh8b2(tester,
        extra: (fs) => fs.collection(Collections.facilities).doc(testFacilityId).update({'activityLogRetentionDays': 30}));
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.common_change).first);
    _expectSheet(_en.facilities_keepLogsFor);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(RadioListTile<int>)), findsNWidgets(4));
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(_en.common_cancel)), findsOneWidget);
    await ph8b2Tap(tester, find.text(_en.debtors_daysCount(60)));
    expect(find.byType(BottomSheet), findsNothing, reason: 'a longer window asks nothing');
    expect((await _facility(tester, app.fs, testFacilityId))['activityLogRetentionDays'], 60);
  }, skip: _skip);

  ph5TestWidgets('the retention picker: a shorter window asks first in a sheet; Cancel keeps it', (tester) async {
    final app = await pumpPh8b2(tester);
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.common_change).first);
    await ph8b2Tap(tester, find.text(_en.debtors_daysCount(30)));
    _expectSheet(_en.facilities_deleteOlderLogsTitle);
    await ph8b2Tap(tester, find.text(_en.common_cancel));
    expect((await _facility(tester, app.fs, testFacilityId))['activityLogRetentionDays'], isNull);
  }, skip: _skip);

  ph5TestWidgets('the retention confirmation: Delete and switch saves the shorter window', (tester) async {
    final app = await pumpPh8b2(tester);
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.common_change).first);
    await ph8b2Tap(tester, find.text(_en.debtors_daysCount(30)));
    await ph8b2Tap(tester, find.text(_en.facilities_deleteAndSwitch(30)));
    expect((await _facility(tester, app.fs, testFacilityId))['activityLogRetentionDays'], 30);
  }, skip: _skip);

  ph5TestWidgets('the overdue picker: a sheet of radio rows; a choice saves as today', (tester) async {
    final app = await pumpPh8b2(tester);
    await _settings(tester);
    await ph8b2Tap(tester, find.text(_en.common_change).last);
    _expectSheet(_en.facilities_overdueAfterTitle);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(RadioListTile<int>)), findsNWidgets(5));
    await ph8b2Tap(tester, find.text(_en.debtors_daysCount(60)));
    expect((await _facility(tester, app.fs, testFacilityId))['debtOverdueDays'], 60);
  }, skip: _skip);
}
