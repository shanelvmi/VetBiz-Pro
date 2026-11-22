// UX8 Fix 2: Remove logo on Business Profile (the identity card on PC and
// tablet, the action bar on a phone). Shown to an admin only when there is a
// logo; asks first; removes logoUrl from the facility document and the
// uploaded file; Cancel keeps both; a failed write shows an error and keeps
// the logo.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/fake_storage.dart';
import 'helpers/phone_list_harness.dart';

const _url = 'https://example.test/logo.png?alt=media&cb=1';

Future<void> _withLogo(FirebaseFirestore fs) =>
    facilityDoc(fs).set({'type': 'Agrovet', 'logoUrl': _url}, SetOptions(merge: true));

Future<Map<String, dynamic>> _facility(WidgetTester tester, FirebaseFirestore fs) async =>
    (await tester.runAsync(() async => (await facilityDoc(fs).get()).data() ?? <String, dynamic>{}))!;

/// The app listens to the facility from sign-in; the harness does not.
Future<void> _listen(WidgetTester tester) async {
  Provider.of<FacilityProvider>(tester.element(find.byType(BusinessProfileScreen)), listen: false)
      .listenToFacility(testFacilityId);
  await ph5Settle(tester);
  while (tester.takeException() != null) {} // the network image in tests
}

Finder _remove(bool phone) => find.byKey(ValueKey(phone ? 'formActionBar-secondary' : 'business-remove-logo'));

void main() {
  for (final (size, phone) in const [(Size(1200, 800), false), (Size(390, 844), true)]) {
    final at = '${size.width.toInt()}';

    ph5TestWidgets('$at: Remove logo, confirmed, clears the field and the file', (tester) async {
      final storage = FakeStorage();
      final app = await pumpPh5(tester, (fs) => BusinessProfileScreen(firestore: fs, storage: storage),
          size: size, pushed: true, seed: _withLogo);
      await _listen(tester);
      await tester.tap(_remove(phone));
      await ph5Settle(tester);
      await tester.tap(find.byKey(const ValueKey('business-remove-logo-confirm')));
      await ph5Settle(tester);
      while (tester.takeException() != null) {}
      expect((await _facility(tester, app.fs)).containsKey('logoUrl'), isFalse);
      expect(storage.deletes, ['facility_logos/$testFacilityId.png']);
      expect(find.text('Logo removed'), findsOneWidget);
      expect(_remove(phone), findsNothing, reason: 'no logo, no Remove');
    });

    ph5TestWidgets('$at: Cancel keeps the logo', (tester) async {
      final storage = FakeStorage();
      final app = await pumpPh5(tester, (fs) => BusinessProfileScreen(firestore: fs, storage: storage),
          size: size, pushed: true, seed: _withLogo);
      await _listen(tester);
      await tester.tap(_remove(phone));
      await ph5Settle(tester);
      await tester.tap(find.byKey(const ValueKey('business-remove-logo-cancel')));
      await ph5Settle(tester);
      while (tester.takeException() != null) {}
      expect((await _facility(tester, app.fs))['logoUrl'], _url);
      expect(storage.deletes, isEmpty);
      expect(_remove(phone), findsOneWidget);
    });

    ph5TestWidgets('$at: no logo, no Remove logo', (tester) async {
      await pumpPh5(tester, (fs) => BusinessProfileScreen(firestore: fs, storage: FakeStorage()),
          size: size, pushed: true);
      expect(_remove(phone), findsNothing);
    });

    ph5TestWidgets('$at: an assistant sees no Remove logo', (tester) async {
      await pumpPh5(tester, (fs) => BusinessProfileScreen(firestore: fs, storage: FakeStorage()),
          size: size, pushed: true, seed: _withLogo, admin: false);
      await _listen(tester);
      expect(_remove(phone), findsNothing);
    });
  }

  ph5TestWidgets('a failed write shows an error and keeps the logo', (tester) async {
    final storage = FakeStorage();
    final app = await pumpPh5(tester, (fs) => BusinessProfileScreen(firestore: fs, storage: storage),
        size: const Size(1200, 800), pushed: true, seed: _withLogo);
    await _listen(tester);
    // The document gone: the update is refused (not-found); the page still
    // holds the logo it had.
    await tester.runAsync(() => facilityDoc(app.fs).delete());
    await ph5Settle(tester);
    await tester.tap(_remove(false));
    await ph5Settle(tester);
    await tester.tap(find.byKey(const ValueKey('business-remove-logo-confirm')));
    await ph5Settle(tester);
    while (tester.takeException() != null) {}
    expect(find.text("Couldn't update the logo"), findsOneWidget);
    expect(storage.deletes, isEmpty);
    expect(_remove(false), findsOneWidget);
  });
}
