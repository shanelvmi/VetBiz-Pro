// POL6 (owner answer 3): every phone list's initials leading is one neutral
// tint (no rainbow: a chart hue per name coloured a person, not a state);
// the initials stay. Checked on the shared function in every colour theme,
// Light and Dark, and on the drawn rows of the group 5 lists.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';

void main() {
  test('leadingColorFor: the same neutral role for every name, every theme, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final b in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: b);
        for (final seed in ['Amina Juma', 'Baraka Mushi', 'Walk-in Customer', '', 'Ivermectin 1%']) {
          expect(leadingColorFor(c, seed), c.textSecondary, reason: '${theme.id} $b $seed');
        }
      }
    }
  });

  final lists = <String, Widget Function(dynamic fs)>{
    'Clients': (fs) => ClientsScreen(firestore: fs),
    'Debtors': (fs) => DebtorsScreen(firestore: fs),
  };
  for (final e in lists.entries) {
    ph5TestWidgets('${e.key}: every row\'s initials circle is the neutral tint', (tester) async {
      await pumpPh5(tester, (fs) => e.value(fs), seed: (fs) async {
        await ph5SeedClients(fs, [
          Ph5Client('c1', 'Amina Juma', ph5When(0), balance: 45000, oldestDebt: ph5When(45)),
          Ph5Client('c2', 'Baraka Mushi', ph5When(1), balance: 12500, oldestDebt: ph5When(3)),
        ]);
        await ph5SeedDebts(fs, [Ph5Debt('d1', 'c1', ph5When(45), 45000), Ph5Debt('d2', 'c2', ph5When(3), 12500)]);
      });
      final c = tester.element(find.byType(RecordTile).first).colors;
      final circles = find.descendant(
          of: find.byType(RecordTile),
          matching: find.byWidgetPredicate((w) =>
              w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle));
      expect(circles, findsAtLeastNWidgets(2), reason: e.key);
      for (final el in circles.evaluate()) {
        final d = (el.widget as Container).decoration! as BoxDecoration;
        expect(d.color, c.textSecondary.withValues(alpha: PhoneListMetrics.leadingAlpha), reason: e.key);
      }
    });
  }
}
