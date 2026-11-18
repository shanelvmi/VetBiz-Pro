import 'package:flutter/widgets.dart' show IconData;

import '../l10n/l10n.dart';
import '../screens/dashboard/hub_destinations.dart' show HubTile;
import '../theme/app_icons.dart';

/// LAY1: the places of the PC/tablet shell, one registry (docs/LAYOUT_AUDIT.md
/// Part 4). Plain data: no screens, no BuildContext, no Navigator. LAY2 reads
/// it to build the sidebar and adds the screen for each place; the tablet
/// rail shows the same list, icons only (there is no separate rail flag).
///
/// Not members, on purpose:
/// - Platform Admin stays outside the shell (owner, 2026-11-18).
/// - Team, Facilities, Activity log and Notifications become sections of
///   Settings in LAY7, not shell places.
///
/// Labels are the keys the sidebar uses today (dashboard_screen.dart
/// _buildDrawerContent); Home and Insights take the phone's keys. The phone
/// hub keeps its own HubTile enum; [destinationForHubTile] links the two.
enum AppDestination {
  // (label, icon, section, adminOnly, refreshHomeOnReturn, webPath)
  home(_home, AppIcons.home, DestinationSection.main, false, false, '/home'),
  insights(_insights, AppIcons.insights, DestinationSection.main, false, false, '/insights'),
  stockStore(_stockStore, AppIcons.stockStore, DestinationSection.main, false, true, '/stock-store'),
  products(_products, AppIcons.products, DestinationSection.main, false, true, '/products'),
  sales(_sales, AppIcons.sales, DestinationSection.main, false, true, '/sales'),
  services(_services, AppIcons.services, DestinationSection.main, false, true, '/services'),
  // The sidebar does not refresh Home after Clients or Reports today.
  clients(_clients, AppIcons.clients, DestinationSection.main, false, false, '/clients'),
  payments(_payments, AppIcons.payments, DestinationSection.main, false, true, '/payments'),
  debtors(_debtors, AppIcons.debtors, DestinationSection.main, false, true, '/debtors'),
  transactions(_transactions, AppIcons.transactions, DestinationSection.main, false, true, '/transactions'),
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

/// The shell's places in sidebar order: Home, Insights, today's nine in
/// today's order, then Settings (bottom). Whether Sales should lead, as on
/// the phone, is the owner's call at LAY2, not here.
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
