// PH8b seams: Team Members and Facilities built in a test on a fake Firestore
// (optional firestore:, auth:, storage: and the server's membership:
// parameters defaulting to the app's own; no behaviour change). One smoke
// test each.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';

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
}
