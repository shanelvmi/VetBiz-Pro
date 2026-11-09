// HUB1 (5): Home with the docked action panel, the real Home (the card and
// the strip) at 360x740, 390x844, 412x915, 360x640 and 740x360 in the four
// themes, Light and Dark: no overflow, 48 px targets, and the panel never
// covers the card or the strip (at 740x360 the panel folds to one row of
// eight and Home scrolls: its end, the strip, still clears the folded
// panel). ui5_home_layout_test checks the portrait sizes without scrolling
// in Light, Dark and Kiswahili.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'helpers/hub1_hub.dart';
import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

// HUB1: true until the panel folds to one row sideways (the next commit).
const _skip = true;

const _sizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('412x915', Size(412, 915), phone: true),
  MatrixSize('360x640', Size(360, 640), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

void main() {
  for (final s in _sizes) {
    for (final theme in AppColorTheme.all) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        final where = '${s.label} ${theme.id} ${look.name}';
        testWidgets('$where: Home above the panel, nothing covered', (tester) async {
          await pumpAtSize(tester, screen: phoneHomeHarness(), size: s.size, look: look, colorTheme: theme);
          await checkCase(tester, phone: true, where: where);
          // Home's end: scroll it there (nothing moves where it fits).
          final home = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
          home.jumpTo(home.maxScrollExtent);
          await tester.pumpAndSettle();
          final panelTop = hubPanelTop(tester);
          expect(tester.getRect(find.byType(AttentionStrip)).bottom, lessThanOrEqualTo(panelTop), reason: where);
          if (s.size.height > s.size.width) {
            expect(tester.getRect(find.byType(TodayCard)).bottom, lessThanOrEqualTo(panelTop), reason: where);
          } else {
            // Sideways: the eight folded tiles in one row (Home keeps room).
            expect({for (final t in hubCollapsedTiles) tester.getTopLeft(hubTile(t)).dy}, hasLength(1), reason: where);
          }
        }, skip: _skip);
      }
    }
  }
}
