import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_safe_area.dart';
import '../../widgets/support_contact_dialog.dart';
import '../activity/activity_log_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../clients/clients_screen.dart';
import '../debtors/debtors_screen.dart';
import '../facilities/facility_screen.dart';
import '../payments/payments_screen.dart';
import '../platform_admin/platform_admin_home_screen.dart';
import '../reports/view_reports_screen.dart';
import '../services/services_screen.dart';
import '../settings/business_hours_screen.dart';
import '../settings/export_data_screen.dart';
import '../settings/manage_account_screen.dart';
import '../settings/printer_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/trash_screen.dart';
import '../store/stockstore_screen.dart';
import '../subscription/subscription_screen.dart';
import '../transactions/transactions_screen.dart';
import 'more_parts.dart';
import 'phone_shell.dart';
import 'insights_screen.dart';

/// Everything the More page can show (phone_shell.md D5 and section 4), in
/// the order of its sections (MR1).
enum MoreItem {
  clients,
  debtors,
  services,
  payments,
  transactions,
  stockStore,
  reports,
  insights,
  activityLog,
  team,
  facilities,
  businessHours,
  subscription,
  settings,
  printerSettings,
  export,
  trash,
  manageAccount,
  help,
  platformAdmin,
}

/// MR1: the More page's named sections, top to bottom.
enum MoreSection { dailyWork, stockAndReports, teamAndBusiness, app, platform }

/// The sections the role may use, each with its items in order; a section
/// with nothing for the role is left out. The gates are today's: Settings'
/// (Subscription, Trash, Export, Business Hours: admins; Printer settings and
/// Manage Account: everyone) and the sidebar's (Platform Admin: platform
/// admins only). Business profile is not here: Settings does not open it.
///
/// UI1: only what is in neither the bottom bar (Home, Sales, Products) nor
/// the profile menu (the avatar's drawer: Team Members, Facilities and
/// Activity log for admins, with Edit profile, Change password and Logout),
/// and not Settings or Help, the app bar's two icons. Those items stay in
/// [MoreItem] for the app bar and [openMoreItem].
List<({MoreSection section, List<MoreItem> items})> moreSectionsFor({required bool isAdmin, bool isPlatformAdmin = false}) {
  final all = [
    (
      section: MoreSection.dailyWork,
      items: [MoreItem.clients, MoreItem.debtors, MoreItem.services, MoreItem.payments, MoreItem.transactions],
    ),
    (
      section: MoreSection.stockAndReports,
      items: [MoreItem.stockStore, MoreItem.reports, MoreItem.insights],
    ),
    (
      section: MoreSection.teamAndBusiness,
      items: [if (isAdmin) ...[MoreItem.businessHours, MoreItem.subscription]],
    ),
    (
      section: MoreSection.app,
      items: [MoreItem.printerSettings, if (isAdmin) ...[MoreItem.export, MoreItem.trash], MoreItem.manageAccount],
    ),
    (section: MoreSection.platform, items: [if (isPlatformAdmin) MoreItem.platformAdmin]),
  ];
  return [for (final s in all) if (s.items.isNotEmpty) s];
}

/// The items the role may use, in the order of their sections.
List<MoreItem> moreItemsFor({required bool isAdmin, bool isPlatformAdmin = false}) =>
    [for (final s in moreSectionsFor(isAdmin: isAdmin, isPlatformAdmin: isPlatformAdmin)) ...s.items];

/// The item's label: the label the sidebar, drawer or settings already use.
String moreItemLabel(BuildContext context, MoreItem item) => _label(context.l10n, item);

String _label(AppLocalizations l10n, MoreItem item) => switch (item) {
      MoreItem.clients => l10n.clients_title,
      MoreItem.debtors => l10n.nav_debtors,
      MoreItem.services => l10n.nav_services,
      MoreItem.payments => l10n.payments_title,
      MoreItem.transactions => l10n.transactions_title,
      MoreItem.stockStore => l10n.store_title,
      MoreItem.reports => l10n.nav_reports,
      MoreItem.insights => l10n.insights_title,
      MoreItem.activityLog => l10n.export_activityLog,
      MoreItem.team => l10n.team_title,
      MoreItem.facilities => l10n.facilities_title,
      MoreItem.businessHours => l10n.hours_title,
      MoreItem.subscription => l10n.subscription_title,
      MoreItem.settings => l10n.settings_title,
      MoreItem.printerSettings => l10n.printer_title,
      MoreItem.export => l10n.settings_exportData,
      MoreItem.trash => l10n.activityType_trash,
      MoreItem.manageAccount => l10n.account_title,
      MoreItem.help => l10n.dashboard_help,
      MoreItem.platformAdmin => l10n.nav_platformAdmin,
    };

