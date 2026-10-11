import 'package:flutter/material.dart';

import '../data/activity_type.dart';
import 'app_colors.dart';

/// The icon and colour an activity-log entry is shown with, by its stored
/// `actionType`.
///
/// The activity log, the dashboard's recent activity, the facility detail
/// panel and the report's activity tab each had their own copy of this
/// switch, and the copies had drifted (two of them showed Transactions with
/// the default icon). Matching is case-insensitive and goes through
/// [ActivityType.canonicalKey], so old 'Sale' entries look like 'Sales'.
/// 'clients', 'settings' and 'admin' are types nothing writes any more; they
/// stay so old entries keep their look.
abstract final class ActivityTypeStyle {
  static IconData icon(String actionType) {
    switch (ActivityType.canonicalKey(actionType).toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'transactions':
        return Icons.receipt_long;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  static Color color(String actionType, AppColors c) {
    switch (ActivityType.canonicalKey(actionType).toLowerCase()) {
      case 'inventory move':
        return c.info;
      case 'products':
        return c.success;
      case 'sales':
        return c.accent;
      case 'services':
        return c.chart4;
      case 'transactions':
        return c.chart7;
      case 'clients':
        return c.chart6;
      case 'debtors':
        return c.warning;
      case 'settings':
        return c.textHint;
      case 'admin':
        return c.danger;
      default:
        return c.primary;
    }
  }
}
