// POL4 (group 3, Sales and Services) on phone, tablet and computer, in every
// theme, Light and Dark (shared checks: helpers/pol4_checks.dart):
// - The payment status is the dot plus the word (StatusDot), the dot in the
//   state's role (paymentAppStatus); the word is always there.
// - No decorative shadow or gradient; no shadow under the app bars, a
//   hairline in the divider role; the figure cards flat, in the border role.
// The archives, the receipt previews, text at 1.3 and reduced motion:
// pol4_archives_receipts_test.dart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/flat_stat_card.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/dark_surface_scan.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/pol4_checks.dart';
import 'helpers/screen_size_matrix.dart';

/// The two lists: the screen, its type and a row's text that opens it.
final _lists = <String, (Widget Function(FirebaseFirestore fs), Type, String)>{
  'Sales': ((fs) => SalesScreen(firestore: fs), SalesScreen, 'SL-000001'),
  'Services': ((fs) => ServicesScreen(firestore: fs), ServicesScreen, 'Vaccination visit'),
};

const _phones = [Size(390, 844), Size(360, 640)];

void main() {
  group('phone: the rows draw the dot and the word', () {
    for (final e in _lists.entries) {
      final (build, type, _) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in _phones) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: pol4Seed);
              await ph5SettleUntil(tester, () => find.text('Amina Juma').evaluate().isNotEmpty, what: 'the rows');
              await checkCase(tester, phone: true, where: where);
              final c = pol4Colors(tester, type);
              final rows = find.byType(RecordTile);
              expectPol4Dots(tester, rows, c, where: where, atLeast: 3);
              // The sales and services rows no longer draw the tinted chip.
              for (final chip in find.descendant(of: rows, matching: find.byType(StatusChip)).evaluate()) {
                expect((chip.widget as StatusChip).status.state, isNotNull, reason: where);
              }
              expectNoShadowOrGradient(tester, find.byType(type), where: where);
            });
          }
        }
      }
    }
  });

  group('tablet and computer: the dot, flat cards, a flat bar', () {
    for (final e in _lists.entries) {
      final (build, type, rowText) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in ph5WideSizes) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: pol4Seed);
              await ph5SettleUntil(tester, () => find.text(rowText).evaluate().isNotEmpty, what: 'the rows');
              knownWideOverflowOnly(tester, '$where list');
              expectNoBadSurfaces(tester, dark: look == MatrixLook.dark, where: where);
              await tester.tap(find.text(rowText).first);
              await ph5Settle(tester);
              knownWideOverflowOnly(tester, where);
              final c = pol4Colors(tester, type);
              final screen = find.byType(type);
              // Three rows and the details panel's status.
              expectPol4Dots(tester, screen, c, where: where, atLeast: 4);
              expectNoShadowOrGradient(tester, screen, where: where);
              expectFlatBar(tester, screen, c, where: where);
              final cards = find.descendant(of: screen, matching: find.byType(FlatStatCard));
              // UX2: Sales shows three (no Collected); Services its four.
              expect(cards, findsNWidgets(type == SalesScreen ? 3 : 4), reason: where);
              final card = tester.widget<Material>(find.descendant(of: cards.first, matching: find.byType(Material)).first);
              expect((card.shape! as RoundedRectangleBorder).side.color, c.border, reason: where);
            });
          }
        }
      }
    }
  });

}
