import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/services/facility_codes.dart';

// E4b (b3): profiles no longer carry users/{uid}.facilities[].code. Screens
// that show a facility's code read it from the facility document.
void main() {
  test('fetch reads each code from the facility document', () async {
    final db = FakeFirebaseFirestore();
    await db.collection(Collections.facilities).doc('F1').set({'name': 'Ukuli', 'code': 'AAAA1111'});
    await db.collection(Collections.facilities).doc('F2').set({'name': 'No code yet'});
    await db.collection(Collections.facilities).doc('F3').set({'name': 'Empty', 'code': ''});

    final codes = await FacilityCodes(firestore: db).fetch(['F1', 'F2', 'F3', 'gone', '', 'F1']);

    expect(codes, {'F1': 'AAAA1111'});
  });

  test('no ids, no reads', () async {
    expect(await FacilityCodes(firestore: FakeFirebaseFirestore()).fetch(const []), isEmpty);
  });

  // Every `['code']` read left in lib/, and why it is not a profile's copy.
  // A new one fails here until it is checked and added.
  test("no screen reads a facility code from a profile's facilities list", () {
    const allowed = {
      // The active invite from InviteCodeService (an inviteCodes document).
      'lib/screens/admin/invite_assistant_dialog.dart': 1,
      // A facilities/{id} document (Platform Admin directory).
      'lib/screens/platform_admin/facilities_directory_tab.dart': 2,
      // _codeOf's fallback for the unsaved sign-up list (no facility id
      // yet), and the typed invite code being redeemed.
      'lib/screens/register_screen.dart': 2,
      // createInviteCode's answer.
      'lib/services/membership_service.dart': 1,
    };
    final found = <String, int>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final count = "['code']".allMatches(file.readAsStringSync()).length;
      if (count > 0) found[file.path.replaceAll(r'\', '/')] = count;
    }
    expect(found, allowed);
  });

  test('the Platform Admin "Add to Facility" entry copies no code', () {
    final source = File('lib/screens/platform_admin/user_detail_screen.dart').readAsStringSync();
    expect(source.contains("'code'"), isFalse);
  });
}
