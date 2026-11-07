// LG1: tablets and wide windows keep today's login exactly (the two cards,
// the header bar, the frame). At 768x1024, 1024x768 and 1200x800 the whole
// page is compared with the fingerprint recorded from the code before LG1
// (test/fixtures/ph5a_wide_fingerprints.json, the lg1- names): no Updates,
// one, several, several in Kiswahili, and the empty-fields error.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';

import 'helpers/login_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _sizes = [Size(768, 1024), Size(1024, 768), Size(1200, 800)];

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, find.byType(LoginScreen))}');

/// Past the page's one entrance; well before the first auto-advance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    final states = <(String, int, Locale)>[
      ('none', 0, const Locale('en')),
      ('one', 1, const Locale('en')),
      ('several', 3, const Locale('en')),
      ('several-sw', 3, const Locale('sw')),
    ];
    for (final (name, count, locale) in states) {
      testWidgets('lg1-login-$name-$at: the wide login is unchanged', (tester) async {
        final db = count == 0 ? FakeFirebaseFirestore() : await dbWithUpdates(count);
        await pumpLogin(tester, db, width: size.width, height: size.height, locale: locale);
        await _settle(tester);
        _expect(tester, 'lg1-login-$name-$at');
      });
    }

    testWidgets('lg1-login-error-$at: the empty-fields error and the red borders are unchanged', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), width: size.width, height: size.height);
      await _settle(tester);
      await tester.tap(find.text('Sign in').last);
      await _settle(tester);
      _expect(tester, 'lg1-login-error-$at');
    });
  }
}
