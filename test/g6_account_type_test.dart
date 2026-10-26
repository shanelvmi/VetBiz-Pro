import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';

import 'helpers/register_harness.dart';

// G6, the owner's report: registration step 1 must not pre-select the account
// type. Nothing is chosen at first; each card is a toggle; Continue with
// nothing chosen stays on step 1 with the step's error in the line kept for
// it (nothing changes height). Written before the change (skipped until it
// exists).
const _skip = false;

void main() {
  final en = registerEn;
  String step(int n) => en.wizard_stepOf(n, 5);
  String error(AppLocalizations t) => t.register_chooseAccountType(AppInfo.name);

  Finder owner(AppLocalizations t) => find.widgetWithText(WizardOptionCard, t.register_roleAdminSubtitle);
  Finder assistant(AppLocalizations t) => find.widgetWithText(WizardOptionCard, t.register_roleAssistantSubtitle);
  bool selected(WidgetTester tester, Finder card) => tester.widget<WizardOptionCard>(card).selected;
  List<bool> choice(WidgetTester tester) => [selected(tester, owner(en)), selected(tester, assistant(en))];

  testWidgets('nothing is selected on first show (and Semantics says so)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRegister(tester, chooseOwner: false);
    expect(find.text(step(1)), findsOneWidget);
    expect(choice(tester), [false, false]);
    for (final card in [owner(en), assistant(en)]) {
      expect(tester.getSemantics(card), isSemantics(isSelected: false, isButton: true, isInMutuallyExclusiveGroup: true));
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    }
    expect(find.text(error(en)), findsNothing);
    handle.dispose();
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the cards are toggles: select, deselect, select again, switch', (tester) async {
    await pumpRegister(tester, chooseOwner: false);
    await tapText(tester, en.register_roleAdminSubtitle);
    expect(choice(tester), [true, false]);
    await tapText(tester, en.register_roleAdminSubtitle);
    expect(choice(tester), [false, false]);
    await tapText(tester, en.register_roleAdminSubtitle);
    expect(choice(tester), [true, false]);
    await tapText(tester, en.register_roleAssistantSubtitle);
    expect(choice(tester), [false, true]);
    await tapText(tester, en.register_roleAssistantSubtitle);
    expect(choice(tester), [false, false]);
    await finishRegister(tester);
  }, skip: _skip);

  for (final width in [1200.0, 390.0]) {
    testWidgets('$width: Continue with nothing chosen stays, shows the error, and nothing changes height', (tester) async {
      await pumpRegister(tester, chooseOwner: false, size: Size(width, 900));
      // Measured where tapping Continue leaves the page scrolled.
      await tester.ensureVisible(find.text(en.products_continue).last);
      await tester.pumpAndSettle();
      final cards = [tester.getRect(owner(en)), tester.getRect(assistant(en))];
      final card = tester.getSize(find.byKey(AuthCard.surfaceKey)).height;
      final continueTop = tester.getRect(find.text(en.products_continue).last).top;
      await tapContinue(tester);
      expect(find.text(step(1)), findsOneWidget);
      expect(find.text(step(2)), findsNothing);
      expect(find.text(error(en)), findsOneWidget);
      expect([tester.getRect(owner(en)), tester.getRect(assistant(en))], cards);
      expect(tester.getSize(find.byKey(AuthCard.surfaceKey)).height, card);
      expect(tester.getRect(find.text(en.products_continue).last).top, continueTop);
      // Choosing one clears the error, in the same line.
      await tapText(tester, en.register_roleAssistantSubtitle);
      expect(find.text(error(en)), findsNothing);
      expect(tester.getSize(find.byKey(AuthCard.surfaceKey)).height, card);
      await tapContinue(tester);
      expect(find.text(step(2)), findsOneWidget);
      await finishRegister(tester);
    }, skip: _skip);
  }

  testWidgets('the choice is kept on Back', (tester) async {
    await pumpRegister(tester, chooseOwner: false);
    await tapText(tester, en.register_roleAssistantSubtitle);
    await tapContinue(tester);
    expect(find.text(step(2)), findsOneWidget);
    await tapBack(tester);
    expect(find.text(step(1)), findsOneWidget);
    expect(choice(tester), [false, true]);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the owner flow, chosen by hand, still reaches Create', (tester) async {
    await pumpRegister(tester, chooseOwner: false);
    await tapText(tester, en.register_roleAdminSubtitle);
    await fillOwnerSteps(tester);
    expect(find.text(step(5)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('the assistant flow, chosen by hand, still reaches Create', (tester) async {
    await pumpRegister(tester, chooseOwner: false);
    await tapText(tester, en.register_roleAssistantSubtitle);
    await tapContinue(tester);
    await tapText(tester, AssistantInputs.prefix);
    await typeInto(tester, 'name', AssistantInputs.name);
    await typeInto(tester, 'phone', AssistantInputs.phone);
    await tapContinue(tester);
    await typeInto(tester, 'invite', AssistantInputs.code);
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pumpAndSettle();
    await tapContinue(tester);
    await typeInto(tester, 'email', AssistantInputs.email);
    await typeInto(tester, 'password', AssistantInputs.password);
    await typeInto(tester, 'confirm', AssistantInputs.password);
    await tapContinue(tester);
    expect(find.text(step(5)), findsOneWidget);
    await finishRegister(tester);
  }, skip: _skip);

  for (final width in [360.0, 390.0, 768.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        testWidgets('no overflow at $width, ${brightness.name}, ${locale.languageCode}: none chosen, refused, chosen', (tester) async {
          final t = lookupAppLocalizations(locale);
          await pumpRegister(tester, chooseOwner: false, size: Size(width, 800), brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: 'first show');
          await tapContinue(tester, t);
          expect(find.text(error(t)), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'refused');
          await tapText(tester, t.register_roleAdminSubtitle);
          expect(tester.takeException(), isNull, reason: 'chosen');
          await finishRegister(tester);
        }, skip: _skip);
      }
    }
  }
}