/// The words, besides the label, that find an item (comma separated).
String _keywords(AppLocalizations l10n, MoreItem item) => switch (item) {
      MoreItem.clients => l10n.more_keywordsClients,
      MoreItem.debtors => l10n.more_keywordsDebtors,
      MoreItem.services => l10n.more_keywordsServices,
      MoreItem.payments => l10n.more_keywordsPayments,
      MoreItem.transactions => l10n.more_keywordsTransactions,
      MoreItem.stockStore => l10n.more_keywordsStockStore,
      MoreItem.reports => l10n.more_keywordsReports,
      MoreItem.insights => l10n.more_keywordsInsights,
      MoreItem.activityLog => l10n.more_keywordsActivityLog,
      MoreItem.team => l10n.more_keywordsTeam,
      MoreItem.facilities => l10n.more_keywordsFacilities,
      MoreItem.businessHours => l10n.more_keywordsBusinessHours,
      MoreItem.subscription => l10n.more_keywordsSubscription,
      MoreItem.settings => l10n.more_keywordsSettings,
      MoreItem.printerSettings => l10n.more_keywordsPrinter,
      MoreItem.export => l10n.more_keywordsExport,
      MoreItem.trash => l10n.more_keywordsTrash,
      MoreItem.manageAccount => l10n.more_keywordsManageAccount,
      MoreItem.help => l10n.more_keywordsHelp,
      MoreItem.platformAdmin => l10n.more_keywordsPlatformAdmin,
    };

/// The section's title.
String moreSectionTitle(AppLocalizations l10n, MoreSection section) => switch (section) {
      MoreSection.dailyWork => l10n.more_sectionDailyWork,
      MoreSection.stockAndReports => l10n.more_sectionStockReports,
      MoreSection.teamAndBusiness => l10n.more_sectionTeamBusiness,
      MoreSection.app => l10n.more_sectionApp,
      MoreSection.platform => l10n.authFooter_platform,
    };

IconData _icon(MoreItem item) => switch (item) {
      MoreItem.clients => AppIcons.clients.filled,
      MoreItem.debtors => AppIcons.debtors.filled,
      MoreItem.services => AppIcons.services.filled,
      MoreItem.payments => AppIcons.payments.filled,
      MoreItem.transactions => AppIcons.transactions.filled,
      MoreItem.stockStore => AppIcons.stockStore.filled,
      MoreItem.reports => AppIcons.reports.filled,
      MoreItem.insights => AppIcons.insights.filled,
      MoreItem.activityLog => AppIcons.activityLog.filled,
      MoreItem.team => AppIcons.team.outlined,
      MoreItem.facilities => AppIcons.facilities.outlined,
      MoreItem.businessHours => AppIcons.businessHours.outlined,
      MoreItem.subscription => AppIcons.subscription.outlined,
      MoreItem.settings => AppIcons.settings.filled,
      MoreItem.printerSettings => AppIcons.printer.outlined,
      MoreItem.export => AppIcons.export.outlined,
      MoreItem.trash => AppIcons.trash.outlined,
      MoreItem.manageAccount => Icons.manage_accounts_outlined,
      MoreItem.help => AppIcons.help.outlined,
      MoreItem.platformAdmin => Icons.admin_panel_settings_outlined,
    };

/// Lower case, accents dropped, so "Éxport" finds Export.
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

/// Whether [query] finds [item]: every word of it is in the item's label or
/// keywords in any language the app has (so a word in English or Kiswahili
/// finds it whatever the app's language), in any case, accents ignored. An
/// empty query finds every item.
bool moreItemMatches(AppLocalizations shown, MoreItem item, String query) {
  final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = _fold([
    _label(shown, item),
    for (final locale in AppLocalizations.supportedLocales) ...[
      _label(lookupAppLocalizations(locale), item),
      _keywords(lookupAppLocalizations(locale), item),
    ],
  ].join(' | '));
  return words.every(text.contains);
}

/// PH3 (5), MR1: the More page. The app bar (Settings and Help), Find a
/// feature, then the named sections of round icons; each opens the existing
/// screen as today (pushed, full screen over the bar). UI1: no profile card;
/// the avatar's drawer is the profile menu.
class MoreScreen extends StatefulWidget {
  final bool isAdmin;
  final bool isPlatformAdmin;

  /// Opens an item; null: the app's own screens ([openMoreItem]).
  final Future<void> Function(BuildContext context, MoreItem item)? onOpen;

  /// After a pushed screen returns (the dashboard refreshes, as it does
  /// after the sidebar's screens).
  final VoidCallback? onReturned;

