import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/widgets/profile/profile_photo_editor.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';

import 'helpers/register_harness.dart';

// RW2c (docs/design/register_wizard.md section 2, the RW2c batch): the
// assistant's five steps in the wizard, replacing the one-page form. Written
// before the change, skipped until it exists.
const _skip = false;

const _pets = InviteCheck(facilityName: 'Mwanza Pets', facilityType: 'Other', facilityTypeDetail: 'Pet shop');

void main() {
  final en = registerEn;
  String step(int n) => en.wizard_stepOf(n, 5);
  bool obscured(WidgetTester tester, String field) =>
      tester.widget<EditableText>(find.descendant(of: registerField(field), matching: find.byType(EditableText))).obscureText;

  Future<void> toStep2(WidgetTester tester) async {
    await tapText(tester, en.register_roleAssistantSubtitle);
    await tapContinue(tester);
  }

  Future<void> aboutYou(WidgetTester tester) async {
    await tapText(tester, AssistantInputs.prefix);
    await typeInto(tester, 'name', AssistantInputs.name);
    await typeInto(tester, 'phone', AssistantInputs.phone);
    await tapContinue(tester);
  }

  // Types a code and lets the debounced check answer.
  Future<void> typeCode(WidgetTester tester, String code) async {
    await typeInto(tester, 'invite', code);
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pumpAndSettle();
  }

  // Continue while the check is still running: no settling, which would
  // let the debounced check finish first.
  Future<void> continueNow(WidgetTester tester) async {
    await tester.tap(find.text(en.products_continue).last);
    await tester.pump();
  }

  Future<void> signIn(WidgetTester tester) async {
    await typeInto(tester, 'email', AssistantInputs.email);
    await typeInto(tester, 'password', AssistantInputs.password);
    await typeInto(tester, 'confirm', AssistantInputs.password);
    await tapContinue(tester);
  }

  Future<void> create(WidgetTester tester) async {
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
  }

  /// Steps 1 to 4 with AssistantInputs, ending on step 5.
  Future<void> fillAssistantSteps(WidgetTester tester) async {
    await toStep2(tester);
    await aboutYou(tester);
    await typeCode(tester, AssistantInputs.code);
    await tapContinue(tester);
    await signIn(tester);
  }

  final validOnly = {AssistantInputs.code.trim(): FakeRegisterMembership.mwanga, 'PETS22': _pets};

  testWidgets('step 2 for the assistant: photo, six titles, name, phone; Continue checks them', (tester) async {
    await pumpRegister(tester);
    await toStep2(tester);
    expect(find.byType(WizardStepHeader), findsOneWidget);
    expect(find.text(step(2)), findsOneWidget);
    expect(find.byType(ProfilePhotoEditor), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    await tapContinue(tester);
    expect(find.text(step(2)), findsOneWidget);
    expect(errorOf(tester, 'name'), en.register_enterFullName);
    expect(errorOf(tester, 'phone'), en.register_enterPhone);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 3: the invite code, checked as typed; Continue waits for a good one', (tester) async {
    final membership = FakeRegisterMembership(codes: validOnly);
    await pumpRegister(tester, membership: membership);
    await toStep2(tester);
    await aboutYou(tester);
    expect(find.text(en.register_stepInvite), findsWidgets);
    expect(find.text(en.register_askAdminForInvite), findsOneWidget);
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    expect(errorOf(tester, 'invite'), en.register_enterInviteCode);
    await typeInto(tester, 'invite', AssistantInputs.code);
    await continueNow(tester); // still checking
    expect(find.text(step(3)), findsOneWidget);
    expect(errorOf(tester, 'invite'), en.register_stillChecking);
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pumpAndSettle();
    expect(membership.checked, [AssistantInputs.code.trim()]);
    expect(find.text(en.register_joining('Mwanga Agrovet (Agrovet)')), findsOneWidget);
    await tapContinue(tester);
    expect(find.text(step(4)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('an Other facility shows its own words', (tester) async {
    await pumpRegister(tester, membership: FakeRegisterMembership(codes: validOnly));
    await toStep2(tester);
    await aboutYou(tester);
    await typeCode(tester, 'PETS22');
    expect(find.text(en.register_joining('Mwanza Pets (Pet shop)')), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('a wrong (or expired) code: the existing message, counted, Continue refused', (tester) async {
    final membership = FakeRegisterMembership(codes: validOnly, limit: 5);
    await pumpRegister(tester, membership: membership);
    await toStep2(tester);
    await aboutYou(tester);
    await typeCode(tester, 'OLD222');
    expect(find.text(en.register_inviteInvalid), findsOneWidget);
    expect(membership.wrong, 1);
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    expect(errorOf(tester, 'invite'), en.register_inviteInvalid);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('five wrong codes, then the sixth check shows the limit message', (tester) async {
    final membership = FakeRegisterMembership(codes: validOnly, limit: 5);
    await pumpRegister(tester, membership: membership);
    await toStep2(tester);
    await aboutYou(tester);
    for (final code in ['BAD001', 'BAD002', 'BAD003', 'BAD004', 'BAD005']) {
      await typeCode(tester, code);
    }
    expect(membership.wrong, 5);
    await typeCode(tester, AssistantInputs.code);
    final limit = MembershipService.errorMessage(FirebaseFunctionsException(code: 'resource-exhausted', message: 'x'));
    expect(find.text(limit), findsOneWidget);
    await tapContinue(tester);
    expect(errorOf(tester, 'invite'), limit);
    expect(find.text(step(3)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Back after a good code, then a new code: the old result is dropped and checked again', (tester) async {
    final membership = FakeRegisterMembership(codes: validOnly);
    await pumpRegister(tester, membership: membership);
    await toStep2(tester);
    await aboutYou(tester);
    await typeCode(tester, AssistantInputs.code);
    await tapContinue(tester);
    await tapBack(tester);
    expect(find.text(en.register_joining('Mwanga Agrovet (Agrovet)')), findsOneWidget, reason: 'kept on Back');
    await typeInto(tester, 'invite', 'PETS22');
    expect(find.text(en.register_joining('Mwanga Agrovet (Agrovet)')), findsNothing, reason: 'the old result goes at once');
    await continueNow(tester);
    expect(find.text(step(3)), findsOneWidget, reason: 'still checking the new code');
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pumpAndSettle();
    expect(membership.checked, [AssistantInputs.code.trim(), 'PETS22']);
    expect(find.text(en.register_joining('Mwanza Pets (Pet shop)')), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 4: no eyes, both hidden, the minimum and the match tick', (tester) async {
    await pumpRegister(tester);
    await toStep2(tester);
    await aboutYou(tester);
    await typeCode(tester, AssistantInputs.code);
    await tapContinue(tester);
    expect(find.text(step(4)), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.text(en.register_passwordRule), findsOneWidget);
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    expect(find.descendant(of: registerField('confirm'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(obscured(tester, 'password'), isTrue);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the review sums up; Create needs the box; then exactly the old form\'s call, once', (tester) async {
    final auth = FakeRegisterAuth();
    final membership = FakeRegisterMembership(codes: validOnly);
    await pumpRegister(tester, auth: auth, membership: membership);
    await fillAssistantSteps(tester);
    expect(find.text(step(5)), findsOneWidget);
    expect(find.text('Ms. Neema Juma'), findsOneWidget);
    expect(find.text('Mwanga Agrovet (Agrovet)'), findsOneWidget);
    expect(find.text('neema@example.com'), findsOneWidget);
    await tapText(tester, en.register_createAccount);
    expect(find.text(en.register_consentRequired), findsOneWidget);
    expect(auth.assistantCalls, isEmpty);
    await create(tester);
    expect(auth.assistantCalls, [AssistantInputs.recordedCall]);
    expect(auth.ownerCalls, isEmpty);
    // Waiting for approval: Sign in, as the old form did.
    expect(find.byKey(loginStandInKey), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the code expired or was used before Create: step 3 with the server\'s message', (tester) async {
    final auth = FakeRegisterAuth(
        assistantFailWith: FirebaseFunctionsException(code: 'failed-precondition', message: 'Invalid, expired, or already-used invite code'));
    await pumpRegister(tester, auth: auth, membership: FakeRegisterMembership(codes: validOnly));
    await fillAssistantSteps(tester);
    await create(tester);
    expect(find.text(step(3)), findsOneWidget);
    expect(errorOf(tester, 'invite'), 'Invalid, expired, or already-used invite code');
    expect(find.text(en.register_joining('Mwanga Agrovet (Agrovet)')), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('email already in use: step 4, the message, both passwords empty', (tester) async {
    final auth = FakeRegisterAuth(assistantFailWith: FirebaseAuthException(code: 'email-already-in-use'));
    await pumpRegister(tester, auth: auth);
    await fillAssistantSteps(tester);
    await create(tester);
    expect(find.text(step(4)), findsOneWidget);
    expect(errorOf(tester, 'email'), en.register_emailAlreadyRegistered);
    expect(textOf(tester, 'password'), isEmpty);
    expect(textOf(tester, 'confirm'), isEmpty);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('any other failure: step 4, the passwords emptied', (tester) async {
    final auth = FakeRegisterAuth(assistantFailWith: FirebaseAuthException(code: 'network-request-failed'));
    await pumpRegister(tester, auth: auth);
    await fillAssistantSteps(tester);
    await create(tester);
    expect(find.text(step(4)), findsOneWidget);
    expect(textOf(tester, 'password'), isEmpty);
    expect(obscured(tester, 'password'), isTrue);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('account made, sign-in failed: Sign in with the email filled in', (tester) async {
    final auth = FakeRegisterAuth(assistantFailWith: AccountCreatedException(en.register_accountCreatedSignIn));
    await pumpRegister(tester, auth: auth);
    await fillAssistantSteps(tester);
    await create(tester);
    expect(tester.widget<Text>(find.byKey(loginStandInKey)).data,
        'email=neema@example.com message=${en.register_accountCreatedSignIn}');
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Back keeps every answer (passwords hidden); the back gesture goes one step back', (tester) async {
    await pumpRegister(tester);
    await fillAssistantSteps(tester);
    await tapBack(tester);
    expect(textOf(tester, 'password'), AssistantInputs.password);
    expect(obscured(tester, 'password'), isTrue);
    await tapBack(tester);
    expect(textOf(tester, 'invite'), AssistantInputs.code);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(step(2)), findsOneWidget);
    expect(textOf(tester, 'name'), AssistantInputs.name);
    await finishRegister(tester);
  }, skip: _skip);

  test('the old one-page register form is gone', () {
    final src = File('lib/screens/register_screen.dart').readAsStringSync();
    for (final gone in ['_buildRegisterForm', '_buildAssistantFormBody', '_showsAssistantForm', '_buildSecuritySection', '_buildTermsLine']) {
      expect(src.contains(gone), isFalse, reason: gone);
    }
    expect(src.split('\n').length, lessThan(2050)); // 2270 lines before RW2c
  }, skip: _skip);
}
