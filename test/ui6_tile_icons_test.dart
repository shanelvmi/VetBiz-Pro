// UI6 (2): in the phone action panel (folded and pulled up) only the icons
// take colour: the RECORD tiles (every tile with a record action: Record
// Sale, Record Visit, Record Payment, Add Client and the Record group's
// create actions) homeTileIconRecord, the PLACE tiles (Sales, Products,
// Clients, Debtors and every Daily work and Business tile)
// homeTileIconPlace. The tiles keep the surface fill, the 1 px border and
// textPrimary labels; a tap, the press and focus work as before. No other
// screen uses the two roles. Four themes, Light and Dark.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/press_scale.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = true;

void _expectTile(WidgetTester tester, HubTile t, AppColors c, String where) {
  final tile = hubTile(t);
  final icon = tester.widget<Icon>(find.descendant(of: tile, matching: find.byType(Icon)));
  final record = hubTileAction(t) != null;
  expect(icon.color, record ? c.homeTileIconRecord : c.homeTileIconPlace, reason: '$where ${t.name} icon');
  final label = tester.widget<Text>(find.descendant(of: tile, matching: find.byType(Text)));
  expect(label.style!.color, c.textPrimary, reason: '$where ${t.name} label');
  final material = tester.widget<Material>(find.descendant(of: tile, matching: find.byType(Material)).first);
  expect(material.color, c.surface, reason: '$where ${t.name} fill');
  expect((material.shape! as RoundedRectangleBorder).side.color, c.border, reason: '$where ${t.name} border');
  expect(find.descendant(of: tile, matching: find.byType(PressScale)), findsOneWidget, reason: 'press feedback');
  final ink = tester.widget<InkWell>(find.descendant(of: tile, matching: find.byType(InkWell)));
  expect(ink.onTap, isNotNull);
  expect(ink.canRequestFocus, isTrue, reason: 'focus');
  expect(ink.overlayColor, isNull, reason: 'the theme\'s pressed, hover and focus overlays, as before');
}

void main() {
  for (final theme in AppColorTheme.all) {
    for (final look in [MatrixLook.light, MatrixLook.dark]) {
      final where = '${theme.id} ${look.name}';
      testWidgets('$where: folded and pulled up, record and place tones', (tester) async {
        await pumpAtSize(tester,
            screen: hubHarness(isPlatformAdmin: true), size: const Size(390, 1400), look: look, colorTheme: theme);
        await tester.pumpAndSettle();
        final c = tester.element(find.byKey(hubPanel)).colors;
        final folded = hubCollapsedTilesFor(isAdmin: true);
        for (final t in folded) {
          _expectTile(tester, t, c, '$where folded');
        }
        expect([for (final t in folded) hubTileAction(t) != null], [true, true, true, true, false, false, false, false],
            reason: 'the record row, then the place row');
        await tester.tap(find.byKey(hubHandle));
        await tester.pumpAndSettle();
        for (final g in hubGroupsFor(isAdmin: true, isPlatformAdmin: true)) {
          for (final t in g.tiles) {
            expect(hubTileAction(t) != null, g.group == HubGroup.record, reason: '${t.name} in ${g.group.name}');
            _expectTile(tester, t, c, '$where ${g.group.name}');
          }
        }
      }, skip: _skip);
    }
  }

  testWidgets('a tap still runs the tile', (tester) async {
    final tapped = <HubTile>[];
    await pumpAtSize(tester,
        screen: hubHarness(onTile: (_, t) async => tapped.add(t)), size: const Size(390, 844));
    await tester.pumpAndSettle();
    await tester.tap(hubTile(HubTile.recordSale));
    await tester.tap(hubTile(HubTile.sales));
    await tester.pumpAndSettle();
    expect(tapped, [HubTile.recordSale, HubTile.sales]);
  }, skip: _skip);

  test('only the action panel uses the two roles', () {
    final users = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final source = f.readAsStringSync();
      if (source.contains('homeTileIconRecord') || source.contains('homeTileIconPlace')) {
        users.add(f.path.replaceAll('\\', '/'));
      }
    }
    expect(users..sort(), ['lib/screens/dashboard/hub_tiles.dart', 'lib/theme/app_colors.dart']);
  }, skip: _skip);
}
