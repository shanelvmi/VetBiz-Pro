// PH8a seams: the screens PH8a changes, built in a test on a fake Firestore
// (optional firestore:, auth: and storage: parameters defaulting to the
// app's own; no behaviour change). One smoke test each.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';

import 'helpers/fake_firestore.dart';
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
}
