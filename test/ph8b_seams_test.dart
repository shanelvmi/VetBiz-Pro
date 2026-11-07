// PH8b seams: Team Members and Facilities built in a test on a fake Firestore
// (optional firestore:, auth:, storage: and the server's membership:
// parameters defaulting to the app's own; no behaviour change). One smoke
// test each. PH8b-2: Facilities' functions: (the delete callable) and
// imagePicker: (the logo) seams.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';

import 'helpers/fake_storage.dart';
import 'helpers/ph7a_fakes.dart' show FakeImagePicker;
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/updates_harness.dart' show testPng;

final _en = lookupAppLocalizations(const Locale('en'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
}

/// Today's wide layout overflows a few pixels in the square test font.
void _dropOverflows(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  ph5TestWidgets('Team Members builds on a fake Firestore and lists the team', (tester) async {
    await pumpPh5(tester, (fs) => ph8bTeamScreen(fs), size: const Size(1200, 800), pushed: true, seed: ph8bSeedTeam);
    expect(find.byType(ManageAssistantsScreen), findsOneWidget);
    expect(find.text('Neema Active'), findsOneWidget);
    // Not a team member: never listed.
    expect(find.text('Support Admin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  ph5TestWidgets('Facilities builds on a fake Firestore and lists the facilities', (tester) async {
    // Today's wide layout overflows a few pixels in the square test font
    // (the fingerprints keep those as they are); anything else, a Firebase
    // error above all, fails.
    final errors = <String>[];
    final before = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);
    addTearDown(() => FlutterError.onError = before);
    await pumpPh5(tester, (fs) => FacilityScreen(firestore: fs, auth: Ph8bAuth(), storage: FakeStorage()),
        size: const Size(1200, 800), pushed: true, seed: ph8bSeedFacilities);
    FlutterError.onError = before;
    expect(find.byType(FacilityScreen), findsOneWidget);
    expect(find.text('Mifugo Clinic'), findsWidgets);
    expect(errors.where((e) => !e.startsWith('A RenderFlex overflowed')), isEmpty);
  });

  ph5TestWidgets('Facilities\' Delete calls deleteOwnFacility through the functions: seam', (tester) async {
    final functions = Ph8bFunctions();
    await pumpPh5(tester, (fs) => FacilityScreen(firestore: fs, auth: Ph8bAuth(), storage: FakeStorage(), functions: functions),
        size: const Size(1200, 800), pushed: true, seed: ph8bSeedFacilities);
    await _tap(tester, find.text('Shamba Hub'));
    await _tap(tester, find.text(_en.facilities_moreActions));
    await _tap(tester, find.text(_en.facilities_deleteTitle).last);
    await tester.enterText(find.byType(TextField).last, 'Shamba Hub');
    await _settle(tester);
    await _tap(tester, find.widgetWithText(ElevatedButton, _en.common_delete));
    _dropOverflows(tester);
    expect(functions.calls.map((c) => '${c.$1} ${c.$2}'), ['deleteOwnFacility {facilityId: $ph8bOtherId}']);
  });

  ph5TestWidgets('Facilities\' logo is picked through the imagePicker: seam', (tester) async {
    final picker = FakeImagePicker(testPng);
    await pumpPh5(tester, (fs) => FacilityScreen(firestore: fs, auth: Ph8bAuth(), storage: FakeStorage(), imagePicker: picker),
        size: const Size(1200, 800), pushed: true, seed: ph8bSeedFacilities);
    await _tap(tester, find.text(_en.facilities_moreActions));
    await _tap(tester, find.text(_en.facilities_editTitle).last);
    await _tap(tester, find.byIcon(Icons.camera_alt));
    _dropOverflows(tester);
    expect(picker.picks, 1);
    expect(find.text(_en.facilities_removeLogo), findsOneWidget);
  });
}
