import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// RW2a (docs/design/register_wizard.md section 5): RegisterScreen takes an
// optional AuthService and MembershipService, as LoginScreen does, so the
// wizard tests of RW2b and RW2c can drive it without Firebase. With none
// given the real services are used, exactly as before.
// Written before the seams, skipped until they exist.
const _skip = true;

class _FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMembership implements MembershipService {
  final checked = <String>[];

  @override
  Future<InviteCheck?> checkInviteCode(String code) async {
    checked.add(code);
    return const InviteCheck(facilityName: 'Mwanga Agrovet', facilityType: 'Agrovet');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<dynamic> pump(WidgetTester tester, RegisterScreen screen) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: screen,
    ));
    await tester.pump();
    return tester.state(find.byType(RegisterScreen));
  }

  Future<void> typeInviteCode(WidgetTester tester, String code) async {
    await tester.tap(find.text('I have an invite code'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Enter your invite code'), code);
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pump();
  }

  testWidgets('the services given are the ones the screen uses', (tester) async {
    final auth = _FakeAuth();
    final membership = _FakeMembership();
    final state = await pump(
        tester, RegisterScreen(firestore: FakeFirebaseFirestore(), authService: auth, membershipService: membership));
    expect(identical(state.authServiceInUse, auth), isTrue);
    expect(identical(state.membershipServiceInUse, membership), isTrue);

    await typeInviteCode(tester, 'ABC123');
    expect(membership.checked, ['ABC123']);
    expect(find.text('Joining: Mwanga Agrovet'), findsOneWidget);
  }, skip: _skip);

  testWidgets('none given: the real services, unchanged', (tester) async {
    final state = await pump(tester, RegisterScreen(firestore: FakeFirebaseFirestore()));
    // Building did not reach Firebase (the services are made when first used).
    expect(tester.takeException(), isNull);
    // The real ones need a Firebase app, which a widget test does not have.
    expect(() => state.authServiceInUse, throwsA(isNot(isA<NoSuchMethodError>())));
    expect(() => state.membershipServiceInUse, throwsA(isNot(isA<NoSuchMethodError>())));

    // So the invite check runs the real service and fails the usual way.
    await typeInviteCode(tester, 'ABC123');
    expect(find.text("Couldn't check this code - try again"), findsOneWidget);
  }, skip: _skip);
}
