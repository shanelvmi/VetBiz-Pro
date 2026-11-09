// UI5 (4): Home's action grid replaces Quick access and Go to: 4 x 2 equal
// monochrome tiles (the record actions, then Debtors, Stock Store, Reports,
// Transactions), two label lines reserved, icons on one top, a single-word
// label never wrapped or cut, the shared press feedback.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home_rows.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/press_scale.dart';

import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/wide_dashboard_group.dart' show withRobotoText;

const _skip = false;

Widget _grid({bool isAdmin = true, Future<void> Function(HomeTile)? onTile}) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: HomeActionGrid(tiles: homeTilesFor(isAdmin: isAdmin), onTile: onTile ?? (_) async {}),
        ),
      ),
    );

/// The tile labels' paragraphs (an icon is a one-glyph paragraph too).
Iterable<RenderParagraph> _labels(WidgetTester tester) => find
    .descendant(of: find.byType(HomeActionGrid), matching: find.byType(RichText))
    .evaluate()
    .map((e) => e.renderObject! as RenderParagraph)
    .where((p) => p.text.toPlainText().runes.length > 1);

void main() {
  setUpAll(loadRealFont);

  test('the order: the record actions, then the places; the same for both roles (today\'s gates)', () {
    expect(homeTilesFor(isAdmin: true), [
      HomeTile.recordSale,
      HomeTile.recordVisit,
      HomeTile.recordPayment,
      HomeTile.addClient,
      HomeTile.debtors,
      HomeTile.stockStore,
      HomeTile.reports,
      HomeTile.transactions,
    ]);
    expect(homeTilesFor(isAdmin: false), homeTilesFor(isAdmin: true));
    expect([for (final t in HomeTile.values.take(4)) homeTileAction(t)], quickAccessActions);
    expect([for (final t in HomeTile.values.skip(4)) homeTilePlace(t)],
        [MoreItem.debtors, MoreItem.stockStore, MoreItem.reports, MoreItem.transactions]);
  }, skip: _skip);

  for (final width in [360.0, 390.0]) {
    for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
      testWidgets('${width.toInt()} ${look.name}: one-word labels on one line, nothing cut, icons level',
          (tester) async {
        await pumpAtSize(tester, screen: withRobotoText(_grid()), size: Size(width, 740), look: look);
        expect(tester.takeException(), isNull);
        final tiles = find.descendant(of: find.byType(HomeActionGrid), matching: find.byType(InkWell));
        expect(tiles, findsNWidgets(8));
        for (final p in _labels(tester)) {
          final text = p.text.toPlainText();
          expect(p.didExceedMaxLines, isFalse, reason: text);
          final lines = (p.size.height / (PhoneHomeMetrics.label * PhoneHomeMetrics.tileLabelLineHeight)).round();
          if (!text.contains(' ')) expect(lines, 1, reason: '"$text" wraps or breaks a word');
          // A word is never broken across lines: each line ends at a space.
          if (lines == 2) expect(text.split(' ').length, greaterThan(1), reason: text);
        }
        final iconTops = find
            .descendant(of: find.byType(HomeActionGrid), matching: find.byType(Icon))
            .evaluate()
            .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
            .toSet();
        expect(iconTops.length, 2, reason: 'one top per row');
        final sizes = tiles.evaluate().map((e) => tester.getSize(find.byWidget(e.widget))).toSet();
        expect(sizes.length, 1, reason: 'equal tiles');
        expect(sizes.single.height, greaterThanOrEqualTo(PhoneHomeMetrics.gridTileHeight));
        expect(sizes.single.width, greaterThanOrEqualTo(48));
      }, skip: _skip);
    }
  }

  for (final look in [MatrixLook.light, MatrixLook.dark]) {
    testWidgets('${look.name}: monochrome: neutral fill, a 1 px border, icons in the text colour, no circle',
        (tester) async {
      await pumpAtSize(tester, screen: _grid(), size: const Size(390, 844), look: look);
      final colors = tester.element(find.byType(HomeActionGrid)).colors;
      for (final icon in tester.widgetList<Icon>(find.descendant(of: find.byType(HomeActionGrid), matching: find.byType(Icon)))) {
        expect(icon.color, colors.textPrimary);
      }
      for (final m in tester.widgetList<Material>(find.descendant(of: find.byType(HomeActionGrid), matching: find.byType(Material)))) {
        expect(m.color, colors.surface);
        expect((m.shape! as RoundedRectangleBorder).side.width, 1);
      }
      final circles = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(HomeActionGrid), matching: find.byType(DecoratedBox)))
          .where((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(circles, isEmpty);
    }, skip: _skip);
  }

  testWidgets('a tile is a button named by its label; a tap runs its tile once', (tester) async {
    final handle = tester.ensureSemantics();
    final ran = <HomeTile>[];
    await pumpAtSize(tester, screen: _grid(onTile: (t) async => ran.add(t)), size: const Size(390, 844));
    expect(find.bySemanticsLabel('Transactions'), findsOneWidget);
    await tester.tap(find.text('Stock Store'));
    await tester.pump();
    expect(ran, [HomeTile.stockStore]);
    handle.dispose();
  }, skip: _skip);

  testWidgets('press feedback: 0.97 while pressed, back on release; none under reduced motion', (tester) async {
    await pumpAtSize(tester, screen: _grid(), size: const Size(390, 844));
    double scale() => tester
        .widget<AnimatedScale>(find.descendant(of: find.byType(PressScale).first, matching: find.byType(AnimatedScale)))
        .scale;
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale).first));
    await tester.pump();
    expect(scale(), AppMotion.pressScale);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);

    await pumpAtSize(
      tester,
      screen: Builder(
        builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: _grid()),
      ),
      size: const Size(390, 844),
    );
    final still = await tester.startGesture(tester.getCenter(find.byType(PressScale).first));
    await tester.pump();
    expect(scale(), 1);
    await still.up();
  }, skip: _skip);
}
