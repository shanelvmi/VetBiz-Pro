import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_intro.dart';

import 'helpers/wizard_harness.dart';

// RW2a (docs/design/register_wizard.md section 3): the wizard's header and
// step intro. Written before the widgets, skipped until they exist.
const _skip = true;

void main() {
  Color textColor(WidgetTester tester, String text) =>
      tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText))).text.style!.color!;
  double fontSize(WidgetTester tester, String text) =>
      tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText))).text.style!.fontSize!;

  group('WizardStepHeader', () {
    testWidgets('"Step n of total" at the left, the title at the right, roles in Light and Dark', (tester) async {
      for (final b in Brightness.values) {
        await pumpWizard(tester, const WizardStepHeader(current: 2, total: 5, title: 'About you'),
            size: const Size(1200, 800), brightness: b);
        final c = AppColors.fromTheme(AppColorTheme.pasture, brightness: b);
        final header = tester.getRect(find.byType(WizardStepHeader));
        final step = tester.getRect(find.text('Step 2 of 5'));
        final title = tester.getRect(find.text('About you'));
        expect(step.left, header.left);
        expect(title.right, header.right);
        expect(title.top, step.top, reason: 'one line when there is room');
        expect(textColor(tester, 'Step 2 of 5'), c.textMuted);
        expect(textColor(tester, 'About you'), c.textPrimary);
      }
    }, skip: _skip);

    testWidgets('the title wraps under the step text when narrow', (tester) async {
      const long = 'A very long step title that cannot share the line with the step count';
      await pumpWizard(tester, const WizardStepHeader(current: 3, total: 5, title: long), size: const Size(360, 800));
      final step = tester.getRect(find.text('Step 3 of 5'));
      final title = tester.getRect(find.text(long));
      expect(title.top, greaterThanOrEqualTo(step.bottom));
      expect(tester.takeException(), isNull);
    }, skip: _skip);

    testWidgets('a 4 px bar, primary on divider, at current over total, animated with AppMotion.fast',
        (tester) async {
      await pumpWizard(tester, const WizardStepHeader(current: 2, total: 5, title: 'About you'));
      await tester.pumpAndSettle();
      final c = AppColors.fromTheme(AppColorTheme.pasture);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, 2 / 5);
      expect(bar.color, c.primary);
      expect(bar.backgroundColor, c.divider);
      expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 4);
      final tween = tester.widget<TweenAnimationBuilder<double>>(find.byType(TweenAnimationBuilder<double>));
      expect(tween.duration, AppMotion.fast);

      // Moving on animates from the old value to the new one.
      await pumpWizard(tester, const WizardStepHeader(current: 3, total: 5, title: 'Your facility'));
      await tester.pump(AppMotion.fast ~/ 2);
      final mid = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;
      expect(mid, greaterThan(2 / 5));
      expect(mid, lessThan(3 / 5));
      await tester.pumpAndSettle();
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 3 / 5);
    }, skip: _skip);

    testWidgets('Kiswahili at 360: "Hatua n kati ya total", no overflow', (tester) async {
      await pumpWizard(tester, const WizardStepHeader(current: 4, total: 5, title: 'Taarifa za kuingia'),
          size: const Size(360, 800), locale: const Locale('sw'));
      expect(find.text('Hatua 4 kati ya 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: _skip);
  });

  group('WizardStepIntro', () {
    testWidgets('title f22 bold textStrong, subtitle f14 textMuted, in Light and Dark', (tester) async {
      for (final b in Brightness.values) {
        await pumpWizard(tester, const WizardStepIntro(title: 'About you', subtitle: 'Tell us who you are.'),
            brightness: b);
        final c = AppColors.fromTheme(AppColorTheme.pasture, brightness: b);
        expect(fontSize(tester, 'About you'), 22);
        expect(
            tester.widget<RichText>(find.descendant(of: find.text('About you'), matching: find.byType(RichText)))
                .text
                .style!
                .fontWeight,
            FontWeight.bold);
        expect(textColor(tester, 'About you'), c.textStrong);
        expect(fontSize(tester, 'Tell us who you are.'), 14);
        expect(textColor(tester, 'Tell us who you are.'), c.textMuted);
      }
    }, skip: _skip);

    testWidgets('no subtitle: only the title; long text wraps (no maxLines)', (tester) async {
      const long = 'A title long enough to need three lines on a phone held upright in the hand';
      await pumpWizard(tester, const WizardStepIntro(title: long), size: const Size(360, 800));
      expect(find.byType(Text), findsOneWidget);
      expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
      expect(tester.getSize(find.text(long)).height, greaterThan(2 * 22));
      expect(tester.takeException(), isNull);
    }, skip: _skip);
  });
}
