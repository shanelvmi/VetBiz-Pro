import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_nav_bar.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';

import 'helpers/wizard_harness.dart';

// RW2a (docs/design/register_wizard.md section 3): the option card and the
// Back/Continue bar. Written before the widgets, skipped until they exist.
const _skip = true;

void main() {
  Color textColor(WidgetTester tester, String text) =>
      tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText))).text.style!.color!;

  Widget card({required bool selected, VoidCallback? onTap}) => WizardOptionCard(
        title: 'I own or manage a facility',
        subtitle: 'Sales, stock and your team',
        icon: Icons.storefront_outlined,
        selected: selected,
        onTap: onTap ?? () {},
      );

  group('WizardOptionCard', () {
    testWidgets('at least 56 px high; the whole card is tappable', (tester) async {
      var taps = 0;
      await pumpWizard(tester, WizardOptionCard(title: 'Short', selected: false, onTap: () => taps++));
      final rect = tester.getRect(find.byType(WizardOptionCard));
      expect(rect.height, greaterThanOrEqualTo(56));
      await tester.tapAt(rect.topLeft + const Offset(3, 3));
      await tester.tapAt(rect.bottomRight - const Offset(3, 3));
      expect(taps, 2);
    }, skip: _skip);

    testWidgets('Semantics: selected follows the choice', (tester) async {
      final handle = tester.ensureSemantics();
      for (final selected in [true, false]) {
        await pumpWizard(tester, card(selected: selected));
        expect(
          tester.getSemantics(find.byType(WizardOptionCard)),
          isSemantics(isSelected: selected, isButton: true, isInMutuallyExclusiveGroup: true),
        );
      }
      handle.dispose();
    }, skip: _skip);

    for (final theme in AppColorTheme.all) {
      for (final b in Brightness.values) {
        testWidgets('${theme.id} ${b.name}: selectedCardFill, the selectableCardInk border, text 4.5+',
            (tester) async {
          final c = AppColors.fromTheme(theme, brightness: b);
          await pumpWizard(tester, card(selected: true), theme: theme, brightness: b);
          final material = tester.widget<Material>(
              find.descendant(of: find.byType(WizardOptionCard), matching: find.byType(Material)).first);
          expect(material.color, c.selectedCardFill);
          final side = (material.shape! as RoundedRectangleBorder).side;
          expect(side.color, c.selectableCardInk);
          for (final under in [c.surface, c.background]) {
            final fill = ColorMath.composite(c.selectedCardFill, under);
            for (final text in ['I own or manage a facility', 'Sales, stock and your team']) {
              expect(ColorMath.contrast(textColor(tester, text), fill), greaterThanOrEqualTo(4.5), reason: text);
            }
            expect(ColorMath.contrast(side.color, under), greaterThanOrEqualTo(3.0), reason: 'border on the page');
          }

          await pumpWizard(tester, card(selected: false), theme: theme, brightness: b);
          final plain = tester.widget<Material>(
              find.descendant(of: find.byType(WizardOptionCard), matching: find.byType(Material)).first);
          expect(plain.color, c.surface);
          expect((plain.shape! as RoundedRectangleBorder).side.color, c.border);
          for (final text in ['I own or manage a facility', 'Sales, stock and your team']) {
            expect(ColorMath.contrast(textColor(tester, text), c.surface), greaterThanOrEqualTo(4.5), reason: text);
          }
        }, skip: _skip);
      }
    }
  });

  group('WizardNavBar', () {
    Widget bar({bool first = false, bool last = false, bool submitting = false, bool pinned = false,
            VoidCallback? onBack, VoidCallback? onContinue}) =>
        WizardNavBar(
          isFirst: first,
          isLast: last,
          submitting: submitting,
          pinned: pinned,
          finishLabel: 'Create account',
          onBack: onBack ?? () {},
          onContinue: onContinue ?? () {},
        );

    testWidgets('Back outlined at the left, Continue filled primary at the right, both 48 px', (tester) async {
      var back = 0, next = 0;
      await pumpWizard(tester, bar(onBack: () => back++, onContinue: () => next++));
      final c = AppColors.fromTheme(AppColorTheme.pasture);
      final row = tester.getRect(find.byType(WizardNavBar));
      final b = tester.getRect(find.widgetWithText(OutlinedButton, 'Back'));
      final n = tester.getRect(find.widgetWithText(FilledButton, 'Continue'));
      expect(b.height, 48);
      expect(n.height, 48);
      expect(b.left, lessThan(n.left));
      expect(n.right, lessThanOrEqualTo(row.right));
      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
      expect(style.backgroundColor!.resolve({}), c.primary);
      expect(style.foregroundColor!.resolve({}), c.onPrimary);
      await tester.tap(find.text('Back'));
      await tester.tap(find.text('Continue'));
      expect((back, next), (1, 1));
    }, skip: _skip);

    testWidgets('first step: no Back, Continue stays at the right', (tester) async {
      await pumpWizard(tester, bar(first: true));
      expect(find.text('Back'), findsNothing);
      expect(tester.getRect(find.byType(FilledButton)).right,
          closeTo(tester.getRect(find.byType(WizardNavBar)).right, 24));
    }, skip: _skip);

    testWidgets('last step: Continue becomes the finish label', (tester) async {
      await pumpWizard(tester, bar(last: true));
      expect(find.text('Continue'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    }, skip: _skip);

    testWidgets('submitting: both disabled, Continue shows a spinner', (tester) async {
      await pumpWizard(tester, bar(last: true, submitting: true));
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).height, 48);
    }, skip: _skip);

    testWidgets('pinned: above a 300 px keyboard at the bottom of the screen', (tester) async {
      const size = Size(360, 740);
      await pumpWizard(tester, bar(pinned: true), size: size, keyboard: 300, scaffoldBar: true);
      final n = tester.getRect(find.byType(FilledButton));
      expect(n.bottom, lessThanOrEqualTo(size.height - 300));
      expect(n.bottom, greaterThan(size.height - 300 - 80), reason: 'right above the keyboard');
      await pumpWizard(tester, bar(pinned: true), size: size, scaffoldBar: true);
      expect(tester.getRect(find.byType(FilledButton)).bottom, greaterThan(size.height - 80));
    }, skip: _skip);

    testWidgets('inline: the bottom row of its card, the keyboard does not move it', (tester) async {
      const cardKey = ValueKey('card');
      final inCard = Container(
        key: cardKey,
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 200), bar()]),
      );
      await pumpWizard(tester, inCard, size: const Size(360, 740));
      final cardRect = tester.getRect(find.byKey(cardKey));
      final before = tester.getRect(find.byType(WizardNavBar));
      expect(before.bottom, cardRect.bottom - 18);
      await pumpWizard(tester, inCard, size: const Size(360, 740), keyboard: 300);
      expect(tester.getRect(find.byType(WizardNavBar)), before);
    }, skip: _skip);

    testWidgets('Kiswahili at 360: Rudi and Endelea, no overflow', (tester) async {
      await pumpWizard(tester, bar(), size: const Size(360, 740), locale: const Locale('sw'));
      expect(find.text('Rudi'), findsOneWidget);
      expect(find.text('Endelea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: _skip);
  });
}
