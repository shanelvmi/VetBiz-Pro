import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_layout.dart';
import 'package:provider/provider.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/user_role_provider.dart';
import 'ui_settings_dialog.dart';

import 'manage_account_screen.dart';
import 'printer_settings_screen.dart';
import 'export_data_screen.dart';
import 'business_hours_screen.dart';
import 'trash_screen.dart';
import 'business_profile_screen.dart';
import '../facilities/facility_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../activity/activity_log_screen.dart';
import '../subscription/subscription_screen.dart';
import '../dashboard/notifications_screen.dart';
import '../../config/app_defaults.dart';
import '../../l10n/l10n.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/shell/app_shell.dart';
import '../../navigation/app_destinations.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/polish_metrics.dart';
import '../../ui/polish/section_label.dart';
import '../../widgets/shell/page_header.dart';

class SettingsScreen extends StatefulWidget {
  // Null: the app's own Firebase, passed on to the screens the wide view
  // shows in its pane. Tests pass fakes (PH8a seams; no behaviour change).
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  /// LAY7: a Business item another place asks Settings to show (a
  /// notification, Needs attention). Settings shows it (a pane from 900 of
  /// the content, else pushed inside the content) and clears the request.
  final ValueNotifier<SettingsRequest?>? request;

  const SettingsScreen({super.key, this.firestore, this.auth, this.request});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// LAY7: which Business item to show ([SettingsScreen.request]); [teamStatus]
/// is the Team list's first status chip (Needs attention: Pending).
class SettingsRequest {
  final String item;
  final String? teamStatus;
  const SettingsRequest(this.item, {this.teamStatus});

  static const team = 'team';
  static const activityLog = 'activity_log';
}

class _SettingsScreenState extends State<SettingsScreen> {
  // The gap above the version footer on phones: a size, not spacing
  // (above the 32 px spacing ladder, spec 4.3).
  static const double _footerGap = 36;

  static const double cardElevation = 2.0;

