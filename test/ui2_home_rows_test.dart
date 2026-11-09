// UI2 (3), carried into UI5's action grid (which replaced Go to and Quick
// access): Transactions comes last (for every role) and fits on one line; no
// one-word label wraps or is cut; every tile keeps two label lines, so the
// icons of a row share one top.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home_rows.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/real_font.dart';

const _skip = false;

Future<void> _pump(WidgetTester tester, Widget child, {required double width, required String locale}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = AppTheme.build(AppColorTheme.pasture, Brightness.light);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
    builder: (context, child) => DefaultTextStyle.merge(style: const TextStyle(fontFamily: realFontFamily), child: child!),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding), child: Column(children: [child])),
    ),
  ));
  await tester.pumpAndSettle();
}

final _grid = find.byKey(const ValueKey('phone-home-grid'));

void main() {
  setUpAll(loadRealFont);

  for (final isAdmin in [true, false]) {
    test('${isAdmin ? 'an admin' : 'an assistant'}: Transactions is the last tile', () {
      expect(homeTilesFor(isAdmin: isAdmin).last, HomeTile.transactions);
    }, skip: _skip);
  }

  for (final width in [360.0, 390.0]) {
    for (final locale in ['en', 'sw']) {
      testWidgets('the grid at $width in $locale: one-word labels on one line, uncut; icons share a top per row',
          (tester) async {
        final tiles = homeTilesFor(isAdmin: true);
        await _pump(tester, HomeActionGrid(tiles: tiles, onTile: (_) async {}), width: width, locale: locale);
        for (final tile in tiles) {
          final label = find.descendant(of: _grid, matching: find.text(homeTileLabel(tester.element(_grid), tile)));
          final text = tester.widget<Text>(label);
          final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: label, matching: find.byType(RichText)));
          expect(paragraph.didExceedMaxLines, isFalse, reason: '"${text.data}" is cut');
          if (!text.data!.contains(' ')) {
            final lines = {
              for (final b in paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.data!.length)))
                b.top,
            };
            expect(lines, hasLength(1), reason: '"${text.data}" wraps');
          }
        }
        final tops = {
          for (final e in find.descendant(of: _grid, matching: find.byType(Icon)).evaluate())
            tester.getRect(find.byWidget(e.widget)).top,
        };
        expect(tops, hasLength(2), reason: 'two rows, one icon top each: $tops');
      }, skip: _skip);
    }
  }
}
