// FIN1: tablets and wide windows keep today's register wizard exactly (the
// frame, the header bar, the card, the welcome panel). At 768x1024, 1024x768
// and 1200x800 the whole page is compared with the fingerprint recorded from
// the code before FIN1 (test/fixtures/ph5a_wide_fingerprints.json, the fin1-
// names): every step of the owner and the assistant flows, step 1's and step
// 2's errors, and step 1 in Kiswahili.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';

import 'helpers/register_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _sizes = [Size(768, 1024), Size(1024, 768), Size(1200, 800)];

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

Future<void> _expect(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  // Every step is compared from its top: the wizard scrolls to a field on
  // an error and tapText scrolls to what it taps.
  for (final s in find.byType(Scrollable).evaluate()) {
    final position = (s as StatefulElement).state as ScrollableState;
    if (position.position.pixels != 0) position.position.jumpTo(0);
  }
  await tester.pumpAndSettle();
  expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, find.byType(RegisterScreen))}');
}

void main() {
  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    Future<void> pump(WidgetTester tester, {bool chooseOwner = true, Locale locale = const Locale('en')}) =>
        pumpRegister(tester, size: size, chooseOwner: chooseOwner, locale: locale);

    final owner = <String, Future<void> Function(WidgetTester)>{
      for (final n in [1, 2, 3, 4, 5]) 'step$n': (t) => toOwnerStep(t, n),
      'step2-errors': (t) async {
        await toOwnerStep(t, 2);
        await tapContinue(t);
      },
    };
    for (final MapEntry(key: name, value: steps) in owner.entries) {
      testWidgets('fin1-register-owner-$name-$at: the wide wizard is unchanged', (tester) async {
        await pump(tester);
        await steps(tester);
        await _expect(tester, 'fin1-register-owner-$name-$at');
        await finishRegister(tester);
      });
    }

    for (final step in [2, 3, 4, 5]) {
      testWidgets('fin1-register-assistant-step$step-$at: the wide wizard is unchanged', (tester) async {
        await pump(tester);
        await toAssistantStep(tester, step);
        await _expect(tester, 'fin1-register-assistant-step$step-$at');
        await finishRegister(tester);
      });
    }

    testWidgets('fin1-register-step1-error-$at: nothing chosen, Continue', (tester) async {
      await pump(tester, chooseOwner: false);
      await tapContinue(tester);
      await _expect(tester, 'fin1-register-step1-error-$at');
      await finishRegister(tester);
    });

    testWidgets('fin1-register-step1-sw-$at: step 1 in Kiswahili', (tester) async {
      await pump(tester, locale: const Locale('sw'));
      await _expect(tester, 'fin1-register-step1-sw-$at');
      await finishRegister(tester);
    });
  }
}
