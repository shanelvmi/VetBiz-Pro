import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../utils/subscription_guard.dart';
import '../clients/clients_screen.dart';
import '../debtors/debtors_screen.dart';
import '../payments/payments_screen.dart';
import '../platform_admin/platform_admin_home_screen.dart';
import '../products/products_screen.dart';
import '../reports/view_reports_screen.dart';
import '../sales/sales_screen.dart';
import '../services/services_screen.dart';
import '../store/stockstore_screen.dart';
import '../transactions/transactions_screen.dart';
import 'insights_screen.dart';
import 'record_sheet.dart';

/// HUB1: every tile of the phone hub's action panel (phone_shell.md D1
/// SUPERSEDED): the record actions, then the places of daily work, then the
/// business places, in the expanded panel's order. The panel is daily work
/// only: the person and Settings are in the profile menu, configuration in
/// the Settings screen, and no destination is in two of them.
enum HubTile {
  recordSale,
  recordVisit,
  recordPayment,
  addClient,
  recordTransaction,
  addProduct,
  addBatch,
  sales,
  products,
  services,
  clients,
  debtors,
  payments,
  transactions,
  stockStore,
  reports,
  insights,
  platformAdmin,
}

/// The expanded panel's named groups, top to bottom.
enum HubGroup { record, dailyWork, business }

/// The collapsed panel: two rows of four, the record actions then the places
/// people open most.
const hubCollapsedTiles = [
  HubTile.recordSale,
  HubTile.recordVisit,
  HubTile.recordPayment,
  HubTile.addClient,
  HubTile.sales,
  HubTile.products,
  HubTile.clients,
  HubTile.debtors,
];

/// Today's gates: Add Product for admins only (owner decision E4d-2, as the
/// Products screen and the old "+" sheet); Platform Admin for platform admins
/// only (the sidebar's check). Every other tile was open to both roles (the
/// gates are inside the screens).
bool hubTileAllowed(HubTile tile, {required bool isAdmin, bool isPlatformAdmin = false}) => switch (tile) {
      HubTile.addProduct => isAdmin,
      HubTile.platformAdmin => isPlatformAdmin,
      _ => true,
    };

/// The collapsed tiles the role may use: one it may not is left out and the
/// rest keep their order.
List<HubTile> hubCollapsedTilesFor({required bool isAdmin}) =>
    [for (final t in hubCollapsedTiles) if (hubTileAllowed(t, isAdmin: isAdmin)) t];

/// The expanded groups with the tiles the role may use; everything the old
/// "+" sheet (and its More group), the bottom bar and the More page offered
/// for daily work, so nothing becomes unreachable. Subscription stays in the
/// Settings screen (owner answer, 2026-11-09).
List<({HubGroup group, List<HubTile> tiles})> hubGroupsFor({required bool isAdmin, bool isPlatformAdmin = false}) {
  const all = {
    HubGroup.record: [
      HubTile.recordSale,
      HubTile.recordVisit,
      HubTile.recordPayment,
      HubTile.addClient,
      HubTile.recordTransaction,
      HubTile.addProduct,
      HubTile.addBatch,
    ],
    HubGroup.dailyWork: [
      HubTile.sales,
      HubTile.products,
      HubTile.services,
      HubTile.clients,
      HubTile.debtors,
      HubTile.payments,
      HubTile.transactions,
      HubTile.stockStore,
    ],
    HubGroup.business: [HubTile.reports, HubTile.insights, HubTile.platformAdmin],
  };
  return [
    for (final e in all.entries)
      (
        group: e.key,
        tiles: [for (final t in e.value) if (hubTileAllowed(t, isAdmin: isAdmin, isPlatformAdmin: isPlatformAdmin)) t],
      ),
  ].where((g) => g.tiles.isNotEmpty).toList();
}

/// The tile's record action, or null for a place.
RecordAction? hubTileAction(HubTile tile) => switch (tile) {
      HubTile.recordSale => RecordAction.recordSale,
      HubTile.recordVisit => RecordAction.recordVisit,
      HubTile.recordPayment => RecordAction.recordPayment,
      HubTile.addClient => RecordAction.addClient,
      HubTile.recordTransaction => RecordAction.recordTransaction,
      HubTile.addProduct => RecordAction.addProduct,
      HubTile.addBatch => RecordAction.addBatch,
      _ => null,
    };

/// The group's title (existing labels).
String hubGroupTitle(AppLocalizations l10n, HubGroup group) => switch (group) {
      HubGroup.record => l10n.shell_record,
      HubGroup.dailyWork => l10n.more_sectionDailyWork,
      HubGroup.business => l10n.expenseGroup_business,
    };

