// PH8a (4): the Settings pages on phones: every page at 360x740, 390x844 and
// 740x360 in Light, Dark and Kiswahili with a very long facility name (no
// overflow, 48 px targets, text 12 px or more); Business profile scrolls and
// has the PH6 action bar; Business hours' closing times and Printer's paper
// size are chosen in sheets; Export's date range and Manage Account's
// dialogs open as sheets (showSheetOrDialog). Wider windows keep their
// dialogs (ph8a_settings_wide_test pins the pages).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/printer_settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/widgets/phone_form/form_action_bar.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_settings_wide_test.dart' show seedFacility;

// True until the phone pages exist.
const _skip = false;

final _pages = <(String, Widget Function(FirebaseFirestore))>[
  ('Business profile', (fs) => BusinessProfileScreen(firestore: fs, storage: FakeStorage())),
  ('Business hours', (fs) => BusinessHoursScreen(firestore: fs)),
  ('Printer settings', (fs) => const PrinterSettingsScreen()),
  ('Export', (fs) => ExportDataScreen(firestore: fs)),
  ('Manage Account', (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth())),
  ('Settings', (fs) => SettingsScreen(firestore: fs, auth: Ph8Auth())),
];

Future<void> _long(FirebaseFirestore fs) async {
  await seedFacility(fs);
  await facilityDoc(fs).set({'name': matrixLongFacilityName}, SetOptions(merge: true));
}

Future<Ph5App> _pump(WidgetTester tester, Widget Function(FirebaseFirestore) page,
        {Size size = const Size(390, 844), MatrixLook look = MatrixLook.light}) =>
    pumpPh5(tester, page, size: size, look: look, pushed: true, seed: _long);

Finder get _sheet => find.byType(BottomSheet);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'facilityName': matrixLongFacilityName}));

  for (final (name, page) in _pages) {
    for (final size in ph5PhoneSizes) {
      for (final look in MatrixLook.values) {
        final where = '$name ${size.label} ${look.name}';
        ph5TestWidgets('$where: no overflow, 48 px targets, text 12 px or more', (tester) async {
          await _pump(tester, page, size: size.size, look: look);
          await checkCase(tester, phone: true, where: where);
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -2000));
            await ph5Settle(tester);
            // Scrolled to the end a row may sit half under the app bar, which
            // the tap-target check reads as a small target: here only overflow
            // and text sizes (the targets were checked unscrolled).
            expect(tester.takeException(), isNull, reason: '$where, scrolled');
            expect(smallTexts(tester), isEmpty, reason: '$where, scrolled');
          }
        }, skip: _skip);
      }
    }
  }

  ph5TestWidgets('Business profile scrolls, with the logo action in the action bar', (tester) async {
    await _pump(tester, _pages[0].$2, size: const Size(740, 360));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.descendant(of: find.byType(FormActionBar), matching: find.text('Upload Logo')), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Business hours: a closing time is chosen in a sheet; Save is in the action bar', (tester) async {
    await _pump(tester, _pages[1].$2);
    expect(find.descendant(of: find.byType(FormActionBar), matching: find.text('Save Business Hours')), findsOneWidget);
    await tester.tap(find.textContaining('Closes at').first);
    await ph5Settle(tester);
    expect(_sheet, findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Done'));
    await ph5Settle(tester);
    expect(_sheet, findsNothing);
  }, skip: _skip);

  ph5TestWidgets('Printer settings: the paper size is chosen in a sheet and saved as before', (tester) async {
    await _pump(tester, _pages[2].$2);
    await tester.tap(find.text('Paper Size'));
    await ph5Settle(tester);
    expect(_sheet, findsOneWidget);
    await tester.tap(find.text('80mm').last);
    await ph5Settle(tester);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getString('printer_paper_size'), '80');
  }, skip: _skip);

  ph5TestWidgets('Export: the date range opens as a sheet', (tester) async {
    await _pump(tester, _pages[3].$2);
    await tester.scrollUntilVisible(find.text('Modify'), 200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await ph5Settle(tester);
    await tester.tap(find.text('Modify'));
    await ph5Settle(tester);
    expect(_sheet, findsOneWidget);
    expect(find.descendant(of: _sheet, matching: find.text('Last 7 Days')), findsOneWidget);
    await checkCase(tester, phone: true, where: 'the date range sheet');
  }, skip: _skip);

  for (final (tile, title) in [
    ('Sign Out of All Devices', 'Sign Out of All Devices?'),
    ('Wipe All Business Data', 'Wipe All Data?'),
    ('Deactivate Account', 'Deactivate Account'),
  ]) {
    ph5TestWidgets('Manage Account: "$tile" asks in a sheet; Cancel changes nothing', (tester) async {
      await _pump(tester, _pages[4].$2);
      await tester.tap(find.text(tile).first);
      await ph5Settle(tester);
      expect(find.descendant(of: _sheet, matching: find.text(title)), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await checkCase(tester, phone: true, where: '$tile sheet');
      await tester.tap(find.descendant(of: _sheet, matching: find.text('Cancel')));
      await ph5Settle(tester);
      expect(_sheet, findsNothing);
      expect(find.byType(ManageAccountScreen), findsOneWidget);
    }, skip: _skip);
  }

  ph5TestWidgets('Manage Account on a tablet keeps its dialogs', (tester) async {
    await _pump(tester, _pages[4].$2, size: const Size(768, 1024));
    await tester.tap(find.text('Sign Out of All Devices').first);
    await ph5Settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(_sheet, findsNothing);
  }, skip: _skip);
}
