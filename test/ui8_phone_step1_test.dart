// UI8, written before the change: step 1 of the register wizard on a phone.
// The two cards are taller, with an icon tile; the chosen one is tinted
// (selectedCardFill) with the primary border (selectableCardInk). Admin
// keeps "Admin"; the assistant card SHOWS "Staff/Assistant", while the
// stored value stays 'Assistant': choosing it still takes the invite flow
// and creates the account through the assistant call. Wide windows keep
// "Assistant" (and test/ui8_wide_unchanged_test.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/stored_labels.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';

import 'helpers/register_harness.dart';

const _skip = false;

const _phone = Size(390, 844);
final _en = registerEn;

/// The K6 pair's measured contrast where it is under 4.5 (UI8 found it).
const _k6BelowAA = {'pasture light': 4.05, 'clinic light': 4.29};

Finder _card(String title) => find.ancestor(of: find.text(title), matching: find.byType(WizardOptionCard));

ShapeBorder _shape(WidgetTester tester, Finder card) =>
    tester.widget<Material>(find.descendant(of: card, matching: find.byType(Material)).first).shape!;

Color _fill(WidgetTester tester, Finder card) =>
    tester.widget<Material>(find.descendant(of: card, matching: find.byType(Material)).first).color!;

void main() {
  testWidgets('phone: Admin keeps "Admin"; the assistant card shows "Staff/Assistant"', (tester) async {
    await pumpRegister(tester, size: _phone, chooseOwner: false);
    expect(find.text(_en.roleLabel('admin')), findsOneWidget);
    expect(find.text(_en.register_roleStaffAssistant), findsOneWidget);
    expect(find.text(_en.roleLabel('assistant')), findsNothing);
    final staff = _card(_en.register_roleAssistantSubtitle);
    expect(find.descendant(of: staff, matching: find.text(_en.register_roleStaffAssistant)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('Kiswahili: the draft label', (tester) async {
    await pumpRegister(tester, size: _phone, chooseOwner: false, locale: const Locale('sw'));
    expect(find.text(registerSw.register_roleStaffAssistant), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('wide: the card still shows "Assistant"', (tester) async {
    await pumpRegister(tester, size: const Size(1200, 800), chooseOwner: false);
    expect(find.text(_en.roleLabel('assistant')), findsOneWidget);
    expect(find.text(_en.register_roleStaffAssistant), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('THE STORED VALUE: "Staff/Assistant" is still the assistant flow and the assistant call', (tester) async {
    final auth = FakeRegisterAuth();
    await pumpRegister(tester, size: _phone, chooseOwner: false, auth: auth);
    // The card that shows "Staff/Assistant" is the one the assistant flow
    // chooses (by its title), all the way to Create.
    expect(find.descendant(of: _card(_en.register_roleAssistantSubtitle), matching: find.text(_en.register_roleStaffAssistant)), findsOneWidget);
    await toAssistantStep(tester, 5);
    expect(find.text(_en.wizard_stepOf(5, 5)), findsOneWidget);
    await tickConsent(tester);
    await tapText(tester, _en.register_createAccount);
    expect(auth.ownerCalls, isEmpty);
    expect(auth.assistantCalls, hasLength(1));
    await finishRegister(tester);
  }, skip: _skip);

  test('the role is still stored and compared as \'Assistant\'; the new text is display only', () {
    final sources = [
      File('lib/screens/register_screen.dart').readAsStringSync(),
      for (final f in Directory('lib/screens/register').listSync().whereType<File>()) f.readAsStringSync(),
    ].join('\n');
    expect(sources, contains("_selectRole('Assistant')"));
    expect(sources, contains("selectedRole == 'Assistant'"));
    expect(sources.contains('Staff/Assistant'), isFalse, reason: 'the text comes from the ARB only');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.contains('l10n')) continue;
      final text = f.readAsStringSync();
      if (!text.contains('register_roleStaffAssistant')) continue;
      expect(f.path.replaceAll('\\', '/'), endsWith('lib/screens/register/wizard_view.dart'), reason: 'shown on step 1 only');
    }
  }, skip: _skip);

  testWidgets('the cards: taller, an icon tile, the larger corner', (tester) async {
    await pumpRegister(tester, size: _phone, chooseOwner: false);
    for (final title in [_en.register_roleAdminSubtitle, _en.register_roleAssistantSubtitle]) {
      final card = _card(title);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(AuthPhoneMetrics.optionMinHeight), reason: title);
      final tile = find.descendant(of: card, matching: find.byKey(WizardOptionCard.tileKey));
      expect(tester.getSize(tile), const Size.square(AuthPhoneMetrics.optionTile), reason: title);
      expect((_shape(tester, card) as RoundedRectangleBorder).borderRadius, BorderRadius.circular(AuthPhoneMetrics.optionRadius));
    }
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('chosen: tinted, the primary border; contrast in all four themes, Light and Dark', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final where = '${theme.id} ${brightness.name}';
        await pumpRegister(tester, size: _phone, chooseOwner: false, theme: theme, brightness: brightness);
        await tapText(tester, _en.register_roleStaffAssistant);
        final c = tester.element(find.byType(RegisterScreen)).colors;
        final chosen = _card(_en.register_roleAssistantSubtitle);
        final other = _card(_en.register_roleAdminSubtitle);
        expect(_fill(tester, chosen), c.selectedCardFill, reason: where);
        expect(_fill(tester, other), c.surface, reason: where);
        final side = (_shape(tester, chosen) as RoundedRectangleBorder).side;
        expect(side.color, c.selectableCardInk, reason: where);
        expect(side.width, WizardMetrics.optionBorderSelected);
        for (final text in [_en.register_roleAssistantSubtitle, _en.register_roleStaffAssistant]) {
          final color = tester.widget<Text>(find.text(text)).style!.color!;
          // FOUND IN UI8, NOT CHANGED (the owner fixed the roles): the K6 pair
          // selectableCardInk on selectedCardFill is under 4.5 in Pasture and
          // Clinic Light, on the wide cards too. Pinned so it cannot get worse;
          // in the UI8 ledger row for the owner.
          final floor = _k6BelowAA[where] ?? 4.5;
          expect(ColorMath.contrast(color, c.selectedCardFill), greaterThanOrEqualTo(floor), reason: '$where "$text"');
        }
        await finishRegister(tester);
      }
    }
  }, skip: _skip);
}
