import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';

import 'helpers/register_harness.dart';

// RW2c (register_wizard.md section 3, owner answers 2 and 10): the
// assistant's steps at phone and desktop widths. Skipped until they exist.
const _skip = false;

const _longName = 'Mwanaisha Wanjiru Kilimanjaro-Mwakyembe Nyamwezi';
const _longFacility = InviteCheck(
    facilityName: 'Kituo cha Mifugo na Kilimo cha Wilaya ya Kilimanjaro Magharibi',
    facilityType: 'Other',
    facilityTypeDetail: 'Duka la mifugo na chakula cha kuku bora');

void main() {
  final en = registerEn;

  /// Steps 1 to [last] of the assistant flow (in [t]'s language), with a
  /// check after each step when [each] is given.
  Future<void> assistantTo(WidgetTester tester, int last,
      {AppLocalizations? l10n, void Function(int step)? each}) async {
    final t = l10n ?? en;
    each?.call(1);
    if (last < 2) return;
    await tapText(tester, t.register_roleAssistantSubtitle);
    await tapContinue(tester, t);
    each?.call(2);
    if (last < 3) return;
    await typeInto(tester, 'name', _longName);
    await typeInto(tester, 'phone', '0712 345 678');
    await tapContinue(tester, t);
    await typeInto(tester, 'invite', 'LONG22');
    await tester.pump(AppTimeouts.facilityLookupDebounce);
    await tester.pumpAndSettle();
    each?.call(3);
    if (last < 4) return;
    await tapContinue(tester, t);
    each?.call(4);
    if (last < 5) return;
    await typeInto(tester, 'email', 'mwanaisha.wanjiru@example.com');
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    await tapContinue(tester, t);
    each?.call(5);
  }

  FakeRegisterMembership long() => FakeRegisterMembership(codes: {'LONG22': _longFacility});

  for (final width in [360.0, 390.0, 768.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        testWidgets('assistant: no overflow on any step at $width, ${brightness.name}, ${locale.languageCode}', (tester) async {
          final t = locale.languageCode == 'sw' ? registerSw : en;
          await pumpRegister(tester, size: Size(width, 800), brightness: brightness, locale: locale, membership: long());
          await assistantTo(tester, 5, l10n: t, each: (step) => expect(tester.takeException(), isNull, reason: 'step $step'));
          expect(find.text(t.wizard_stepOf(5, 5)), findsOneWidget);
          await finishRegister(tester);
        }, skip: _skip);
      }
    }
  }

  testWidgets('assistant: 48 px targets on phones', (tester) async {
    await pumpRegister(tester, size: const Size(360, 800), membership: long());
    await assistantTo(tester, 3);
    expect(tester.getSize(find.widgetWithText(FilledButton, en.products_continue)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(OutlinedButton, en.wizard_back)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(registerField('invite')).height, greaterThanOrEqualTo(48));
    await tapContinue(tester);
    await typeInto(tester, 'email', 'a@example.com');
    await typeInto(tester, 'password', 'Secret123');
    await typeInto(tester, 'confirm', 'Secret123');
    await tapContinue(tester);
    expect(tester.getSize(find.byType(Checkbox)).height, greaterThanOrEqualTo(48));
    for (final change in find.widgetWithText(TextButton, en.common_change).evaluate()) {
      expect(tester.getSize(find.byWidget(change.widget)).height, greaterThanOrEqualTo(48));
    }
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('assistant: every step has the footer below the card; the welcome panel beside it', (tester) async {
    await pumpRegister(tester, size: const Size(1200, 900), membership: long());
    await assistantTo(tester, 5, each: (step) {
      final card = tester.getRect(find.byKey(AuthCard.surfaceKey));
      expect(tester.getRect(find.byType(AuthFooter)).top, greaterThanOrEqualTo(card.bottom), reason: 'step $step');
      expect(find.text(en.register_benefitTrial), findsOneWidget, reason: 'panel, step $step');
    });
    await finishRegister(tester);
  }, skip: _skip);

  testWidgets('assistant, phone: the bar is pinned above a keyboard of 300 on the invite step', (tester) async {
    await pumpRegister(tester, size: const Size(360, 800), keyboard: 300, membership: long());
    await assistantTo(tester, 3);
    final next = tester.getRect(find.text(en.products_continue));
    expect(next.bottom, lessThanOrEqualTo(800 - 300));
    expect(find.descendant(of: find.byKey(AuthCard.surfaceKey), matching: find.text(en.products_continue)), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);
}
