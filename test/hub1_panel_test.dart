// HUB1 (1): the action panel: the two collapsed rows per role, the expanded
// groups and search, snapping by drag and by tapping the handle, Escape and
// Back folding it before Home is left, its accessibility, reduced motion,
// and a tile folding it as it opens.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

Future<void> _pump(WidgetTester tester, Widget hub, {Size size = const Size(390, 844), MatrixLook look = MatrixLook.light}) =>
    pumpAtSize(tester, screen: hub, size: size, look: look);

bool _open(WidgetTester tester) => tester.any(find.byKey(hubSearch));

Future<void> _tapHandle(WidgetTester tester) async {
  await tester.tap(find.byKey(hubHandle));
  await tester.pumpAndSettle();
}

void main() {
  group('collapsed', () {
    testWidgets('admin: two rows of four in order, left to right, nothing else', (tester) async {
      await _pump(tester, hubHarness());
      expect(hubDrawnTiles(tester), hubCollapsedTilesFor(isAdmin: true));
      final tops = {for (final t in hubCollapsedTiles) tester.getTopLeft(hubTile(t)).dy};
      expect(tops, hasLength(2));
      expect(_open(tester), isFalse);
      expect(find.byKey(const ValueKey('hub-group-record')), findsNothing);
    }, skip: _skip);

    testWidgets('assistant (and a Co-admin as an admin): the same eight', (tester) async {
      await _pump(tester, hubHarness(isAdmin: false));
      expect(hubDrawnTiles(tester), hubCollapsedTilesFor(isAdmin: false));
    }, skip: _skip);

    testWidgets('tiles are 84 high and at least 48 wide; the last row is fully on screen', (tester) async {
      await _pump(tester, hubHarness(), size: const Size(360, 640));
      for (final t in hubCollapsedTiles) {
        final size = tester.getSize(hubTile(t));
        expect(size.height, PhoneHomeMetrics.gridTileHeight);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(tester.getBottomLeft(hubTile(t)).dy, lessThanOrEqualTo(640));
      }
    }, skip: _skip);

    testWidgets('no text near the handle: only the tiles\' labels are drawn', (tester) async {
      await _pump(tester, hubHarness());
      final panelTexts = find.descendant(of: find.byKey(hubPanel), matching: find.byType(Text));
      expect(panelTexts.evaluate(), hasLength(8));
    }, skip: _skip);
  });

  group('snapping', () {
    testWidgets('tapping the handle opens the panel under the top bar, again folds it', (tester) async {
      await _pump(tester, hubHarness());
      final folded = hubPanelTop(tester);
      await _tapHandle(tester);
      expect(_open(tester), isTrue);
      expect(hubPanelTop(tester), kToolbarHeight);
      for (final g in HubGroup.values) {
        expect(find.byKey(ValueKey('hub-group-${g.name}')), findsOneWidget);
      }
      await _tapHandle(tester);
      expect(_open(tester), isFalse);
      expect(hubPanelTop(tester), folded);
    }, skip: _skip);

    testWidgets('a drag up on the handle opens it, a drag down folds it; a short drag snaps back', (tester) async {
      await _pump(tester, hubHarness());
      final folded = hubPanelTop(tester);
      await tester.drag(find.byKey(hubHandle), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(hubPanelTop(tester), kToolbarHeight);
      await tester.drag(find.byKey(hubHandle), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(hubPanelTop(tester), folded);
      await tester.timedDrag(find.byKey(hubHandle), const Offset(0, -60), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(hubPanelTop(tester), folded);
    }, skip: _skip);

    testWidgets('a drag up on the tiles opens it too (the sheet\'s own drag)', (tester) async {
      await _pump(tester, hubHarness());
      await tester.fling(hubTile(HubTile.sales), const Offset(0, -300), 1500);
      await tester.pumpAndSettle();
      expect(hubPanelTop(tester), kToolbarHeight);
    }, skip: _skip);

    testWidgets('reduced motion: the handle snaps at once', (tester) async {
      await _pump(tester, MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: hubHarness(),
      ));
      await tester.tap(find.byKey(hubHandle));
      await tester.pump();
      await tester.pump();
      expect(hubPanelTop(tester), kToolbarHeight);
    }, skip: _skip);
  });

  group('Escape and Back', () {
    testWidgets('Escape folds the open panel; folded, it does nothing', (tester) async {
      await _pump(tester, hubHarness());
      await _tapHandle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_open(tester), isFalse);
    }, skip: _skip);

    testWidgets('Back folds the open panel and stays on Home; folded, Back leaves Home', (tester) async {
      final key = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        home: const Text('before'),
      ));
      key.currentState!.push(MaterialPageRoute<void>(builder: (_) => hubHarness()));
      await tester.pumpAndSettle();
      await _tapHandle(tester);
      await key.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(_open(tester), isFalse);
      expect(find.byKey(hubHandle), findsOneWidget);
      await key.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byKey(hubHandle), findsNothing);
      expect(find.text('before'), findsOneWidget);
    }, skip: _skip);
  });

  group('accessibility', () {
    testWidgets('the handle is a button with its state and an action to open or fold', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, hubHarness());
      final node = tester.getSemantics(find.byKey(hubHandle));
      expect(node.label, 'Show all actions');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isExpanded.toBoolOrNull(), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.expand), isTrue);
      final open = node.getSemanticsData().customSemanticsActionIds!.single;
      node.owner!.performAction(node.id, SemanticsAction.customAction, open);
      await tester.pumpAndSettle();
      expect(_open(tester), isTrue);
      final after = tester.getSemantics(find.byKey(hubHandle));
      expect(after.label, 'Show fewer actions');
      expect(after.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
      expect(after.getSemanticsData().hasAction(SemanticsAction.collapse), isTrue);
      semantics.dispose();
    }, skip: _skip);

    testWidgets('48 px targets folded and open', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, hubHarness());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _tapHandle(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    }, skip: _skip);
  });

  group('search and tiles', () {
    testWidgets('Find a feature in English and Kiswahili; no match; clear', (tester) async {
      await _pump(tester, hubHarness());
      await _tapHandle(tester);
      await tester.enterText(find.byKey(hubSearch), 'wadaiwa');
      await tester.pump();
      expect(hubDrawnTiles(tester), [HubTile.debtors]);
      await tester.enterText(find.byKey(hubSearch), 'expense');
      await tester.pump();
      expect(hubDrawnTiles(tester), [HubTile.recordTransaction, HubTile.transactions]);
      await tester.enterText(find.byKey(hubSearch), 'zzzz');
      await tester.pump();
      expect(find.byKey(hubNoMatch), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hub-search-clear')));
      await tester.pump();
      expect(hubDrawnTiles(tester).length, greaterThan(8));
    }, skip: _skip);

    testWidgets('Kiswahili shown: the groups and search in Kiswahili', (tester) async {
      await _pump(tester, hubHarness(), look: MatrixLook.kiswahili);
      await _tapHandle(tester);
      expect(find.text('Kazi za kila siku'), findsOneWidget);
      await tester.enterText(find.byKey(hubSearch), 'mauzo');
      await tester.pump();
      expect(hubDrawnTiles(tester), contains(HubTile.sales));
    }, skip: _skip);

    testWidgets('a tile runs its action with its tile and folds the open panel', (tester) async {
      final tapped = <HubTile>[];
      await _pump(tester, hubHarness(onTile: (_, t) async => tapped.add(t)));
      await tester.tap(hubTile(HubTile.recordPayment));
      await tester.pumpAndSettle();
      await _tapHandle(tester);
      await tester.tap(hubTile(HubTile.insights));
      await tester.pumpAndSettle();
      expect(tapped, [HubTile.recordPayment, HubTile.insights]);
      expect(_open(tester), isFalse);
    }, skip: _skip);

    testWidgets('platform admin: Platform Admin last in Business', (tester) async {
      await _pump(tester, hubHarness(isPlatformAdmin: true));
      await _tapHandle(tester);
      expect(hubDrawnTiles(tester).last, HubTile.platformAdmin);
    }, skip: _skip);
  });
}
