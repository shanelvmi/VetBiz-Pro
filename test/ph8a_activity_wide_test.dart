// PH8a (5): the Activity log. Recorded from the code before PH8a: an admin's
// and an assistant's log at 768x1024, 1024x768 and 1200x800 (the ph8a- names
// in test/fixtures/ph5a_wide_fingerprints.json); after PH8a they still match.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

/// Six entries over three days (two of them the signed-in person's, one about
/// them), with a long Kiswahili name in one description.
Future<void> seedActivity(FirebaseFirestore fs) async {
  final logs = facilityCollection(fs, Collections.activityLogs);
  final now = DateTime.now();
  Future<void> log(String id, Duration ago, String type, String description,
          {String user = 'admin2', String name = 'Juma Hassan', String? target}) =>
      logs.doc(id).set({
        'timestamp': Timestamp.fromDate(now.subtract(ago)),
        'userId': user,
        'userName': name,
        'actionType': type,
        'description': description,
        if (target != null) 'targetUserId': target,
      });
  await log('a1', const Duration(minutes: 30), 'Sales', 'Recorded sale to $matrixLongClientName - Tsh 45,000',
      user: testUserId, name: 'Asha Mushi');
  await log('a2', const Duration(hours: 2), 'Products', 'Added product Albendazole 10%');
  await log('a3', const Duration(days: 1, hours: 1), 'Trash', 'Restored Amina Juma');
  await log('a4', const Duration(days: 1, hours: 3), 'Account', 'Approved Asha Mushi', target: testUserId);
  await log('a5', const Duration(days: 2), 'Payments', 'Recorded payment of Tsh 20,000', user: testUserId, name: 'Asha Mushi');
  await log('a6', const Duration(days: 2, hours: 4), 'Sales', 'Recorded sale to Walk-in - Tsh 9,000');
}

Future<Ph5App> pumpActivity(WidgetTester tester,
        {required dynamic size, bool admin = true, bool modal = false, MatrixLook look = MatrixLook.light, FirebaseFirestore? fs}) =>
    pumpPh5(tester, (fs) => ActivityLogScreen(isModal: modal, firestore: fs, auth: Ph8Auth()),
        size: size, look: look, admin: admin, pushed: true, firestore: fs, seed: seedActivity);

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    for (final admin in [true, false]) {
      final name = 'ph8a-activity-${admin ? 'admin' : 'assistant'}-$at';
      ph5TestWidgets('$name: as before PH8a', (tester) async {
        await pumpActivity(tester, size: size, admin: admin, modal: size.width >= 900);
        expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, find.byType(ActivityLogScreen).first)}');
      });
    }
  }
}
