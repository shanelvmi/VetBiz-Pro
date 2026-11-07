// PH8b-2: Facilities on a phone past the list (docs/design/phone_facilities.md
// P2 to P4): the screen on the fake Firestore with the fake server, Storage
// and picker, and the steps the tests share (open a facility's page, a tab's
// row, the page's menu).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

import 'fake_firestore.dart';
import 'fake_storage.dart';
import 'ph7a_fakes.dart' show FakeImagePicker;
import 'ph8b_facilities.dart';
import 'ph8b_team.dart';
import 'phone_list_harness.dart';
import 'screen_size_matrix.dart';
import 'updates_harness.dart' show testPng;

final ph8b2En = lookupAppLocalizations(const Locale('en'));

/// The facility page's parts, as the tests find them.
const ph8b2Details = ValueKey('facility-details');
const ph8b2Menu = ValueKey('facility-details-menu');
const ph8b2Header = ValueKey('facility-phone-header');
const ph8b2Metrics = ValueKey('facility-phone-metrics');
Finder ph8b2TabRow(int index) => find.byKey(ValueKey('facility-tab-row-$index'));
Finder ph8b2TabPage(int index) => find.byKey(ValueKey('facility-tab-page-$index'));

class Ph8b2App {
  final Ph5App app;
  final Ph8bFunctions functions;
  final FakeStorage storage;
  Ph8b2App(this.app, this.functions, this.storage);
  FirebaseFirestore get fs => app.fs;
}

/// Facilities at [size] in [look], pushed; [maxFacilities] the platform's
/// limit (9: room to add).
Future<Ph8b2App> pumpPh8b2(WidgetTester tester,
    {Size size = const Size(390, 844),
    MatrixLook look = MatrixLook.light,
    bool longNames = false,
    int maxFacilities = 9,
    Future<void> Function(FirebaseFirestore fs)? extra}) async {
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
    size: size,
    look: look,
    pushed: true,
    seed: (fs) async {
      await ph8bSeedFacilities(fs, longNames: longNames);
      await fs.collection(Collections.platformConfig).doc('settings').set({'maxFacilitiesPerAdmin': maxFacilities});
      await extra?.call(fs);
    },
  );
  return Ph8b2App(app, functions, storage);
}

Future<void> ph8b2Settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> ph8b2Tap(WidgetTester tester, Finder f) async {
  unawaited(Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5));
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await ph8b2Settle(tester);
}

/// Today's wide screen overflows a few pixels in the square test font (the
/// ph8b- fingerprints keep them): taken where a test looks at a wide screen.
void ph8b2DropOverflows(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// The list row of the facility [id].
Finder ph8b2Row(String id) => find.byKey(ValueKey('phoneList-row-$id'));

/// From the phone list: the facility [id]'s page.
Future<void> ph8b2OpenDetails(WidgetTester tester, [String id = testFacilityId]) => ph8b2Tap(tester, ph8b2Row(id));

/// From the facility's page: tab [index]'s page (1 Team Members to 5 Settings).
Future<void> ph8b2OpenTab(WidgetTester tester, int index) => ph8b2Tap(tester, ph8b2TabRow(index));

/// The texts of the menu's items, open.
List<String> ph8b2MenuTexts(WidgetTester tester) => [
      for (final item in tester.widgetList<PopupMenuItem<String>>(find.byWidgetPredicate((w) => w is PopupMenuItem<String>)))
        for (final t in tester.widgetList<Text>(find.descendant(of: find.byWidget(item), matching: find.byType(Text))))
          t.data ?? '',
    ];
