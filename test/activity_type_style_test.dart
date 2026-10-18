import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/theme/activity_type_style.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

void main() {
  final c = AppColors.fromTheme(AppColorTheme.pasture);

  test("old 'Sale' entries look like 'Sales'", () {
    expect(ActivityTypeStyle.icon(ActivityType.sale.key), ActivityTypeStyle.icon(ActivityType.sales.key));
    expect(ActivityTypeStyle.color('sale', c), c.accent);
  });

  test('matching is case-insensitive; unknown types get the default look', () {
    expect(ActivityTypeStyle.icon('TRANSACTIONS'), Icons.receipt_long);
    expect(ActivityTypeStyle.color('Transactions', c), c.chart7);
    expect(ActivityTypeStyle.icon('Report Draft Deleted'), Icons.info);
    expect(ActivityTypeStyle.color('Unknown', c), c.primary);
  });
}
