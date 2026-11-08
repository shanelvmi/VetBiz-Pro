// UI1 (1), written before the change: on a phone the heading "Sign in to
// your account" and its subtext "Use your email and password." are centred:
// the drawn text itself, within a pixel of the fields' centre line. The brand
// row, the fields, Remember my email and Forgot password, the button and the
// links stay as built (LG1's tests); the wide login keeps its card heading
// (LG1's fingerprints at 768x1024, 1024x768 and 1200x800).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';

import 'helpers/login_harness.dart';

const _skip = false;

/// Where the text is drawn (its glyphs, not its box; a space left at a line
/// break is not drawn, so only the words count).
Rect _ink(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: text, matching: find.byType(RichText)).first);
  Rect? rect;
  for (final word in RegExp(r'\S+').allMatches(paragraph.text.toPlainText())) {
    for (final b in paragraph.getBoxesForSelection(TextSelection(baseOffset: word.start, extentOffset: word.end))) {
      rect = rect == null ? b.toRect() : rect.expandToInclude(b.toRect());
    }
  }
  return rect!.shift(paragraph.localToGlobal(Offset.zero));
}

void main() {
  for (final (size, locale) in [
    (const Size(360, 740), const Locale('en')),
    (const Size(390, 844), const Locale('en')),
    (const Size(390, 844), const Locale('sw')),
  ]) {
    final at = '${size.width.toInt()}x${size.height.toInt()} ${locale.languageCode}';
    testWidgets('$at: the heading and its subtext are centred over the fields', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), width: size.width, height: size.height, locale: locale);
      final l10n = lookupAppLocalizations(locale);
      final heading = find.byKey(LoginScreen.welcomeBackRowKey);
      final centre = tester.getCenter(find.byType(TextField).first).dx;
      for (final text in [l10n.login_signInTitle, l10n.login_signInSubtitle]) {
        final found = find.descendant(of: heading, matching: find.text(text));
        expect(found, findsOneWidget, reason: text);
        expect(_ink(tester, found).center.dx, closeTo(centre, 1), reason: text);
      }
      expect(find.descendant(of: heading, matching: find.byType(Icon)), findsNothing, reason: 'no lock circle on the phone');
      expect(tester.takeException(), isNull);
    }, skip: _skip);
  }

  testWidgets('1200: the card heading stays left with its lock circle', (tester) async {
    await pumpLogin(tester, await dbWithUpdates(1), width: 1200, height: 1000);
    final heading = find.byKey(LoginScreen.welcomeBackRowKey);
    expect(find.descendant(of: heading, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
    final title = _ink(tester, find.descendant(of: heading, matching: find.text('Sign in to your account')));
    expect(title.left, greaterThan(tester.getRect(find.descendant(of: heading, matching: find.byType(Icon))).right));
  }, skip: _skip);
}
