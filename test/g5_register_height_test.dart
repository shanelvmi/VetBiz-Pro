import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_nav_bar.dart';

import 'helpers/register_harness.dart';

// G5: pressing Continue (or Create account) on an empty wizard step shows
// its errors WITHOUT changing the card's height: every message line under a
// field is kept, so an error replaces it. Measured on each step, wide and
// 390 px, English and Kiswahili; the Back and Continue bar stays put too.
// Written before the change, skipped until it exists.
const _skip = true;

void main() {
  // Steps 2 to 5 of the owner, step 3 of the assistant: walks there with
  // valid answers, leaving the step itself empty.
  Future<void> openStep(WidgetTester tester, AppLocalizations l10n, int step, {bool assistant = false}) async {
    if (assistant) await tapText(tester, l10n.register_roleAssistantSubtitle);
    await tapContinue(tester, l10n);
    if (step == 2) return;
    await typeInto(tester, 'name', 'Amina Juma');
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester, l10n);
    if (step == 3) return;
    await typeInto(tester, 'facility-name', 'Mwanga');
    await chooseFacilityType(tester, l10n.facilityTypeLabel('Agrovet'));
    await tapText(tester, l10n.common_add);
    await tapContinue(tester, l10n);
    if (step == 4) return;
    await typeInto(tester, 'email', 'amina@example.com');
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    await tapContinue(tester, l10n);
  }

  // The card's height, and the bar's top measured from the card's top (the
  // page may scroll to the first error; on phones the bar is pinned, so its
  // own top).
  (double, double) measure(WidgetTester tester, {required bool phone}) {
    final card = tester.getRect(find.byKey(AuthCard.surfaceKey));
    final bar = tester.getRect(find.byType(WizardNavBar));
    return (card.height, phone ? bar.top : bar.top - card.top);
  }

  final cases = <(String, int, bool)>[
    ('step 2', 2, false),
    ('step 3 (owner)', 3, false),
    ('step 3 (assistant)', 3, true),
    ('step 4', 4, false),
    ('step 5', 5, false),
  ];

  for (final (name, step, assistant) in cases) {
    for (final width in [1200.0, 390.0]) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        testWidgets('$name, $width, ${locale.languageCode}: the errors do not change the card', (tester) async {
          final l10n = lookupAppLocalizations(locale);
          final phone = width < 600;
          await pumpRegister(tester, size: Size(width, 900), locale: locale);
          await openStep(tester, l10n, step, assistant: assistant);
          expect(find.text(l10n.wizard_stepOf(step, 5)), findsOneWidget);

          final press = step == 5 ? l10n.register_createAccount : l10n.products_continue;
          await tester.ensureVisible(find.text(press).last);
          await tester.pumpAndSettle();
          final (heightBefore, barBefore) = measure(tester, phone: phone);
          await tapText(tester, press);
          // Still on the step, with its errors.
          expect(find.text(l10n.wizard_stepOf(step, 5)), findsOneWidget);
          final (heightAfter, barAfter) = measure(tester, phone: phone);

          expect(heightAfter, heightBefore, reason: 'the card height');
          expect(barAfter, barBefore, reason: 'the Back and Continue bar');
          expect(tester.takeException(), isNull);
          await finishRegister(tester);
        }, skip: _skip);
      }
    }
  }
}
