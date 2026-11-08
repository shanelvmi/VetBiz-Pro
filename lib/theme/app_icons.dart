import 'package:flutter/material.dart';

/// One concept's icon: the outlined glyph for the resting state and the
/// filled one for the selected state (the bottom bar's active item). Where
/// Material draws both alike (swap_vert, history) they are still the two
/// named variants, so a later restyle changes one line here.
@immutable
class AppIcon {
  final IconData outlined;
  final IconData filled;

  const AppIcon(this.outlined, this.filled);
}

/// NAV1: the one place that names the icon of every concept, so the sidebar,
/// the bottom bar, More, Home's Go to row, the quick tiles and sheets, the
/// settings rows and the dashboard cards all show the same picture for the
/// same place, and one file restyles them.
///
/// Rules (test/nav1_icons_test.dart): no two concepts share a glyph; no
/// dollar-sign icon (Sales is a receipt, Debtors a wallet, the currency row
/// coins); no AI-style sparkles or bolts. bar_chart is for Reports only.
abstract final class AppIcons {
  static const home = AppIcon(Icons.home_outlined, Icons.home);
  static const sales = AppIcon(Icons.receipt_long_outlined, Icons.receipt_long);
  static const debtors = AppIcon(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet);
  static const payments = AppIcon(Icons.payments_outlined, Icons.payments);
  static const transactions = AppIcon(Icons.swap_vert_outlined, Icons.swap_vert);
  static const expenses = AppIcon(Icons.trending_down_outlined, Icons.trending_down);
  static const products = AppIcon(Icons.inventory_2_outlined, Icons.inventory_2);
  static const stockStore = AppIcon(Icons.warehouse_outlined, Icons.warehouse);
  static const clients = AppIcon(Icons.groups_outlined, Icons.groups);
  static const services = AppIcon(Icons.vaccines_outlined, Icons.vaccines);
  static const reports = AppIcon(Icons.bar_chart_outlined, Icons.bar_chart);
  static const insights = AppIcon(Icons.insights_outlined, Icons.insights);
  static const more = AppIcon(Icons.grid_view_outlined, Icons.grid_view);
  static const team = AppIcon(Icons.group_outlined, Icons.group);
  static const facilities = AppIcon(Icons.store_outlined, Icons.store);
  static const subscription = AppIcon(Icons.workspace_premium_outlined, Icons.workspace_premium);
  static const settings = AppIcon(Icons.settings_outlined, Icons.settings);
  static const help = AppIcon(Icons.help_outline, Icons.help);
  static const trash = AppIcon(Icons.delete_outline, Icons.delete);
  static const export = AppIcon(Icons.download_outlined, Icons.download);
  static const printer = AppIcon(Icons.print_outlined, Icons.print);
  static const businessHours = AppIcon(Icons.schedule_outlined, Icons.schedule);
  static const activityLog = AppIcon(Icons.history_outlined, Icons.history);

  /// Settings' currency row and the product form's price section: coins and
  /// a price tag, not a dollar sign.
  static const currency = AppIcon(Icons.toll_outlined, Icons.toll);
  static const price = AppIcon(Icons.sell_outlined, Icons.sell);

  /// The Products and Stock Store sort dropdowns: not a concept, but its own
  /// glyph so it never looks like Transactions.
  static const sort = Icons.sort;

  /// Every concept by name (the uniqueness test reads this).
  static const Map<String, AppIcon> concepts = {
    'home': home,
    'sales': sales,
    'debtors': debtors,
    'payments': payments,
    'transactions': transactions,
    'expenses': expenses,
    'products': products,
    'stockStore': stockStore,
    'clients': clients,
    'services': services,
    'reports': reports,
    'insights': insights,
    'more': more,
    'team': team,
    'facilities': facilities,
    'subscription': subscription,
    'settings': settings,
    'help': help,
    'trash': trash,
    'export': export,
    'printer': printer,
    'businessHours': businessHours,
    'activityLog': activityLog,
    'currency': currency,
    'price': price,
  };
}