/// The tile's label: the record action's, or the name the sidebar gives the
/// screen (one word for the collapsed places: Sales, Products, Clients,
/// Debtors).
String hubTileLabel(AppLocalizations l10n, HubTile tile) {
  final action = hubTileAction(tile);
  if (action != null) return recordActionLabelOf(l10n, action);
  return switch (tile) {
    HubTile.sales => l10n.nav_sales,
    HubTile.products => l10n.nav_products,
    HubTile.services => l10n.nav_services,
    HubTile.clients => l10n.clients_title,
    HubTile.debtors => l10n.nav_debtors,
    HubTile.payments => l10n.payments_title,
    HubTile.transactions => l10n.transactions_title,
    HubTile.stockStore => l10n.store_title,
    HubTile.reports => l10n.nav_reports,
    HubTile.insights => l10n.insights_title,
    _ => l10n.nav_platformAdmin,
  };
}

/// MR1's search words besides the label (a record action: its hint).
String _keywords(AppLocalizations l10n, HubTile tile) {
  final action = hubTileAction(tile);
  if (action != null) return recordActionHintOf(l10n, action);
  return switch (tile) {
    HubTile.services => l10n.more_keywordsServices,
    HubTile.clients => l10n.more_keywordsClients,
    HubTile.debtors => l10n.more_keywordsDebtors,
    HubTile.payments => l10n.more_keywordsPayments,
    HubTile.transactions => l10n.more_keywordsTransactions,
    HubTile.stockStore => l10n.more_keywordsStockStore,
    HubTile.reports => l10n.more_keywordsReports,
    HubTile.insights => l10n.more_keywordsInsights,
    HubTile.platformAdmin => l10n.more_keywordsPlatformAdmin,
    _ => '',
  };
}

IconData hubTileIcon(HubTile tile) {
  final action = hubTileAction(tile);
  if (action != null) return recordActionIcon(action);
  return switch (tile) {
    HubTile.sales => AppIcons.sales.outlined,
    HubTile.products => AppIcons.products.outlined,
    HubTile.services => AppIcons.services.outlined,
    HubTile.clients => AppIcons.clients.outlined,
    HubTile.debtors => AppIcons.debtors.outlined,
    HubTile.payments => AppIcons.payments.outlined,
    HubTile.transactions => AppIcons.transactions.outlined,
    HubTile.stockStore => AppIcons.stockStore.outlined,
    HubTile.reports => AppIcons.reports.outlined,
    HubTile.insights => AppIcons.insights.outlined,
    _ => Icons.admin_panel_settings_outlined,
  };
}

/// Lower case, accents dropped, so "Éxport" finds Export (MR1's rule).
String _fold(String s) {
  const accented = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = accented.indexOf(ch);
    out.write(i < 0 ? ch : plain[i]);
  }
  return out.toString();
}

/// Find a feature (MR1's rule): every typed word is in the tile's label or
/// keywords in any language the app has, in any case, accents ignored. An
/// empty query finds every tile.
bool hubTileMatches(AppLocalizations shown, HubTile tile, String query) {
  final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = _fold([
    hubTileLabel(shown, tile),
    for (final locale in AppLocalizations.supportedLocales) ...[
      hubTileLabel(lookupAppLocalizations(locale), tile),
      _keywords(lookupAppLocalizations(locale), tile),
    ],
  ].join(' | '));
  return words.every(text.contains);
}

/// Opens a place's existing screen, pushed with its own back arrow, as the
/// sidebar opens it.
Future<void> openHubPlace(BuildContext context, HubTile tile) async {
  Future<void> push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  switch (tile) {
    case HubTile.sales:
      return push(const SalesScreen());
    case HubTile.products:
      return push(const ProductsScreen());
    case HubTile.services:
      return push(ServicesScreen());
    case HubTile.clients:
      return push(ClientsScreen());
    case HubTile.debtors:
      return push(DebtorsScreen());
    case HubTile.payments:
      return push(const PaymentsScreen());
    case HubTile.transactions:
      return push(TransactionScreen());
    case HubTile.stockStore:
      return push(StockStoreScreen());
    case HubTile.reports:
      return push(const ViewReportsScreen());
    case HubTile.insights:
      return showInsightsScreen(context);
    case HubTile.platformAdmin:
      return push(const PlatformAdminHomeScreen());
    default:
      assert(false, '$tile is a record action');
  }
}

/// A tile's tap: a record action through the old "+" sheet's guard and forms
/// (runRecordAction: the locked facility shows its message, Record Payment
/// first finds who owes), or a place opened. [onDone] runs after either.
Future<void> runHubTile(
  BuildContext context,
  HubTile tile, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  Future<void> Function(BuildContext context, HubTile tile) openPlace = openHubPlace,
  VoidCallback? onDone,
}) async {
  final action = hubTileAction(tile);
  if (action != null) return runRecordAction(context, action, actions: actions, guard: guard, onDone: onDone);
  await openPlace(context, tile);
  onDone?.call();
}
