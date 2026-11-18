// POL7 (owner rule: never colour a category, type or kind). Every activity
// type is shown in the one neutral role in every theme, Light and Dark;
// the stored type values and how they are matched stay as they were. A
// notification kind is a state role or neutral, never a chart role.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/theme/activity_type_style.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

void main() {
  test('the stored activity type values are unchanged', () {
    expect([for (final t in ActivityType.values) t.key], [
      'Account', 'Debtors', 'Products', 'Inventory Move', 'Sales', 'Sale', 'Services',
      'Transactions', 'Trash', 'Report Draft Deleted',
    ]);
    expect(ActivityType.canonicalKey('Sale'), 'Sales');
    expect(ActivityType.canonicalKey('Products'), 'Products');
  });

  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      test('${theme.name} ${b.name}: every type neutral; notification kinds state or neutral', () {
        final c = AppColors.fromTheme(theme, brightness: b);
        for (final key in [...ActivityType.values.map((t) => t.key), 'clients', 'settings', 'admin', 'Unknown']) {
          expect(ActivityTypeStyle.color(key, c), c.textSecondary, reason: key);
        }
        final allowed = {c.success, c.warning, c.danger, c.info, c.textSecondary, c.textHint};
        final chart = {c.chart1, c.chart2, c.chart3, c.chart4, c.chart5, c.chart6, c.chart7, c.chart8, c.chart9};
        for (final t in NotificationType.values) {
          expect(allowed.contains(t.colorIn(c)), isTrue, reason: t.name);
          expect(chart.contains(t.colorIn(c)), isFalse, reason: t.name);
        }
      });
    }
  }
}
