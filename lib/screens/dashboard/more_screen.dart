import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
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
import '../settings/settings_screen.dart';
import '../settings/trash_screen.dart';
import '../store/stockstore_screen.dart';
import '../subscription/subscription_screen.dart';
import '../transactions/transactions_screen.dart';
import 'phone_shell.dart';
import 'insights_screen.dart';

/// Everything the More page can show (phone_shell.md D5 and section 4).
enum MoreItem {
  clients,
  debtors,
  services,
  payments,
  transactions,
  reports,
  insights,
  stockStore,
  team,
  facilities,
  settings,
  trash,
  export,
  businessHours,
  subscription,
  activityLog,
  help,
  platformAdmin,
}

/// The items the role may use, in order. The gates are today's: the
/// profile drawer's (Team Members, Facilities, Activity log: admins),
/// Settings' (Subscription, Trash, Export, Business Hours: admins) and the
/// sidebar's (Platform Admin: platform admins only).
///
/// Clients and Debtors come first: on a phone they were reached only from the
/// drawer, which the shell removes, until PH4's "Go to" row has them.
List<MoreItem> moreItemsFor({required bool isAdmin, bool isPlatformAdmin = false}) => [
      MoreItem.clients,
      MoreItem.debtors,
      MoreItem.services,
      MoreItem.payments,
      MoreItem.transactions,
      MoreItem.reports,
      MoreItem.insights,
      MoreItem.stockStore,
      if (isAdmin) ...[MoreItem.team, MoreItem.facilities],
      MoreItem.settings,
      if (isAdmin) ...[
        MoreItem.trash,
        MoreItem.export,
        MoreItem.businessHours,
        MoreItem.subscription,
        MoreItem.activityLog,
      ],
      MoreItem.help,
      if (isPlatformAdmin) MoreItem.platformAdmin,
    ];

/// The item's label: the label the sidebar, drawer or settings already use.
String moreItemLabel(BuildContext context, MoreItem item) {
  final l10n = context.l10n;
  return switch (item) {
    MoreItem.clients => l10n.clients_title,
    MoreItem.debtors => l10n.nav_debtors,
    MoreItem.services => l10n.nav_services,
    MoreItem.payments => l10n.payments_title,
    MoreItem.transactions => l10n.transactions_title,
    MoreItem.reports => l10n.nav_reports,
    MoreItem.insights => l10n.insights_title,
    MoreItem.stockStore => l10n.store_title,
    MoreItem.team => l10n.team_title,
    MoreItem.facilities => l10n.facilities_title,
    MoreItem.settings => l10n.settings_title,
    MoreItem.trash => l10n.activityType_trash,
    MoreItem.export => l10n.settings_exportData,
    MoreItem.businessHours => l10n.hours_title,
    MoreItem.subscription => l10n.subscription_title,
    MoreItem.activityLog => l10n.export_activityLog,
    MoreItem.help => l10n.dashboard_help,
    MoreItem.platformAdmin => l10n.nav_platformAdmin,
  };
}

IconData _icon(MoreItem item) => switch (item) {
      MoreItem.clients => Icons.people,
      MoreItem.debtors => Icons.money_off,
      MoreItem.services => Icons.design_services,
      MoreItem.payments => Icons.payments,
      MoreItem.transactions => Icons.receipt_long,
      MoreItem.reports => Icons.summarize_outlined,
      MoreItem.insights => Icons.insights,
      MoreItem.stockStore => Icons.store,
      MoreItem.team => Icons.group_outlined,
      MoreItem.facilities => Icons.store_outlined,
      MoreItem.settings => Icons.settings,
      MoreItem.trash => Icons.delete_outline,
      MoreItem.export => Icons.import_export,
      MoreItem.businessHours => Icons.schedule_outlined,
      MoreItem.subscription => Icons.workspace_premium_outlined,
      MoreItem.activityLog => Icons.history,
      MoreItem.help => Icons.help_outline,
      MoreItem.platformAdmin => Icons.admin_panel_settings_outlined,
    };

/// PH3 (5): the More page, a grid of round icons; each opens the existing
/// screen as today (pushed, full screen over the bar).
class MoreScreen extends StatelessWidget {
  final bool isAdmin;
  final bool isPlatformAdmin;

  /// Opens an item; null: the app's own screens ([openMoreItem]).
  final Future<void> Function(BuildContext context, MoreItem item)? onOpen;

  /// After a pushed screen returns (the dashboard refreshes, as it does
  /// after the sidebar's screens).
  final VoidCallback? onReturned;

  const MoreScreen({super.key, required this.isAdmin, this.isPlatformAdmin = false, this.onOpen, this.onReturned});

  Future<void> _open(BuildContext context, MoreItem item) async {
    await (onOpen ?? openMoreItem)(context, item);
    onReturned?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = moreItemsFor(isAdmin: isAdmin, isPlatformAdmin: isPlatformAdmin);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // A tab of the phone shell: no back arrow, it would pop the shell.
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: AppElevation.e1,
        centerTitle: true,
        title: Text(context.l10n.shell_tabMore, style: const TextStyle(fontWeight: AppFontWeight.bold)),
      ),
      // PH8a: the subscription banner sits under the app bar (the shell's).
      body: PhoneShell.bodyWithBanner(context, LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 2 * PhoneShellMetrics.morePadding;
          // Four a row on a phone held upright; more when it is turned.
          final columns = math.max(PhoneShellMetrics.moreColumns, width ~/ PhoneShellMetrics.moreCellWidth);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              PhoneShellMetrics.morePadding,
              PhoneShellMetrics.morePadding,
              PhoneShellMetrics.morePadding,
              PhoneShellMetrics.morePadding + AppSafeArea.bottomOf(context),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              // Taller with larger text, so two lines of label always fit.
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(PhoneShellMetrics.moreCellHeight),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _MoreCell(
              icon: _icon(items[i]),
              label: moreItemLabel(context, items[i]),
              onTap: () => _open(context, items[i]),
            ),
          );
        },
      )),
    );
  }
}

class _MoreCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreCell({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: PhoneShellMetrics.moreCircle,
            height: PhoneShellMetrics.moreCircle,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: PhoneShellMetrics.pillAlpha),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: PhoneShellMetrics.moreIcon, color: colors.primary),
          ),
          const SizedBox(height: PhoneShellMetrics.moreLabelGap),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: PhoneShellMetrics.moreLabel, color: colors.textPrimary),
          ),
        ],
      ),
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
    case MoreItem.help:
      return showSupportContactDialog(context);
    case MoreItem.platformAdmin:
      return push(const PlatformAdminHomeScreen());
  }
}