  @override
  void initState() {
    super.initState();
    widget.request?.addListener(_onRequest);
    // A request made as Settings opens: shown once the first frame is laid out.
    if (widget.request?.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
  }

  @override
  void dispose() {
    widget.request?.removeListener(_onRequest);
    super.dispose();
  }

  /// UX3: the item asked for opens as a page above the hub (or the phone
  /// list), inside the content: Back returns to Settings, then Home.
  void _onRequest() {
    final r = widget.request?.value;
    if (r == null || !mounted) return;
    widget.request!.value = null;
    _pushItem(context, r.item, teamStatus: r.teamStatus);
  }

  @override
  Widget build(BuildContext context) {
    // UX3: the phone keeps its list exactly; PC and tablet get the hub.
    if (context.screenWidth < AppBreakpoints.medium && AppLayout.isPhone(context)) {
      return _buildMobileLayout(context);
    }
    return _buildHub(context);
  }

  // Unchanged from before this rewrite - full drill-down list, every
  // item pushes a full screen. Mobile has no spare room for a
  // sidebar+pane layout, so this stays exactly as it always worked.
  Widget _buildMobileLayout(BuildContext context) {
    final uiSettings = Provider.of<UiSettingsProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    final phone = AppLayout.isPhone(context);

    final currentLanguageName = AppDefaults.languageNames[uiSettings.languageCode];

    return Scaffold(
      appBar: AppBar(
        // LAY4: a place opened from the sidebar has no back arrow (the sidebar
        // is the way out); pushed above it, or outside the shell, as before.
        automaticallyImplyLeading: !ShellScope.isTopLevel(context),
        title: Text(
          context.l10n.settings_title,
          style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f20),
        ),
        backgroundColor: context.colors.brandSurface,
        foregroundColor: context.colors.onBrandSurface,
        centerTitle: true,
        elevation: AppElevation.e0,
      ),
      backgroundColor: context.colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              if (isAdmin) ...[
                _buildSectionTitle(context.l10n.subscription_title),
                const SizedBox(height: AppSpacing.s6),
                Card(
                  elevation: cardElevation,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: AppIcons.subscription.outlined,
                        label: context.l10n.settings_subscriptionBilling,
                        isLast: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              // LAY7: on a tablet (not a phone) the Business items live here,
              // pushed inside the content; the phone keeps them in its profile page.
              if (isAdmin && !phone) ...[
                const SizedBox(height: AppSpacing.s20),
                _buildSectionTitle(context.l10n.expenseGroup_business),
                const SizedBox(height: AppSpacing.s6),
                Card(
                  elevation: cardElevation,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, item) in _businessItems(context).indexed)
                        _buildSettingsItem(
                          icon: item.icon,
                          label: item.label,
                          isLast: i == _businessItems(context).length - 1,
                          onTap: () => _pushItem(context, item.key),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s20),
              _buildSectionTitle(context.l10n.settings_accountData),
              const SizedBox(height: AppSpacing.s6),
              Card(
                elevation: cardElevation,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (isAdmin)
                      _buildSettingsItem(
                        icon: AppIcons.trash.outlined,
                        label: context.l10n.activityType_trash,
                        isLast: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TrashScreen()),
                          );
                        },
                      ),
                    if (isAdmin)
                      _buildSettingsItem(
                        icon: AppIcons.export.outlined,
                        label: context.l10n.settings_exportData,
                        isLast: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ExportDataScreen()),
                          );
                        },
                      ),
                    if (isAdmin && phone)
                      _buildSettingsItem(
                        icon: AppIcons.businessHours.outlined,
                        label: context.l10n.hours_title,
                        isLast: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BusinessHoursScreen()),
                          );
                        },
                      ),
                    _buildSettingsItem(
                      icon: Icons.manage_accounts_outlined,
                      label: context.l10n.account_title,
                      isLast: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageAccountScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionTitle(context.l10n.settings_general),
              const SizedBox(height: AppSpacing.s6),
              Card(
                elevation: cardElevation,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.notifications_none,
                      label: context.l10n.common_notifications,
                      isLast: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      icon: AppIcons.printer.outlined,
                      label: context.l10n.printer_title,
                      isLast: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.info_outline,
                      label: context.l10n.settings_appInfo,
                      isLast: true,
                      onTap: () => _showAppInfoDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionTitle(context.l10n.settings_preferences),
              const SizedBox(height: AppSpacing.s6),
              Card(
                elevation: cardElevation,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.color_lens_outlined,
                      label: context.l10n.uiSettings_title,
                      trailingText: context.l10n.settings_themeLayout,
                      isLast: false,
                      onTap: () => showUiSettingsDialog(context),
                    ),
                    _buildSettingsItem(
                      icon: AppIcons.currency.outlined,
                      label: context.l10n.settings_currency,
                      trailingText: AppDefaults.currencySymbol,
                      isLast: false,
                      onTap: () {}, // not a real choice - no picker to open
                    ),
                    _buildSettingsItem(
                      icon: Icons.language_outlined,
                      label: context.l10n.settings_languageBoth,
                      trailingText: currentLanguageName,
                      isLast: true,
                      onTap: () => showLanguagePicker(context, uiSettings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _footerGap),
              Center(
                child: Text(
                  context.l10n.settings_versionLine(AppInfo.name, context.l10n.common_versionWithBuild(AppInfo.version, AppInfo.buildStamp)),
                  style: TextStyle(
                    fontSize: AppFontSize.f12,
                    color: context.colors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
            ],
          ),
        ),
      ),
    );
  }

  // UX3 (owner, 2026-11-21): on PC and tablet Settings is one hub page: the
  // shared page header, then the groups (their titles as SectionLabels) of
  // bordered flat rows (icon, title, the trailing value some rows have, a
  // chevron), two columns from 900 of the content, else one. A row opens its
  // page inside the content above the hub (Back returns here, then Home;
  // Settings stays highlighted in the sidebar); the dialog and sheet rows
  // open them as before. The role gates are the phone list's and LAY7's.
  // (Before UX3: a 300 px section list beside a pane, or a plain list.)
  Widget _buildHub(BuildContext context) {
    final uiSettings = Provider.of<UiSettingsProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    final l10n = context.l10n;
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    final groups = <(String, List<_HubRow>)>[
      if (isAdmin) ...[
        (l10n.subscription_title, [
          _HubRow('subscription', AppIcons.subscription.outlined, l10n.settings_subscriptionBilling,
              () => open(SubscriptionScreen(firestore: widget.firestore, auth: widget.auth))),
        ]),
        (l10n.expenseGroup_business, [
          for (final item in _businessItems(context)) _HubRow(item.key, item.icon, item.label, () => _pushItem(context, item.key)),
        ]),
      ],
      (l10n.settings_accountData, [
        if (isAdmin) _HubRow('trash', AppIcons.trash.outlined, l10n.activityType_trash, () => open(TrashScreen(firestore: widget.firestore))),
        if (isAdmin)
          _HubRow('export', AppIcons.export.outlined, l10n.settings_exportData, () => open(ExportDataScreen(firestore: widget.firestore))),
        _HubRow('manage_account', Icons.manage_accounts_outlined, l10n.account_title,
            () => open(ManageAccountScreen(firestore: widget.firestore, auth: widget.auth))),
      ]),
      (l10n.settings_general, [
        // LAY7: an assistant's notification opens Team Members above the hub.
        _HubRow('notifications', Icons.notifications_none, l10n.common_notifications,
            () => open(NotificationsScreen(
                  openPlace: (page, place) async => place == AppDestination.settings
                      ? _pushItem(context, SettingsRequest.team)
                      : Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
                ))),
        _HubRow('printer', AppIcons.printer.outlined, l10n.printer_title, () => open(const PrinterSettingsScreen())),
        _HubRow('app_info', Icons.info_outline, l10n.settings_appInfo, () => _showAppInfoDialog(context)),
      ]),
      (l10n.settings_preferences, [
        _HubRow('ui_settings', Icons.color_lens_outlined, l10n.uiSettings_title, () => showUiSettingsDialog(context),
            trailing: l10n.settings_themeLayout),
        // Not a real choice: no picker to open.
        _HubRow('currency', AppIcons.currency.outlined, l10n.settings_currency, () {}, trailing: AppDefaults.currencySymbol),
        _HubRow('language', Icons.language_outlined, l10n.settings_languageBoth, () => showLanguagePicker(context, uiSettings),
            trailing: AppDefaults.languageNames[uiSettings.languageCode]),
      ]),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PageHeader(title: l10n.settings_title),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= AppBreakpoints.medium ? 2 : 1;
          return ListView(
            padding: const EdgeInsets.fromLTRB(PolishMetrics.pagePadding, 0, PolishMetrics.pagePadding, PolishMetrics.pagePadding),
            children: [
              for (final (title, rows) in groups) ...[
                SectionLabel(
                  title,
                  padding: const EdgeInsets.only(
                      top: PolishMetrics.sectionLabelPaddingTop, bottom: PolishMetrics.sectionLabelPaddingBottom),
                ),
                for (var i = 0; i < rows.length; i += columns) ...[
                  if (i > 0) const SizedBox(height: PolishMetrics.gapInGroup),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = i; j < i + columns; j++) ...[
                        if (j > i) const SizedBox(width: PolishMetrics.gapInGroup),
                        Expanded(child: j < rows.length ? _buildHubRow(rows[j]) : const SizedBox.shrink()),
                      ],
                    ],
                  ),
                ],
              ],
              const SizedBox(height: _footerGap),
              Center(
                child: Text(
                  l10n.settings_versionLine(AppInfo.name, l10n.common_versionWithBuild(AppInfo.version, AppInfo.buildStamp)),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textHint),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// UX3: a hub row: a flat surface with a hairline border, at least a tap
  /// target high. The title wraps rather than being cut short.
  Widget _buildHubRow(_HubRow row) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PolishMetrics.cardRadius),
      side: BorderSide(color: colors.border, width: PolishMetrics.hairline),
    );
    return Material(
      key: ValueKey('settingsHub-${row.key}'),
      color: colors.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: row.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PolishMetrics.cardPadding, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Icon(row.icon, color: colors.primary, size: AppIconSize.i20),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(color: colors.textPrimary, fontSize: AppFontSize.f14, fontWeight: AppFontWeight.medium),
                  ),
                ),
                if (row.trailing != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Text(row.trailing!, style: TextStyle(color: colors.textMuted, fontSize: AppFontSize.f13)),
                ],
                const SizedBox(width: AppSpacing.s4),
                Icon(Icons.chevron_right_rounded, color: colors.textHint, size: AppIconSize.i20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// LAY7: the Business items (PC and tablet only), all admin-only (a
  /// Co-admin included), as their gates were in the profile panel: Team
  /// Members, View Facilities, Activity Log; Business Hours as in Settings;
  /// Business Profile, never opened before, with the facility settings it
  /// writes (an admin's, firestore.rules isEditingFacilitySettingsOnly).
  /// The caller shows them only to an admin.
  List<({String key, IconData icon, String label})> _businessItems(BuildContext context) => [
        (key: 'business_profile', icon: Icons.business_outlined, label: context.l10n.profile_title),
        (key: 'business_hours', icon: AppIcons.businessHours.outlined, label: context.l10n.hours_title),
        (key: 'facilities', icon: AppIcons.facilities.outlined, label: context.l10n.dashboard_viewFacilities),
        (key: 'team', icon: AppIcons.team.outlined, label: context.l10n.team_title),
        (key: 'activity_log', icon: AppIcons.activityLog.outlined, label: context.l10n.export_activityLog),
      ];

  /// The screen of a Business item.
  Widget _itemScreen(String key, {String? teamStatus}) => switch (key) {
        'business_profile' => BusinessProfileScreen(firestore: widget.firestore),
        'business_hours' => BusinessHoursScreen(firestore: widget.firestore),
        'facilities' => FacilityScreen(firestore: widget.firestore, auth: widget.auth),
        'team' => ManageAssistantsScreen(firestore: widget.firestore, auth: widget.auth, initialStatus: teamStatus),
        _ => ActivityLogScreen(firestore: widget.firestore, auth: widget.auth),
      };

  /// The item pushed inside the content (above the hub); Back returns to
  /// Settings.
  void _pushItem(BuildContext context, String key, {String? teamStatus}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _itemScreen(key, teamStatus: teamStatus)));


  // --- Dynamic Bottom Sheets for Data Scalability ---

  // --- Layout Helper Builders ---

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLast,
    String? trailingText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s2),
          leading: Icon(icon, color: context.colors.primary.withValues(alpha: AppAlpha.a85), size: AppIconSize.i24),
          title: Text(
            label,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: AppFontSize.f15,
              fontWeight: AppFontWeight.medium,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13),
                ),
                const SizedBox(width: AppSpacing.s4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textHint,
                size: 20,
              ),
            ],
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.colors.divider,
            indent: 54,
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s4, bottom: AppSpacing.s2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: AppFontWeight.bold,
          // PH8a: 12 on a phone, the smallest text there.
          fontSize: AppLayout.isPhone(context) ? AppFontSize.f12 : AppFontSize.f11,
          color: context.colors.primary.withValues(alpha: AppAlpha.a70),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: context.colors.primary),
            const SizedBox(width: AppSpacing.s8),
            Text(context.l10n.settings_appInfo),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(context.l10n.settings_appName, AppInfo.name),
            _infoRow(context.l10n.settings_version, context.l10n.common_versionWithBuild(AppInfo.version, AppInfo.buildStamp)),
            _infoRow(context.l10n.settings_builtFor, context.l10n.settings_builtForValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_close, style: TextStyle(color: context.colors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: AppFontSize.f13))),
        ],
      ),
    );
  }
}

