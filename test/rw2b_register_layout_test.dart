import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';

import 'helpers/register_harness.dart';

// RW2b (docs/design/register_wizard.md section 3, owner answers 2 and 10):
// the wizard's layout at phone and desktop widths. Written before the
// wizard, skipped until it exists.
const _skip = false;

const _longName = 'Mwanaisha Wanjiru Kilimanjaro-Mwakyembe Nyamwezi';
const _longFacility = 'Kituo cha Mifugo na Kilimo cha Wilaya ya Kilimanjaro Magharibi';

void main() {
  final en = registerEn;

  Future<void> continueTo(WidgetTester tester, int step, [AppLocalizations? l10n]) async {
    final t = l10n ?? en;
    if (step >= 2) await tapContinue(tester, t);
    if (step >= 3) {
      await typeInto(tester, 'name', _longName);
      await typeInto(tester, 'phone', '0712 345 678');
      await tapContinue(tester, t);
    }
  }

  testWidgets('phone: the pinned bar stays above a keyboard of 300', (tester) async {
    await pumpRegister(tester, size: const Size(360, 800), keyboard: 300);
    await continueTo(tester, 2);
    final next = tester.getRect(find.text(en.products_continue));
    expect(next.top, greaterThanOrEqualTo(0));
    expect(next.bottom, lessThanOrEqualTo(800 - 300));
    expect(tester.getRect(find.text(en.wizard_back)).bottom, lessThanOrEqualTo(800 - 300));
    // It is the Scaffold's bar, not the card's bottom row.
    expect(find.descendant(of: find.byKey(AuthCard.surfaceKey), matching: find.text(en.products_continue)), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  for (final width in [768.0, 1200.0]) {
    testWidgets('$width: Back and Continue are the card\'s bottom row', (tester) async {
      await pumpRegister(tester, size: Size(width, 900));
      await continueTo(tester, 2);
      final card = find.byKey(AuthCard.surfaceKey);
      expect(find.descendant(of: card, matching: find.text(en.products_continue)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(en.wizard_back)), findsOneWidget);
      await finishRegister(tester);
    }, skip: _skip);
  }

  testWidgets('wide: the welcome panel stays beside every step', (tester) async {
    await pumpRegister(tester);
    expect(find.text(en.register_benefitTrial), findsOneWidget);
    await continueTo(tester, 3);
    expect(find.text(en.register_benefitTrial), findsOneWidget);
    final panel = tester.getRect(find.text(en.register_benefitTrial));
    final stepTitle = tester.getRect(find.text(en.wizard_stepOf(3, 5)));
    expect(panel.right, lessThan(stepTitle.left));
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('narrow: the welcome strip on step 1 only', (tester) async {
    await pumpRegister(tester, size: const Size(390, 844));
    expect(find.text(en.register_setUpCentre), findsOneWidget);
    await continueTo(tester, 2);
    expect(find.text(en.register_setUpCentre), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('every step: the footer below the card', (tester) async {
    await pumpRegister(tester, size: const Size(1200, 900));
    for (var step = 1; step <= 5; step++) {
      final card = tester.getRect(find.byKey(AuthCard.surfaceKey));
      expect(tester.getRect(find.byType(AuthFooter)).top, greaterThanOrEqualTo(card.bottom), reason: 'step $step');
      if (step == 1) await tapContinue(tester);
      if (step == 2) {
        await typeInto(tester, 'name', 'Amina');
        await typeInto(tester, 'phone', '0712 345 678');
        await tapContinue(tester);
      }
      if (step == 3) {
        await typeInto(tester, 'facility-name', 'Mwanga');
        await tapText(tester, en.facilityTypeLabel('Agrovet'));
        await tapText(tester, en.common_add);
        await tapContinue(tester);
      }
      if (step == 4) {
        await typeInto(tester, 'email', 'a@example.com');
        await typeInto(tester, 'password', 'Secret123');
        await typeInto(tester, 'confirm', 'Secret123');
        await tapContinue(tester);
      }
    }
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('48 px targets on phones', (tester) async {
    await pumpRegister(tester, size: const Size(360, 800));
    void tall(Finder f, String what) {
      for (final e in f.evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        expect(size.height, greaterThanOrEqualTo(48), reason: what);
      }
    }

    tall(find.byType(WizardOptionCard), 'option card');
    tall(find.widgetWithText(FilledButton, en.products_continue), 'Continue');
    await continueTo(tester, 2);
    tall(find.widgetWithText(OutlinedButton, en.wizard_back), 'Back');
    for (final chip in find.byType(ChoiceChip).evaluate()) {
      // The chip's tap area, padded to 48 by Material.
      final box = tester.getSize(find.byWidget(chip.widget));
      expect(box.height, greaterThanOrEqualTo(48), reason: 'title chip');
    }
    await fillOwnerStepsFrom2(tester);
    expect(tester.getSize(find.byType(Checkbox)).height, greaterThanOrEqualTo(48));
    tall(find.widgetWithText(TextButton, en.common_change), 'Change');
    await finishRegister(tester);
  }, skip: _skip);

  for (final width in [360.0, 390.0, 768.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        testWidgets('no overflow on any step at $width, ${brightness.name}, ${locale.languageCode}', (tester) async {
          final t = locale.languageCode == 'sw' ? registerSw : en;
          await pumpRegister(tester, size: Size(width, 800), brightness: brightness, locale: locale);
          expect(tester.takeException(), isNull, reason: 'step 1');
          await fillOwnerSteps(tester, l10n: t, name: _longName, facilityName: _longFacility);
          expect(find.text(t.wizard_stepOf(5, 5)), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'steps 2 to 5');
          await finishRegister(tester);
        }, skip: _skip);
      }
    }
  }
}

/// Steps 2 to 4 from step 2 (en), ending on step 5.
Future<void> fillOwnerStepsFrom2(WidgetTester tester) async {
  final en = registerEn;
  await typeInto(tester, 'name', 'Amina');
  await typeInto(tester, 'phone', '0712 345 678');
  await tapContinue(tester);
  await typeInto(tester, 'facility-name', 'Mwanga');
  await tapText(tester, en.facilityTypeLabel('Agrovet'));
  await tapText(tester, en.common_add);
  await tapContinue(tester);
  await typeInto(tester, 'email', 'a@example.com');
  await typeInto(tester, 'password', 'Secret123');
  await typeInto(tester, 'confirm', 'Secret123');
  await tapContinue(tester);
}
