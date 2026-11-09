// HUB1 (2): the phone shell is just Home: no bottom bar, no "+", no tabs;
// the banner floats over Home only; a pushed screen covers the hub and Back
// returns to the same Home (its state kept); Home's end clears the folded
// panel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_hub.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _homeList = ValueKey<String>('hub-test-home-list');

/// A Home with state: a long list (its scroll offset) and a field (its text).
Widget _home(BuildContext context) => ListView(
      key: _homeList,
      padding: EdgeInsets.only(bottom: HomePanelInsets.bottomOf(context)),
      children: [
        const TextField(key: ValueKey('hub-test-field')),
        for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('row $i')),
      ],
    );

Widget _hub({Widget? banner, Future<void> Function(BuildContext, HubTile)? onTile}) => PhoneHub(
      appBar: AppBar(title: const Text('Home')),
      banner: banner,
      home: _home,
      panel: Builder(
        builder: (context) => HomeActionPanel(
          isAdmin: true,
          onTile: (t) => (onTile ?? (_, __) async {})(context, t),
        ),
      ),
    );

void main() {
  testWidgets('no bottom bar, no "+", no tabs: the top bar, Home and the panel', (tester) async {
    await pumpAtSize(tester, screen: _hub(), size: const Size(390, 844));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(scaffold.floatingActionButton, isNull);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('phone-bar-record')), findsNothing);
    expect(find.byKey(const ValueKey('phone-bar-shape')), findsNothing);
    expect(find.byType(IndexedStack), findsNothing, reason: 'no hidden tabs');
    expect(find.byKey(hubPanel), findsOneWidget);
  }, skip: _skip);

  testWidgets('Home\'s end clears the folded panel', (tester) async {
    await pumpAtSize(tester, screen: _hub(), size: const Size(390, 844));
    await tester.drag(find.byKey(_homeList), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('row 39')).dy, lessThanOrEqualTo(hubPanelTop(tester)));
    final context = tester.element(find.byKey(_homeList));
    expect(HomePanelInsets.bottomOf(context), HomeActionPanel.collapsedHeightOf(context));
  }, skip: _skip);

  testWidgets('a pushed screen covers the hub; Back returns to the same Home', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      screen: _hub(
        banner: const Text('banner'),
        onTile: (context, tile) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(appBar: AppBar(), body: Text('opened ${tile.name}')),
        )),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('hub-test-field')), 'kept');
    // A focused field scrolls itself back into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byKey(_homeList), const Offset(0, -200));
    await tester.pumpAndSettle();
    final homeScroll = find.descendant(of: find.byKey(_homeList), matching: find.byType(Scrollable)).first;
    final state = tester.state<ScrollableState>(homeScroll);
    final offset = state.position.pixels;
    expect(offset, greaterThan(0));
    expect(find.text('banner'), findsOneWidget);

    await tester.tap(hubTile(HubTile.sales));
    await tester.pumpAndSettle();
    expect(find.text('opened sales'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('banner'), findsNothing, reason: 'pushed screens have no banner');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(homeScroll), same(state));
    expect(state.position.pixels, offset);
    expect(find.text('kept', skipOffstage: false), findsOneWidget);
    expect(find.text('banner'), findsOneWidget);
  }, skip: _skip);
}
