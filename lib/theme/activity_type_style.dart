import 'package:flutter/material.dart';

import '../data/activity_type.dart';
import 'app_colors.dart';
import 'app_icons.dart';

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
        return AppIcons.products.filled;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return AppIcons.sales.filled;
      case 'services':
        return AppIcons.services.filled;
      case 'transactions':
        return AppIcons.transactions.filled;
      case 'clients':
        return AppIcons.clients.filled;
      case 'debtors':
        return AppIcons.debtors.filled;
      case 'settings':
        return AppIcons.settings.filled;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  /// POL7 (owner rule: never colour a category, type or kind): every type
  /// is shown in the one neutral role, and the type word carries the
  /// meaning. Before POL7 each type had its own hue (chart4, chart6, chart7,
  /// accent...). The stored type values and the filters are unchanged.
  static Color color(String actionType, AppColors c) => c.textSecondary;
}