/// The language sheet the Settings rows open (LAY3: also the wide profile
/// panel's Language row). Lifted unchanged from the Settings screen so both
/// set the same stored code through [UiSettingsProvider.setLocale].
void showLanguagePicker(BuildContext context, UiSettingsProvider uiSettings) {
  showModalBottomSheet(
    context: context,
    // LAY4: over the whole window, also from inside the shell's content.
    useRootNavigator: true,
    backgroundColor: context.colors.raisedSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settings_selectLanguageBoth,
              style: TextStyle(
                  // PH8a: 12 on a phone, the smallest text there.
                  fontSize: AppLayout.isPhone(context) ? AppFontSize.f12 : AppFontSize.f11,
                  fontWeight: AppFontWeight.bold,
                  color: context.colors.primary,
                  letterSpacing: 1.1),
            ),
            const SizedBox(height: AppSpacing.s10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: AppDefaults.supportedLanguages.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.divider),
                itemBuilder: (context, index) {
                  final code = AppDefaults.supportedLanguages[index];
                  final bool isSelected = code == uiSettings.languageCode;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppDefaults.languageNames[code] ?? code),
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? context.colors.primary : context.colors.border,
                    ),
                    onTap: () {
                      uiSettings.setLocale(code);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// UX3: one row of the Settings hub.
class _HubRow {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  const _HubRow(this.key, this.icon, this.label, this.onTap, {this.trailing});
}
