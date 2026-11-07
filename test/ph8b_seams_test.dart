// PH8b seams: Team Members and Facilities built in a test on a fake Firestore
// (optional firestore:, auth:, storage: and the server's membership:
// parameters defaulting to the app's own; no behaviour change). One smoke
// test each.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';

import 'helpers/fake_storage.dart';
import 'helpers/ph8b_facilities.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';

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
}
