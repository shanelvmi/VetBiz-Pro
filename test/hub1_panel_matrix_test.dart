// HUB1 (5): the action panel's size matrix, folded and open: 360x740,
// 390x844, 412x915, 360x640 and 740x360, in Light, Dark and Kiswahili, in
// the four themes, and with the text at 1.3. No overflow, 48 px targets, no
// text under 12 px, the last folded row fully on screen, one-word labels on
// one line in English and Kiswahili.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _sizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

const _themes = [AppColorTheme.pasture, AppColorTheme.clinic, AppColorTheme.harvest, AppColorTheme.ledger];

Future<void> _check(WidgetTester tester, MatrixSize s, String where) async {
  await checkCase(tester, phone: true, where: '$where folded');
  for (final t in hubCollapsedTiles) {
    expect(tester.getBottomLeft(hubTile(t)).dy, lessThanOrEqualTo(s.size.height), reason: '$where ${t.name}');
  }
  await tester.tap(find.byKey(hubHandle));
  await tester.pumpAndSettle();
  await checkCase(tester, phone: true, where: '$where open');
}

void main() {
  setUpAll(loadRealFont);

  for (final s in _sizes) {
    for (final look in MatrixLook.values) {
      testWidgets('${matrixCase(s, look)}: folded and open', (tester) async {
        await pumpAtSize(tester, screen: hubHarness(isPlatformAdmin: true), size: s.size, look: look);
        await _check(tester, s, matrixCase(s, look));
      }, skip: _skip);
    }
    for (final theme in _themes.skip(1)) {
      testWidgets('${s.label} ${theme.id}: folded and open', (tester) async {
        await pumpAtSize(tester, screen: hubHarness(), size: s.size, colorTheme: theme);
        await _check(tester, s, '${s.label} ${theme.id}');
      }, skip: _skip);
    }
  }

  testWidgets('360x740 text 1.3: folded and open, labels wrap without overflow', (tester) async {
    await pumpAtSize(tester, screen: hubHarness(), size: const Size(360, 740), textScale: matrixLargeTextScale);
    await _check(tester, _sizes.first, '360x740 text 1.3');
  }, skip: _skip);

  for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
    for (final width in [360.0, 390.0]) {
      testWidgets('$width ${look.name}: the row 2 labels sit on one line', (tester) async {
        await pumpAtSize(tester, screen: hubHarness(), size: Size(width, 800), look: look);
        for (final t in hubCollapsedTiles.skip(4)) {
          // The label's paragraph (not the icon's): one line is 12 px at the
          // strut's 1.25, and nothing is cut.
          final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: hubTile(t), matching: find.byType(RichText)).last);
          expect(paragraph.size.height, lessThanOrEqualTo(12 * 1.25 + 0.5), reason: '${t.name} wraps');
          expect(paragraph.didExceedMaxLines, isFalse, reason: t.name);
        }
      }, skip: _skip);
    }
  }
}
