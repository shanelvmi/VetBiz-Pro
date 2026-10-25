import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_consent_row.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_nav_bar.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_intro.dart';

import 'helpers/wizard_harness.dart';

// RW2a: the owner's required terms checkbox (RW1 answer 1), every wizard
// widget together at the four widths of the design, and a source check that
// the new files take every colour from a role and every size from a named
// constant (so the phone-app style can restyle them in one place).
// Written before the widgets, skipped until they exist.
const _skip = true;

void main() {
  const consent = 'I agree to the Terms of Service and the Privacy Policy.';

  Widget row({bool value = false, ValueChanged<bool>? onChanged, VoidCallback? onTerms, VoidCallback? onPrivacy,
          String? error}) =>
      WizardConsentRow(
        value: value,
        onChanged: onChanged ?? (_) {},
        text: consent,
        links: [
          WizardLink(label: 'Terms of Service', onTap: onTerms ?? () {}),
          WizardLink(label: 'Privacy Policy', onTap: onPrivacy ?? () {}),
        ],
        errorText: error,
      );

  group('WizardConsentRow', () {
    testWidgets('unchecked by default, a 48 px tap target, ticking reports true', (tester) async {
      bool? got;
      await pumpWizard(tester, WizardConsentRow(
        onChanged: (v) => got = v,
        text: consent,
        links: const [],
      ));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      final box = tester.getSize(find.byType(Checkbox));
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(Checkbox));
      expect(got, isTrue);
    }, skip: _skip);

    testWidgets('the two names are links that open their own page', (tester) async {
      var terms = 0, privacy = 0;
      await pumpWizard(tester, row(onTerms: () => terms++, onPrivacy: () => privacy++));
      await tester.tapOnText(find.textRange.ofSubstring('Terms of Service'));
      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
      expect((terms, privacy), (1, 1));
    }, skip: _skip);

    testWidgets('an error line in the danger role when Create was pressed unchecked', (tester) async {
      await pumpWizard(tester, row());
      expect(find.text('Tick the box first.'), findsNothing);
      await pumpWizard(tester, row(error: 'Tick the box first.'));
      final c = AppColors.fromTheme(AppColorTheme.pasture);
      final style = tester
          .widget<RichText>(find.descendant(of: find.text('Tick the box first.'), matching: find.byType(RichText)))
          .text
          .style!;
      expect(style.color, c.danger);
    }, skip: _skip);
  });

  group('every wizard widget together', () {
    const longTitle = 'Sajili kituo chako cha mifugo na huduma za kilimo kwa urahisi kabisa leo hii';
    Widget gallery() => Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            const WizardStepHeader(current: 3, total: 5, title: longTitle),
            const WizardStepIntro(title: longTitle, subtitle: longTitle),
            WizardOptionCard(title: longTitle, subtitle: longTitle, icon: Icons.pets, selected: true, onTap: () {}),
            WizardOptionCard(title: longTitle, selected: false, onTap: () {}),
            row(error: longTitle),
            WizardNavBar(isFirst: false, isLast: true, finishLabel: longTitle, onBack: () {}, onContinue: () {}),
          ]),
        );

    for (final width in [360.0, 390.0, 768.0, 1200.0]) {
      for (final locale in const [Locale('en'), Locale('sw')]) {
        for (final b in Brightness.values) {
          testWidgets('${width.toInt()} ${locale.languageCode} ${b.name}: no overflow', (tester) async {
            await pumpWizard(tester, gallery(), size: Size(width, 900), locale: locale, brightness: b);
            expect(tester.takeException(), isNull);
          }, skip: _skip);
        }
      }
    }
  });

  test('the wizard files: colours from context.colors, sizes from named constants', () {
    final files = Directory('lib/widgets/wizard').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files.map((f) => f.uri.pathSegments.last).toSet(), {
      'wizard_step_header.dart',
      'wizard_step_intro.dart',
      'wizard_option_card.dart',
      'wizard_nav_bar.dart',
      'wizard_consent_row.dart',
    });
    // A number other than 0 or 1 outside a name (f22 and s16 are names).
    final rawNumber = RegExp(r'(?<![\w.])(?:[2-9]|\d{2,})(?:\.\d+)?(?![\w])|(?<![\w.])\d+\.\d+');
    for (final f in files) {
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('import '))
          .join('\n');
      expect(code, isNot(contains('Color(')), reason: f.path);
      expect(code, isNot(matches(RegExp(r'\bColors\.'))), reason: f.path);
      expect(rawNumber.allMatches(code).map((m) => m.group(0)).toList(), isEmpty, reason: f.path);
      expect(code, contains('context.colors'), reason: f.path);
    }
  }, skip: _skip);
}
