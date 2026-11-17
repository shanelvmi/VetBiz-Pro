// POL6 Step 0 (from POL5): Stock Alerts' kind row. The kinds are in order
// of severity (Depleted, Expired, Low Stock, Expiring Soon, Restock Shelf)
// and at 768 and 1024 every one is in view without scrolling (the row
// wraps), in English and Kiswahili. The filter still compares the stored
// StockAlertKind.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';

import 'helpers/ph5b_finders.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _order = ['All', 'depleted', 'expired', 'lowStock', 'expiringSoon', 'restockShelf'];

void main() {
  for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
    for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
      final where = '${look.name} ${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: every kind in view, by severity, no scrolling', (tester) async {
        await pumpPh5(tester, (fs) => const Ph7Listening(child: StockAlertsScreen()),
            size: size, look: look, pushed: true, seed: ph7SeedProducts);
        expect(tester.takeException(), isNull, reason: where);
        final row = find.byType(FilterRow);
        expect(tester.widget<FilterRow>(row).values, _order, reason: where);
        expect(find.descendant(of: row, matching: find.byType(Scrollable)), findsNothing, reason: where);
        final screen = Offset.zero & size;
        for (final v in _order) {
          final rect = tester.getRect(ph5Key('pol5-alertKind-$v'));
          expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue,
              reason: '$where: $v at $rect');
        }

        // The filter still compares the stored kind.
        await tester.tap(ph5Key('pol5-alertKind-expired'));
        await ph5Settle(tester);
        expect(tester.widget<FilterRow>(row).selected, StockAlertKind.expired.name, reason: where);
      });
    }
  }
}
