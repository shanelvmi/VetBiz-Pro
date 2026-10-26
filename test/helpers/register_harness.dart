import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

/// RW2b: the register wizard driven without Firebase, through the RW2a
/// seams. Creating an owner is recorded and then fails with [failWith]
/// (a test that needs the success path stops at the recorded call).
class FakeRegisterAuth implements AuthService {
  FakeRegisterAuth({this.failWith});

  Object? failWith;
  final ownerCalls = <Map<String, Object?>>[];
  final assistantCalls = <Map<String, Object?>>[];

  @override
  Future<List<Map<String, dynamic>>> registerOwnerAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required List<Map<String, dynamic>> facilities,
  }) async {
    ownerCalls.add({
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
      // A copy: the screen's own list may change after the call.
      'facilities': [for (final f in facilities) Map<String, dynamic>.of(f)],
    });
    throw failWith ?? Exception('test stops after the call');
  }

  @override
  Future<void> registerAssistantWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String inviteCode,
    dynamic avatarBytes,
  }) async {
    assistantCalls.add({'email': email, 'inviteCode': inviteCode});
  }

  // Nobody is signed in while registering.
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRegisterMembership implements MembershipService {
  final checked = <String>[];

  @override
  Future<InviteCheck?> checkInviteCode(String code) async {
    checked.add(code);
    return const InviteCheck(facilityName: 'Mwanga Agrovet', facilityType: 'Agrovet');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final AppLocalizations registerEn = lookupAppLocalizations(const Locale('en'));
final AppLocalizations registerSw = lookupAppLocalizations(const Locale('sw'));

/// The wizard's own fields, by the keys the screen gives them.
Finder registerField(String name) => find.byKey(ValueKey<String>('register-$name'));

/// What the '/login' route was opened with (the AccountCreatedException
/// case), shown as text so a test can read it.
const loginStandInKey = ValueKey<String>('login-stand-in');

Future<void> pumpRegister(
  WidgetTester tester, {
  FakeRegisterAuth? auth,
  FakeRegisterMembership? membership,
  Size size = const Size(1200, 900),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double keyboard = 0,
  bool overHome = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final screen = RegisterScreen(
    firestore: FakeFirebaseFirestore(),
    authService: auth ?? FakeRegisterAuth(),
    membershipService: membership ?? FakeRegisterMembership(),
  );
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.build(AppColorTheme.pasture, brightness),
    darkTheme: AppTheme.build(AppColorTheme.pasture, Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: Duration.zero,
    // Today's register page is pushed over the sign-in page (AppEntryPoint).
    home: overHome ? const Scaffold(body: Text('home')) : screen,
    routes: {
      '/login': (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        return Scaffold(
          body: Text(
            // dynamic: written before the screen's LoginPrefill existed.
            args == null ? 'login' : 'email=${(args as dynamic).email} message=${(args as dynamic).message}',
            key: loginStandInKey,
          ),
        );
      },
    },
  ));
  await tester.pump();
  if (overHome) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pumpAndSettle();
  }
}

/// Ends with every timer the screen started run out.
Future<void> finishRegister(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> tapContinue(WidgetTester tester, [AppLocalizations? l10n]) =>
    tapText(tester, (l10n ?? registerEn).products_continue);

Future<void> tapBack(WidgetTester tester, [AppLocalizations? l10n]) => tapText(tester, (l10n ?? registerEn).wizard_back);

Future<void> typeInto(WidgetTester tester, String field, String text) async {
  await tester.ensureVisible(registerField(field));
  await tester.enterText(registerField(field), text);
  await tester.pump();
}

String? errorOf(WidgetTester tester, String field) =>
    tester.widget<TextField>(registerField(field)).decoration?.errorText;

String textOf(WidgetTester tester, String field) => tester.widget<TextField>(registerField(field)).controller!.text;

/// The owner inputs every equality test uses (also typed into the old
/// one-page form to record its call, see rw2b_register_wizard_test.dart).
class OwnerInputs {
  static const prefix = 'Dr.';
  static const name = '  Amina Juma ';
  static const email = ' amina@example.com ';
  static const phone = ' 0712 345 678 ';
  static const facilityName = 'Mwanga agrovet';
  static const facilityType = 'Vet Clinic';
  static const password = ' Secret123 ';
}

/// Steps 1 to 4 of the owner flow with [OwnerInputs], ending on step 5.
Future<void> fillOwnerSteps(WidgetTester tester, {AppLocalizations? l10n, String name = OwnerInputs.name, String facilityName = OwnerInputs.facilityName}) async {
  final t = l10n ?? registerEn;
  await tapContinue(tester, t); // step 1: the owner is preselected
  await tapText(tester, OwnerInputs.prefix);
  await typeInto(tester, 'name', name);
  await typeInto(tester, 'phone', OwnerInputs.phone);
  await tapContinue(tester, t);
  await typeInto(tester, 'facility-name', facilityName);
  await tapText(tester, t.facilityTypeLabel(OwnerInputs.facilityType));
  await tapText(tester, t.common_add);
  await tapContinue(tester, t);
  await typeInto(tester, 'email', OwnerInputs.email);
  await typeInto(tester, 'password', OwnerInputs.password);
  await typeInto(tester, 'confirm', OwnerInputs.password);
  await tapContinue(tester, t);
}

Future<void> tickConsent(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

/// RW2b2: step 3's facility type is a dropdown (key register-facility-type):
/// open it and pick the option shown as [label].
Future<void> chooseFacilityType(WidgetTester tester, String label) async {
  final field = registerField('facility-type');
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
