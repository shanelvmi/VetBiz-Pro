import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/utils/facility_limit_helper.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';

import 'helpers/register_harness.dart';

// RW2b2 (docs/design/register_wizard.md, the owner's change to answer 6):
// no Sign in in the header (one link on phones), six titles, the facility
// type as an empty required dropdown with Other and its own words, no eye
// on the register passwords. Written before the change, skipped until it
// exists.
const _skip = false;

const _detail = 'Duka la mifugo na chakula cha kuku bora'; // 39 characters
const _longFacility = 'Kituo cha Mifugo na Kilimo cha Wilaya ya Kilimanjaro Magharibi';

void main() {
  final en = registerEn;
  String step(int n) => en.wizard_stepOf(n, 5);

  Future<void> toStep3(WidgetTester tester, [AppLocalizations? l10n]) async {
    final t = l10n ?? en;
    await tapContinue(tester, t);
    await typeInto(tester, 'name', 'Amina Juma');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester, t);
  }

  Future<void> addFacility(WidgetTester tester, String name, String typeLabel, {String? detail, AppLocalizations? l10n}) async {
    final t = l10n ?? en;
    await typeInto(tester, 'facility-name', name);
    await chooseFacilityType(tester, typeLabel);
    if (detail != null) await typeInto(tester, 'facility-type-detail', detail);
    await tapText(tester, t.common_add);
  }

  Future<void> fromStep4ToReview(WidgetTester tester, [AppLocalizations? l10n]) async {
    await typeInto(tester, 'email', 'amina@example.com');
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    await tapContinue(tester, l10n);
  }

  String? dropdownError(WidgetTester tester) =>
      tester.widget<InputDecorator>(find.descendant(of: registerField('facility-type'), matching: find.byType(InputDecorator))).decoration.errorText;

  group('header and sign-in link', () {
    for (final width in [360.0, 1200.0]) {
      testWidgets('$width: no Sign in in the header; one Sign in link on step 1 that opens Sign in', (tester) async {
        await pumpRegister(tester, size: Size(width, 900));
        expect(find.byIcon(Icons.login), findsNothing);
        expect(find.text(en.common_logIn), findsOneWidget);
        await tapText(tester, en.common_logIn);
        expect(find.byKey(loginStandInKey), findsOneWidget);
        await finishRegister(tester);
      }, skip: _skip);
    }
  });

  testWidgets('titles: six chips in order; the chosen one starts the name sent', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, auth: auth);
    await tapContinue(tester);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).map((c) => (c.label as Text).data).toList();
    expect(chips, ['Mr.', 'Mrs.', 'Ms.', 'Miss', 'Dr.', 'Prof.']);
    await tapText(tester, 'Prof.');
    await typeInto(tester, 'name', ' Amina Juma ');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester);
    await addFacility(tester, 'Mwanga', en.facilityTypeLabel('Agrovet'));
    await tapContinue(tester);
    await fromStep4ToReview(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    expect(auth.ownerCalls.single['fullName'], 'Prof. Amina Juma');
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('titles wrap on a phone', (tester) async {
    await pumpRegister(tester, size: const Size(360, 800));
    await tapContinue(tester);
    final tops = {for (final c in find.byType(ChoiceChip).evaluate()) tester.getTopLeft(find.byWidget(c.widget)).dy};
    expect(tops.length, greaterThan(1), reason: 'six chips need two rows at 360');
    expect(tester.takeException(), isNull);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('step 3: the type starts empty with its hint; Continue refuses until one is chosen', (tester) async {
    await pumpRegister(tester);
    await toStep3(tester);
    expect(find.byType(WizardOptionCard), findsNothing);
    expect(registerField('facility-type'), findsOneWidget);
    expect(find.text(en.facilityType_selectHint), findsOneWidget);
    expect(registerField('facility-type-detail'), findsNothing);
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    expect(dropdownError(tester), en.facilityType_required);
    await typeInto(tester, 'facility-name', 'Mwanga');
    await tapText(tester, en.common_add);
    expect(find.text(en.register_facilitiesAdded(0, kDefaultMaxFacilitiesPerAdmin)), findsOneWidget);
    expect(dropdownError(tester), en.facilityType_required);
    await chooseFacilityType(tester, en.facilityTypeLabel('Vet Clinic'));
    expect(dropdownError(tester), isNull);
    await tapText(tester, en.common_add);
    await tapContinue(tester);
    expect(find.text(step(4)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the options are the stored types with their labels: Ambulatory services', (tester) async {
    await pumpRegister(tester);
    await toStep3(tester);
    await tester.tap(registerField('facility-type'));
    await tester.pumpAndSettle();
    for (final label in ['Agrovet', 'Vet Clinic', 'Vet Hospital', 'Ambulatory services', 'Other']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Ambulatory Vet'), findsNothing);
    await tester.tap(find.text('Ambulatory services').last);
    await tester.pumpAndSettle();
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Other: its field appears, is required and checked, and the words are shown', (tester) async {
    await pumpRegister(tester);
    await toStep3(tester);
    await typeInto(tester, 'facility-name', 'Mwanza Pets');
    await chooseFacilityType(tester, en.facilityType_other);
    expect(registerField('facility-type-detail'), findsOneWidget);
    await tapText(tester, en.common_add);
    expect(errorOf(tester, 'facility-type-detail'), en.facilityType_detailLabel);
    await typeInto(tester, 'facility-type-detail', 'a');
    await tapText(tester, en.common_add);
    expect(errorOf(tester, 'facility-type-detail'), en.facilityType_detailLength(2, 40));
    await typeInto(tester, 'facility-type-detail', 'a' * 41);
    await tapText(tester, en.common_add);
    expect(errorOf(tester, 'facility-type-detail'), en.facilityType_detailLength(2, 40));
    await typeInto(tester, 'facility-type-detail', 'Pet/shop');
    await tapText(tester, en.common_add);
    expect(errorOf(tester, 'facility-type-detail'), en.facilityType_detailCharacters);
    expect(find.text(en.register_facilitiesAdded(0, kDefaultMaxFacilitiesPerAdmin)), findsOneWidget);
    // Continue with Other chosen and nothing added checks the words too.
    await tapContinue(tester);
    expect(find.text(step(3)), findsOneWidget);
    await typeInto(tester, 'facility-type-detail', '  Pet shop ');
    await tapText(tester, en.common_add);
    expect(find.text(en.register_facilitiesAdded(1, kDefaultMaxFacilitiesPerAdmin)), findsOneWidget);
    expect(find.textContaining('Pet shop'), findsOneWidget);
    expect(registerField('facility-type-detail'), findsNothing, reason: 'the type starts empty again');
    await tapContinue(tester);
    await fromStep4ToReview(tester);
    expect(find.text('Mwanza Pets (Pet shop)'), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the call carries typeDetail only for Other', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, auth: auth);
    await toStep3(tester);
    await addFacility(tester, 'Mwanza Pets', en.facilityType_other, detail: ' Pet shop ');
    await addFacility(tester, 'Ukuli', en.facilityTypeLabel('Agrovet'));
    await tapContinue(tester);
    await fromStep4ToReview(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    final sent = auth.ownerCalls.single['facilities'] as List;
    expect(sent[0]['type'], 'Other');
    expect(sent[0]['typeDetail'], 'Pet shop');
    expect(sent[1]['type'], 'Agrovet');
    expect((sent[1] as Map).containsKey('typeDetail'), isFalse);
    expect(sent.length, 2);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('another type after typing Other\'s words: they are dropped', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, auth: auth);
    await toStep3(tester);
    await typeInto(tester, 'facility-name', 'Ukuli');
    await chooseFacilityType(tester, en.facilityType_other);
    await typeInto(tester, 'facility-type-detail', 'Pet shop');
    await chooseFacilityType(tester, en.facilityTypeLabel('Vet Hospital'));
    expect(registerField('facility-type-detail'), findsNothing);
    await tapText(tester, en.common_add);
    await tapContinue(tester);
    await fromStep4ToReview(tester);
    await tickConsent(tester);
    await tapText(tester, en.register_createAccount);
    final sent = (auth.ownerCalls.single['facilities'] as List).single as Map;
    expect(sent.containsKey('typeDetail'), isFalse);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('passwords: no eye, both hidden; the minimum shown; the match tick kept', (tester) async {
    await pumpRegister(tester);
    await toStep3(tester);
    await addFacility(tester, 'Mwanga', en.facilityTypeLabel('Agrovet'));
    await tapContinue(tester);
    for (final field in ['password', 'confirm']) {
      expect(find.descendant(of: registerField(field), matching: find.byIcon(Icons.visibility_outlined)), findsNothing);
      expect(find.descendant(of: registerField(field), matching: find.byIcon(Icons.visibility_off_outlined)), findsNothing);
      expect(find.descendant(of: registerField(field), matching: find.byType(IconButton)), findsNothing);
    }
    expect(find.text(en.register_passwordRule), findsOneWidget);
    expect(en.register_passwordRule, contains('8'));
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    expect(find.descendant(of: registerField('confirm'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    for (final field in ['password', 'confirm']) {
      expect(tester.widget<EditableText>(find.descendant(of: registerField(field), matching: find.byType(EditableText))).obscureText, isTrue);
    }
    await finishRegister(tester);
  }, skip: _skip);

  for (final width in [360.0, 390.0, 768.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        testWidgets('no overflow with Other and its words at $width, ${brightness.name}, ${locale.languageCode}', (tester) async {
          final t = locale.languageCode == 'sw' ? registerSw : en;
          await pumpRegister(tester, size: Size(width, 800), brightness: brightness, locale: locale);
          await toStep3(tester, t);
          await typeInto(tester, 'facility-name', _longFacility);
          await chooseFacilityType(tester, t.facilityType_other);
          await tapText(tester, t.common_add);
          expect(tester.takeException(), isNull, reason: 'the errors under the type');
          await typeInto(tester, 'facility-type-detail', _detail);
          await tapText(tester, t.common_add);
          expect(tester.takeException(), isNull, reason: 'step 3 with the words');
          await tapContinue(tester, t);
          await fromStep4ToReview(tester, t);
          expect(find.text(t.wizard_stepOf(5, 5)), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'the review');
          await finishRegister(tester);
        }, skip: _skip);
      }
    }
  }
}
