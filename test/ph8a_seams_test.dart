// PH8a seams: the screens PH8a changes, built in a test on a fake Firestore
// (optional firestore:, auth: and storage: parameters defaulting to the
// app's own; no behaviour change). One smoke test each.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/phone_list_harness.dart';

class Ph8User extends Fake implements User {
  @override
  String get uid => testUserId;
  @override
  String? get email => 'owner@kilimo.co.tz';
}

class Ph8Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => Ph8User();
}

void main() {
  ph5TestWidgets('Subscription builds on a fake Firestore', (tester) async {
    await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
        size: const Size(1200, 800), pushed: true);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  settingsSeams();
}

/// The seams of the Settings pages (part 4), each built at a wide size.
void settingsSeams() {
  for (final (name, build) in <(String, Widget Function(FirebaseFirestore fs))>[
    ('Business profile', (fs) => BusinessProfileScreen(firestore: fs, storage: FakeStorage())),
    ('Business hours', (fs) => BusinessHoursScreen(firestore: fs)),
    ('Trash', (fs) => TrashScreen(firestore: fs, currentUserInfo: () async => {'userId': testUserId, 'userName': 'Asha'})),
    ('Export', (fs) => ExportDataScreen(firestore: fs)),
    ('Manage Account', (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth())),
    ('Settings', (fs) => SettingsScreen(firestore: fs, auth: Ph8Auth())),
  ]) {
    ph5TestWidgets('$name builds on a fake Firestore', (tester) async {
      await pumpPh5(tester, build, size: const Size(1200, 800), pushed: true);
      expect(tester.takeException(), isNull);
    });
  }
}
