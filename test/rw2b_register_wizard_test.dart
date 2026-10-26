import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';

import 'helpers/register_harness.dart';

// RW2b (docs/design/register_wizard.md sections 2, 4 and 5, with the
// owner's answers): the owner flow as five steps. Written before the
// wizard, skipped until it exists; unskipped on the old one-page form they
// fail (no "Step 1 of 5", every field on one page).
const _skip = true;

// The call the OLD one-page form made for OwnerInputs, recorded by typing
// them into it (title Dr., the facility added, Create account) before the
// wizard was written. The facility code is random (generateUniqueFacilityCode),
// so it is checked by shape.
const _oldCall = {
  'email': 'amina@example.com',
  'password': 'Secret123',
  'fullName': 'Dr. Amina Juma',
  'phone': '0712 345 678',
};
const _oldFacility = {'name': 'Mwanga agrovet', 'type': 'Vet Clinic', 'facilityId': ''};

void main() {
  final en = registerEn;
  String step(int n) => en.wizard_stepOf(n, 5);
  bool focused(WidgetTester tester, String field) => tester
      .state<EditableTextState>(find.descendant(of: registerField(field), matching: find.byType(EditableText)))
      .widget
      .focusNode
      .hasFocus;

  testWidgets('opens on step 1: the two choices and Continue only', (tester) async {
    await pumpRegister(tester);
    expect(find.text(step(1)), findsOneWidget);
    expect(find.byType(WizardOptionCard), findsNWidgets(2));
    expect(find.text(en.register_roleAdminSubtitle), findsOneWidget);
    expect(find.text(en.register_roleAssistantSubtitle), findsOneWidget);
    expect(find.text(en.products_continue), findsOneWidget);
    expect(find.text(en.wizard_back), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Continue shows only its own step\'s errors, stays, focuses the first', (tester) async {
    await pumpRegister(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    expect(find.text(step(2)), findsOneWidget);
    expect(errorOf(tester, 'name'), en.register_enterFullName);
    expect(errorOf(tester, 'phone'), en.register_enterPhone);
    expect(focused(tester, 'name'), isTrue);
    // No toast for field errors (the toast wears this icon).
    expect(find.byIcon(Icons.error_outline), findsNothing);

    await typeInto(tester, 'name', 'Amina Juma');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    expect(find.text(en.register_addOneFacilityHow), findsOneWidget);

    await typeInto(tester, 'facility-name', 'Mwanga');
    await tapText(tester, en.facilityTypeLabel('Agrovet'));
    await tapText(tester, en.common_add);
    await tapContinue(tester);
    // Step 4 opens clean: nothing was flagged for fields not reached yet.
    expect(find.text(step(4)), findsOneWidget);
    expect(errorOf(tester, 'email'), isNull);
    expect(errorOf(tester, 'password'), isNull);
    await tapContinue(tester);
    expect(errorOf(tester, 'email'), en.register_enterEmail);
    expect(errorOf(tester, 'password'), en.register_createPassword);
    expect(errorOf(tester, 'confirm'), en.register_reenterToConfirm);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 4: an invalid email, a short password, a mismatch', (tester) async {
    await pumpRegister(tester);
    await fillOwnerSteps(tester);
    await tapBack(tester);
    await typeInto(tester, 'email', 'amina@example');
    await typeInto(tester, 'password', 'abc1');
    await typeInto(tester, 'confirm', 'abc2');
    await tapContinue(tester);
    expect(find.text(step(4)), findsOneWidget);
    expect(errorOf(tester, 'email'), en.register_validEmailExample);
    expect(errorOf(tester, 'password'), en.register_pwMin8);
    expect(errorOf(tester, 'confirm'), en.common_passwordsDoNotMatch);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Back keeps every typed value except the passwords', (tester) async {
    await pumpRegister(tester);
    await fillOwnerSteps(tester);
    expect(find.text(step(5)), findsOneWidget);
    await tapBack(tester);
    expect(textOf(tester, 'email'), OwnerInputs.email);
    expect(textOf(tester, 'password'), isEmpty);
    expect(textOf(tester, 'confirm'), isEmpty);
    await tapBack(tester);
    expect(find.text(OwnerInputs.facilityName), findsOneWidget);
    await tapBack(tester);
    expect(textOf(tester, 'name'), OwnerInputs.name);
    expect(textOf(tester, 'phone'), OwnerInputs.phone);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, OwnerInputs.prefix)).selected, isTrue);
    await tapContinue(tester);
    await tapContinue(tester);
    expect(textOf(tester, 'email'), OwnerInputs.email);
    expect(textOf(tester, 'password'), isEmpty);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 2 has the title as chips; step 3 the types as option cards', (tester) async {
    await pumpRegister(tester);
    await tapContinue(tester);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    await typeInto(tester, 'name', 'Amina');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester);
    expect(find.byType(WizardOptionCard), findsNWidgets(5));
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the review step sums up each step; Change opens it', (tester) async {
    await pumpRegister(tester);
    await fillOwnerSteps(tester);
    expect(find.text(step(5)), findsOneWidget);
    expect(find.textContaining('Dr. Amina Juma'), findsOneWidget);
    expect(find.textContaining('amina@example.com'), findsOneWidget);
    expect(find.textContaining(OwnerInputs.facilityName), findsOneWidget);
    expect(find.text(en.common_change), findsNWidgets(4));
    await tapText(tester, en.common_change);
    expect(find.text(step(4)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Create sends exactly the old form\'s call, once, only at the end', (tester) async {
    final auth = FakeRegisterAuth();
    final membership = FakeRegisterMembership();
    await pumpRegister(tester, auth: auth, membership: membership);
    await fillOwnerSteps(tester);
    expect(auth.ownerCalls, isEmpty);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    expect(auth.ownerCalls, hasLength(1));
    final call = Map<String, Object?>.of(auth.ownerCalls.single);
    final facilities = call.remove('facilities') as List;
    expect(call, _oldCall);
    expect(facilities, hasLength(1));
    final facility = Map<String, dynamic>.of(facilities.single as Map<String, dynamic>);
    expect(facility.remove('code'), matches(RegExp(r'^[A-Z0-9]{8}$')));
    expect(facility, _oldFacility);
    expect(membership.checked, isEmpty);
    expect(auth.assistantCalls, isEmpty);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the consent box blocks Create and says why', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, auth: auth);
    await fillOwnerSteps(tester);
    await tapText(tester, en.register_createAccount);
    expect(auth.ownerCalls, isEmpty);
    expect(find.text(en.register_consentRequired), findsOneWidget);
    expect(find.text(step(5)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('email already in use: back to step 4, the message under the email', (tester) async {
    final auth = FakeRegisterAuth(failWith: FirebaseAuthException(code: 'email-already-in-use'));
    await pumpRegister(tester, auth: auth);
    await fillOwnerSteps(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    expect(find.text(step(4)), findsOneWidget);
    expect(errorOf(tester, 'email'), en.register_emailAlreadyRegistered);
    expect(textOf(tester, 'password'), isEmpty);
    expect(textOf(tester, 'confirm'), isEmpty);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('any other failure: step 4, the passwords emptied', (tester) async {
    final auth = FakeRegisterAuth(failWith: FirebaseAuthException(code: 'network-request-failed'));
    await pumpRegister(tester, auth: auth);
    await fillOwnerSteps(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    expect(find.text(step(4)), findsOneWidget);
    expect(textOf(tester, 'password'), isEmpty);
    expect(textOf(tester, 'email'), OwnerInputs.email);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('account made, sign-in failed: the Sign in page with the email filled in', (tester) async {
    final auth = FakeRegisterAuth(failWith: AccountCreatedException(en.register_accountCreatedSignIn));
    await pumpRegister(tester, auth: auth);
    await fillOwnerSteps(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    expect(tester.widget<Text>(find.byKey(loginStandInKey)).data,
        'email=amina@example.com message=${en.register_accountCreatedSignIn}');
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Enter on a step\'s last field continues', (tester) async {
    await pumpRegister(tester);
    await tapContinue(tester);
    await typeInto(tester, 'name', 'Amina');
    await typeInto(tester, 'phone', '0712 345 678');
    await tester.showKeyboard(registerField('phone'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(step(3)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the back gesture goes one step back; on step 1 it leaves', (tester) async {
    await pumpRegister(tester, overHome: true);
    await tapContinue(tester);
    await typeInto(tester, 'name', 'Amina');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(step(2)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(step(1)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('"I have an invite code" still opens today\'s assistant form', (tester) async {
    final membership = FakeRegisterMembership();
    await pumpRegister(tester, membership: membership);
    await tapText(tester, en.register_roleAssistantSubtitle);
    await tapContinue(tester);
    expect(find.byType(WizardStepHeader), findsNothing);
    expect(find.text(en.register_enterInviteCode), findsOneWidget);
    expect(find.text(en.register_createAccount), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, en.register_enterInviteCode), 'ABC123');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(membership.checked, ['ABC123']);
    await finishRegister(tester);
  }, skip: _skip);

  test('nothing is kept after a reload: no device or browser storage', () {
    final files = [
      File('lib/screens/register_screen.dart'),
      ...Directory('lib/screens/register').listSync().whereType<File>(),
    ];
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final banned in ['SharedPreferences', 'localStorage', 'sessionStorage', 'package:web', 'dart:html']) {
        expect(src.contains(banned), isFalse, reason: '${file.path} uses $banned');
      }
    }
  }, skip: _skip);
}