  const MoreScreen({
    super.key,
    required this.isAdmin,
    this.isPlatformAdmin = false,
    this.onOpen,
    this.onReturned,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _open(MoreItem item) async {
    await (widget.onOpen ?? openMoreItem)(context, item);
    widget.onReturned?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    // While a query is typed, only the items it finds, and only the sections
    // that still have one.
    final sections = [
      for (final s in moreSectionsFor(isAdmin: widget.isAdmin, isPlatformAdmin: widget.isPlatformAdmin))
        (
          section: s.section,
          items: [
            for (final item in s.items)
              if (moreItemMatches(l10n, item, _query.text)) item,
          ],
        ),
    ].where((s) => s.items.isNotEmpty).toList();

    Widget appBarButton(MoreItem item, IconData icon) => IconButton(
          key: ValueKey('more-app-${item.name}'),
          icon: Icon(icon, color: colors.textPrimary),
          tooltip: _label(l10n, item),
          onPressed: () => _open(item),
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // A tab of the phone shell: no back arrow, it would pop the shell.
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: AppElevation.e1,
        centerTitle: false,
        title: Text(l10n.shell_tabMore, style: const TextStyle(fontWeight: AppFontWeight.bold)),
        actions: [
          appBarButton(MoreItem.settings, AppIcons.settings.outlined),
          appBarButton(MoreItem.help, AppIcons.help.outlined),
          const SizedBox(width: AppSpacing.s4),
        ],
      ),
      // PH8a: the subscription banner sits under the app bar (the shell's).
      body: PhoneShell.bodyWithBanner(context, LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 2 * MoreMetrics.padding;
          // Four a row on a phone held upright; more when it is turned.
          final columns = math.max(MoreMetrics.columns, width ~/ MoreMetrics.cellWidth);
          // The whole page at once (it reads nothing): a short column, so the
          // keyboard only shortens the view and the results scroll above it.
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              MoreMetrics.padding,
              MoreMetrics.padding,
              MoreMetrics.padding,
              // UI4: the end of the page clears the shell's raised "+".
              MoreMetrics.padding + AppSafeArea.bottomOf(context) + PhoneShellInsets.overhangOf(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoreSearchField(controller: _query, onChanged: () => setState(() {})),
                for (final s in sections)
                  MoreSectionGrid(
                    key: ValueKey('more-section-${s.section.name}'),
                    title: moreSectionTitle(l10n, s.section),
                    columns: columns,
                    cells: [
                      for (final item in s.items)
                        MoreCell(
                          key: ValueKey('more-item-${item.name}'),
                          icon: _icon(item),
                          label: _label(l10n, item),
                          onTap: () => _open(item),
                        ),
                    ],
                  ),
                if (sections.isEmpty)
                  Padding(
                    key: const ValueKey('more-no-match'),
                    padding: const EdgeInsets.only(top: MoreMetrics.sectionGap),
                    child: Text(
                      l10n.more_noMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: MoreMetrics.noMatchText, color: colors.textSecondary),
                    ),
                  ),
              ],
            ),
          );
        },
      )),
    );
  }
}

/// Opens [item]'s existing screen, as the sidebar, drawer and settings do.
Future<void> openMoreItem(BuildContext context, MoreItem item) async {
  Future<void> push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  switch (item) {
    case MoreItem.clients:
      return push(ClientsScreen());
    case MoreItem.debtors:
      return push(DebtorsScreen());
    case MoreItem.services:
      return push(ServicesScreen());
    case MoreItem.payments:
      return push(const PaymentsScreen());
    case MoreItem.transactions:
      return push(TransactionScreen());
    case MoreItem.reports:
      return push(const ViewReportsScreen());
    case MoreItem.insights:
      return showInsightsScreen(context);
    case MoreItem.stockStore:
      return push(StockStoreScreen());
    case MoreItem.team:
      return push(ManageAssistantsScreen());
    case MoreItem.facilities:
      return push(FacilityScreen());
    case MoreItem.settings:
      return push(SettingsScreen());
    case MoreItem.trash:
      return push(const TrashScreen());
    case MoreItem.export:
      return push(const ExportDataScreen());
    case MoreItem.businessHours:
      return push(const BusinessHoursScreen());
    case MoreItem.subscription:
      return push(const SubscriptionScreen());
    case MoreItem.activityLog:
      return push(const ActivityLogScreen());
    case MoreItem.printerSettings:
      return push(const PrinterSettingsScreen());
    case MoreItem.manageAccount:
      return push(const ManageAccountScreen());
    case MoreItem.help:
      return showSupportContactDialog(context);
    case MoreItem.platformAdmin:
      return push(const PlatformAdminHomeScreen());
  }
}
