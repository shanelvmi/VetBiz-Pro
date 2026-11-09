// HUB1: the phone hub as the shell lays it out: a top bar, Home padded by the
// collapsed panel's height, and the action panel over the body.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';

const hubPanel = ValueKey<String>('hub-panel');
const hubHandle = ValueKey<String>('hub-handle');
const hubSearch = ValueKey<String>('hub-search');
const hubNoMatch = ValueKey<String>('hub-no-match');
const hubHomeKey = ValueKey<String>('hub-test-home');

Finder hubTile(HubTile t) => find.byKey(ValueKey('hub-tile-${t.name}'));

/// The hub: [home] (a tall stand-in by default) under the panel.
Widget hubHarness({
  bool isAdmin = true,
  bool isPlatformAdmin = false,
  Future<void> Function(BuildContext context, HubTile tile)? onTile,
  Widget? home,
}) =>
    Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Builder(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: HomeActionPanel.collapsedHeightOf(context)),
                child: home ?? const SizedBox(key: hubHomeKey, height: double.infinity, width: double.infinity),
              ),
            ),
            Positioned.fill(
              child: HomeActionPanel(
                isAdmin: isAdmin,
                isPlatformAdmin: isPlatformAdmin,
                onTile: (t) => (onTile ?? (_, __) async {})(context, t),
              ),
            ),
          ],
        ),
      ),
    );

/// The tiles drawn, in reading order (top to bottom, then left to right).
List<HubTile> hubDrawnTiles(WidgetTester tester) {
  final drawn = [
    for (final t in HubTile.values)
      if (hubTile(t).evaluate().isNotEmpty) (tile: t, at: tester.getTopLeft(hubTile(t))),
  ]..sort((a, b) => a.at.dy != b.at.dy ? a.at.dy.compareTo(b.at.dy) : a.at.dx.compareTo(b.at.dx));
  return [for (final d in drawn) d.tile];
}

/// The panel's top edge on screen.
double hubPanelTop(WidgetTester tester) => tester.getTopLeft(find.byKey(hubHandle)).dy;
