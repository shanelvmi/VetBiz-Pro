import 'package:flutter/widgets.dart' show IconData;

import '../l10n/l10n.dart';
import '../screens/dashboard/hub_destinations.dart' show HubTile;
import '../theme/app_icons.dart';

/// LAY1: the places of the PC/tablet shell, one registry (docs/LAYOUT_AUDIT.md
/// Part 4). Plain data: no screens, no BuildContext, no Navigator.
/// AppSidebar (LAY2) is built from it; the tablet rail shows the same list,
/// icons only (there is no separate rail flag).
///
/// Not members, on purpose:
/// - Platform Admin stays outside the shell (owner, 2026-11-18).
/// - Team, Facilities, Activity log and Notifications become sections of
///   Settings in LAY7, not shell places.
///
/// Labels are the keys the sidebar used before LAY2 (dashboard_screen.dart
/// _buildDrawerContent at 75cda9b); Home and Insights take the phone's keys.
/// The phone hub keeps its own HubTile enum; [destinationForHubTile] links
/// the two.
enum AppDestination {
  // (label, icon, section, adminOnly, refreshHomeOnReturn, webPath)
  // Declared in sidebar order: shellDestinationsFor follows it.
  home(_home, AppIcons.home, DestinationSection.main, false, false, '/home'),
  insights(_insights, AppIcons.insights, DestinationSection.main, false, false, '/insights'),
  sales(_sales, AppIcons.sales, DestinationSection.main, false, true, '/sales'),
  services(_services, AppIcons.services, DestinationSection.main, false, true, '/services'),
  // Home is not refreshed after Clients or Reports (as before LAY2).
  clients(_clients, AppIcons.clients, DestinationSection.main, false, false, '/clients'),
  debtors(_debtors, AppIcons.debtors, DestinationSection.main, false, true, '/debtors'),
  payments(_payments, AppIcons.payments, DestinationSection.main, false, true, '/payments'),
  transactions(_transactions, AppIcons.transactions, DestinationSection.main, false, true, '/transactions'),
  products(_products, AppIcons.products, DestinationSection.main, false, true, '/products'),
  stockStore(_stockStore, AppIcons.stockStore, DestinationSection.main, false, true, '/stock-store'),
  reports(_reports, AppIcons.reports, DestinationSection.main, false, false, '/reports'),
  settings(_settings, AppIcons.settings, DestinationSection.bottom, false, false, '/settings');

  const AppDestination(this.label, this._icon, this.section, this.adminOnly, this.refreshHomeOnReturn, this.webPath);

  /// The name shown, from the existing key.
  final String Function(AppLocalizations) label;
  final AppIcon _icon;

  /// The sidebar's main list, or the bottom (Settings).
  final DestinationSection section;

  /// The sidebar calls _refreshDashboardData after the push returns.
  final bool refreshHomeOnReturn;

  /// A stable path for later URL work; unused now.
  final String webPath;

  IconData get icon => _icon.outlined;
  IconData get selectedIcon => _icon.filled;

  /// Hidden from assistants. False for every member: today's sidebar has no
  /// role gate on its items (_buildDrawerContent); only Platform Admin is
  /// gated, and it is not a member.
  final bool adminOnly;
}

enum DestinationSection { main, bottom }

String _home(AppLocalizations l) => l.shell_tabHome;
String _insights(AppLocalizations l) => l.insights_title;
String _stockStore(AppLocalizations l) => l.nav_stock;
String _products(AppLocalizations l) => l.nav_products;
String _sales(AppLocalizations l) => l.nav_sales;
String _services(AppLocalizations l) => l.nav_services;
String _clients(AppLocalizations l) => l.clients_title;
String _payments(AppLocalizations l) => l.payments_title;
String _debtors(AppLocalizations l) => l.nav_debtors;
String _transactions(AppLocalizations l) => l.transactions_title;
String _reports(AppLocalizations l) => l.nav_reports;
String _settings(AppLocalizations l) => l.settings_title;

/// The shell's places in sidebar order (owner, LAY2, 2026-11-18): Home,
/// Insights, Sales, Services, Clients, Debtors, Payments, Transactions,
/// Products, Stock, Reports, then Settings (bottom).
List<AppDestination> shellDestinationsFor({required bool isAdmin}) => [
      for (final d in AppDestination.values)
        if (isAdmin || !d.adminOnly) d,
    ];

/// The shell place a phone hub tile opens, or null for the record actions
/// and Platform Admin.
AppDestination? destinationForHubTile(HubTile tile) => switch (tile) {
      HubTile.sales => AppDestination.sales,
      HubTile.products => AppDestination.products,
      HubTile.services => AppDestination.services,
      HubTile.clients => AppDestination.clients,
      HubTile.debtors => AppDestination.debtors,
      HubTile.payments => AppDestination.payments,
      HubTile.transactions => AppDestination.transactions,
      HubTile.stockStore => AppDestination.stockStore,
      HubTile.reports => AppDestination.reports,
      HubTile.insights => AppDestination.insights,
      HubTile.recordSale ||
      HubTile.recordVisit ||
      HubTile.recordPayment ||
      HubTile.addClient ||
      HubTile.recordTransaction ||
      HubTile.addProduct ||
      HubTile.addBatch ||
      HubTile.platformAdmin =>
        null,
    };
