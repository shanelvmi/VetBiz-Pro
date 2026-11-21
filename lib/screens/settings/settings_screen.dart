import 'dart:math' as math;

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
import 'settings_pane_scope.dart';
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

  // Master-detail (desktop/tablet-width) only - which navigable
  // screen is currently shown in the content pane. Null means "show
  // the empty state", but in practice this is set to a sensible
  // default (see _defaultSelection) as soon as role/platform-admin
  // status is known, so the pane is never blank on first load.
  String? _selectedKey;

  /// The Team pane's first status chip, from the last request; the pane is
  /// rebuilt fresh for each request ([_requestCount]).
  String? _teamStatus;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    widget.request?.addListener(_onRequest);
    // A request made as Settings opens: shown once the first frame is laid out.
    if (widget.request?.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest(fresh: true));
  }

  @override
  void dispose() {
    widget.request?.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest({bool fresh = false}) {
    final r = widget.request?.value;
    if (r == null || !mounted) return;
    widget.request!.value = null;
    if (context.screenWidth < AppBreakpoints.medium) {
      _pushItem(context, r.item, teamStatus: r.teamStatus);
      return;
    }
    _teamStatus = r.teamStatus;
    _requestCount++;
    // Opened for this item: Back leaves Settings (no default pane behind it).
    if (fresh) {
      setState(() => _selectedKey = r.item);
    } else {
      _select(r.item, force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

    if (!isWideScreen) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
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

  // Master-detail: a persistent sidebar of the same section groups
  // and items as the mobile list, but tapping a navigable one swaps
  // the content pane in-place instead of pushing a whole new screen -
  // no navigation stack to climb back out of just to check a
  // different setting next. Dialog/bottom-sheet items (App Info,
  // Language) keep working exactly as they do on mobile - they're
  // small, modal-appropriate content, not worth dedicating a whole pane
  // to. (HUB1: Help & Support left Settings for the profile menu.)
  Widget _buildDesktopLayout(BuildContext context) {
    final uiSettings = Provider.of<UiSettingsProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Whatever's genuinely first in the sidebar for this role -
    // Subscription for an Admin (top of the list), Notifications for
    // an Assistant (who never sees the Subscription section at all).
    _selectedKey ??= isAdmin ? 'subscription' : 'notifications';

    final currentLanguageName = AppDefaults.languageNames[uiSettings.languageCode];

    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _history.isNotEmpty) setState(() => _selectedKey = _history.removeLast());
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Row(
          children: [
            SizedBox(
              width: 300,
              child: Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s24, AppSpacing.s20, AppSpacing.s16),
                      child: Text(
                        context.l10n.settings_title,
                        style: TextStyle(
                          fontWeight: AppFontWeight.bold,
                          fontSize: AppFontSize.f22,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                        children: [
                          if (isAdmin) ...[
                            _buildSectionTitle(context.l10n.subscription_title),
                            const SizedBox(height: AppSpacing.s4),
                            _buildSidebarItem(
                              icon: AppIcons.subscription.outlined,
                              label: context.l10n.settings_subscriptionBilling,
                              navigateKey: 'subscription',
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            // LAY7: the Business items, panes like the others.
                            _buildSectionTitle(context.l10n.expenseGroup_business),
                            const SizedBox(height: AppSpacing.s4),
                            for (final item in _businessItems(context))
                              _buildSidebarItem(icon: item.icon, label: item.label, navigateKey: item.key),
                            const SizedBox(height: AppSpacing.s16),
                          ],
                          _buildSectionTitle(context.l10n.settings_accountData),
                          const SizedBox(height: AppSpacing.s4),
                          if (isAdmin)
                            _buildSidebarItem(
                              icon: AppIcons.trash.outlined,
                              label: context.l10n.activityType_trash,
                              navigateKey: 'trash',
                            ),
                          if (isAdmin)
                            _buildSidebarItem(
                              icon: AppIcons.export.outlined,
                              label: context.l10n.settings_exportData,
                              navigateKey: 'export',
                            ),
                          _buildSidebarItem(
                            icon: Icons.manage_accounts_outlined,
                            label: context.l10n.account_title,
                            navigateKey: 'manage_account',
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          _buildSectionTitle(context.l10n.settings_general),
                          const SizedBox(height: AppSpacing.s4),
                          _buildSidebarItem(
                            icon: Icons.notifications_none,
                            label: context.l10n.common_notifications,
                            navigateKey: 'notifications',
                          ),
                          _buildSidebarItem(
                            icon: AppIcons.printer.outlined,
                            label: context.l10n.printer_title,
                            navigateKey: 'printer',
                          ),
                          _buildSidebarItem(
                            icon: Icons.info_outline,
                            label: context.l10n.settings_appInfo,
                            onTapDialog: () => _showAppInfoDialog(context),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          _buildSectionTitle(context.l10n.settings_preferences),
                          const SizedBox(height: AppSpacing.s4),
                          _buildSidebarItem(
                            icon: Icons.color_lens_outlined,
                            label: context.l10n.uiSettings_title,
                            trailingText: context.l10n.settings_themeLayout,
                            onTapDialog: () => showUiSettingsDialog(context),
                          ),
                          _buildSidebarItem(
                            icon: AppIcons.currency.outlined,
                            label: context.l10n.settings_currency,
                            trailingText: AppDefaults.currencySymbol,
                            onTapDialog: () {}, // not a real choice - no picker to open
                          ),
                          _buildSidebarItem(
                            icon: Icons.language_outlined,
                            label: context.l10n.settings_languageBoth,
                            trailingText: currentLanguageName,
                            onTapDialog: () => showLanguagePicker(context, uiSettings),
                          ),
                          const SizedBox(height: AppSpacing.s20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              // LAY7 (#23): a pane is not a page; its AppBar shows no back arrow.
              child: SettingsPaneScope(child: _buildContentPane(isAdmin)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPane(bool isAdmin) {
    switch (_selectedKey) {
      case 'subscription':
        return isAdmin ? SubscriptionScreen(firestore: widget.firestore, auth: widget.auth) : _buildEmptyPane();
      case 'notifications':
        // LAY7: an assistant's notification shows the Team pane here; the
        // others push inside the content, as before.
        return NotificationsScreen(
          openPlace: (page, place) async => place == AppDestination.settings
              ? _select(SettingsRequest.team)
              : Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
        );
      case 'printer':
        return const PrinterSettingsScreen();
      case 'trash':
        return isAdmin ? TrashScreen(firestore: widget.firestore) : _buildEmptyPane();
      case 'export':
        return isAdmin ? ExportDataScreen(firestore: widget.firestore) : _buildEmptyPane();
      case 'business_hours':
        return isAdmin ? BusinessHoursScreen(firestore: widget.firestore) : _buildEmptyPane();
      case 'manage_account':
        return ManageAccountScreen(firestore: widget.firestore, auth: widget.auth);
      case 'business_profile' || 'facilities' || 'team' || 'activity_log':
        return isAdmin
            ? _paneWidth(KeyedSubtree(
                key: ValueKey('$_selectedKey-$_requestCount'),
                child: _itemScreen(_selectedKey!, teamStatus: _teamStatus),
              ))
            : _buildEmptyPane();
      default:
        return _buildEmptyPane();
    }
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

  /// The screen of a Business item, as a pane or pushed (tablet list).
  Widget _itemScreen(String key, {String? teamStatus}) => switch (key) {
        'business_profile' => BusinessProfileScreen(firestore: widget.firestore),
        'business_hours' => BusinessHoursScreen(firestore: widget.firestore),
        'facilities' => FacilityScreen(firestore: widget.firestore, auth: widget.auth),
        'team' => ManageAssistantsScreen(firestore: widget.firestore, auth: widget.auth, initialStatus: teamStatus),
        _ => ActivityLogScreen(firestore: widget.firestore, auth: widget.auth),
      };

  /// Tablet list (content under 900): the item pushed inside the content;
  /// Back returns to the list.
  void _pushItem(BuildContext context, String key, {String? teamStatus}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _itemScreen(key, teamStatus: teamStatus)));

  /// LAY7: the new panes measure the pane, not the content (never below the
  /// phone breakpoint, as the shell does): Team's details panel needs 1100
  /// and a pane never has it, so a member's details open as its sheet.
  Widget _paneWidth(Widget child) => LayoutBuilder(
        builder: (context, constraints) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(size: Size(math.max(constraints.maxWidth, AppBreakpoints.compact), mq.size.height)),
            child: child,
          );
        },
      );

  /// LAY7 (6): the panes chosen before, newest last. Back shows the previous
  /// one, then leaves Settings (Home).
  final List<String> _history = [];

  void _select(String key, {bool force = false}) {
    if (key == _selectedKey && !force) return;
    if (!force) _teamStatus = null;
    setState(() {
      if (key == _selectedKey) return;
      if (_selectedKey != null) _history.add(_selectedKey!);
      _selectedKey = key;
    });
  }

  Widget _buildEmptyPane() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.settings.outlined, size: AppIconSize.i56, color: context.colors.border),
          const SizedBox(height: AppSpacing.s12),
          Text(
            context.l10n.settings_selectPane,
            style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f14),
          ),
        ],
      ),
    );
  }

  // Sidebar row - visually distinct from _buildSettingsItem below:
  // no chevron (nothing here "navigates away"), instead a selected-
  // state tint for whichever navigable item is currently shown in
  // the content pane. Dialog items (onTapDialog set) never show a
  // selected state, since they don't change the pane at all.
  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    String? trailingText,
    String? navigateKey,
    VoidCallback? onTapDialog,
  }) {
    final isSelected = navigateKey != null && _selectedKey == navigateKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Material(
        color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a10) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          onTap: navigateKey != null
              ? () => _select(navigateKey)
              : onTapDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppIconSize.i20,
                  color: isSelected ? context.colors.primary : context.colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSize.f13_5,
                      fontWeight: isSelected ? AppFontWeight.semibold : AppFontWeight.medium,
                      color: isSelected ? context.colors.primary : context.colors.textPrimary,
                    ),
                  ),
                ),
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
