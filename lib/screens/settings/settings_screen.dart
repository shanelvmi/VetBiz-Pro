import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/user_role_provider.dart';
import 'ui_settings_dialog.dart';

import 'manage_account_screen.dart';
import 'printer_settings_screen.dart';
import 'export_data_screen.dart';
import 'business_hours_screen.dart';
import 'trash_screen.dart';
import '../subscription/subscription_screen.dart';
import '../dashboard/notifications_screen.dart';
import '../../config/app_defaults.dart';
import '../../l10n/l10n.dart';
import '../../config/app_links.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
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

    final currentLanguageName = AppDefaults.languageNames[uiSettings.languageCode];

    return Scaffold(
      appBar: AppBar(
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
                        icon: Icons.workspace_premium_outlined,
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
                        icon: Icons.delete_outline,
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
                        icon: Icons.import_export,
                        label: context.l10n.settings_exportData,
                        isLast: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ExportDataScreen()),
                          );
                        },
                      ),
                    if (isAdmin)
                      _buildSettingsItem(
                        icon: Icons.schedule_outlined,
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
                      icon: Icons.print_outlined,
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
                      icon: Icons.help_outline,
                      label: context.l10n.settings_helpSupport,
                      isLast: false,
                      onTap: () => _showHelpSupportDialog(context),
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
                      icon: Icons.currency_exchange_outlined,
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
                      onTap: () => _showLanguageSelection(context, uiSettings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _footerGap),
              Center(
                child: Text(
                  context.l10n.settings_versionLine(AppInfo.name, '1.0.0'),
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
  // different setting next. Dialog/bottom-sheet items (Help &
  // Support, App Info, Language) keep working exactly as they do on
  // mobile - they're small, modal-appropriate content, not worth
  // dedicating a whole pane to.
  Widget _buildDesktopLayout(BuildContext context) {
    final uiSettings = Provider.of<UiSettingsProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Whatever's genuinely first in the sidebar for this role -
    // Subscription for an Admin (top of the list), Notifications for
    // an Assistant (who never sees the Subscription section at all).
    _selectedKey ??= isAdmin ? 'subscription' : 'notifications';

    final currentLanguageName = AppDefaults.languageNames[uiSettings.languageCode];

    return Scaffold(
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
                            icon: Icons.workspace_premium_outlined,
                            label: context.l10n.settings_subscriptionBilling,
                            navigateKey: 'subscription',
                          ),
                          const SizedBox(height: AppSpacing.s16),
                        ],
                        _buildSectionTitle(context.l10n.settings_accountData),
                        const SizedBox(height: AppSpacing.s4),
                        if (isAdmin)
                          _buildSidebarItem(
                            icon: Icons.delete_outline,
                            label: context.l10n.activityType_trash,
                            navigateKey: 'trash',
                          ),
                        if (isAdmin)
                          _buildSidebarItem(
                            icon: Icons.import_export,
                            label: context.l10n.settings_exportData,
                            navigateKey: 'export',
                          ),
                        if (isAdmin)
                          _buildSidebarItem(
                            icon: Icons.schedule_outlined,
                            label: context.l10n.hours_title,
                            navigateKey: 'business_hours',
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
                          icon: Icons.print_outlined,
                          label: context.l10n.printer_title,
                          navigateKey: 'printer',
                        ),
                        _buildSidebarItem(
                          icon: Icons.help_outline,
                          label: context.l10n.settings_helpSupport,
                          onTapDialog: () => _showHelpSupportDialog(context),
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
                          icon: Icons.currency_exchange_outlined,
                          label: context.l10n.settings_currency,
                          trailingText: AppDefaults.currencySymbol,
                          onTapDialog: () {}, // not a real choice - no picker to open
                        ),
                        _buildSidebarItem(
                          icon: Icons.language_outlined,
                          label: context.l10n.settings_languageBoth,
                          trailingText: currentLanguageName,
                          onTapDialog: () => _showLanguageSelection(context, uiSettings),
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
            child: _buildContentPane(isAdmin),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPane(bool isAdmin) {
    switch (_selectedKey) {
      case 'subscription':
        return isAdmin ? const SubscriptionScreen() : _buildEmptyPane();
      case 'notifications':
        return const NotificationsScreen();
      case 'printer':
        return const PrinterSettingsScreen();
      case 'trash':
        return isAdmin ? const TrashScreen() : _buildEmptyPane();
      case 'export':
        return isAdmin ? const ExportDataScreen() : _buildEmptyPane();
      case 'business_hours':
        return isAdmin ? const BusinessHoursScreen() : _buildEmptyPane();
      case 'manage_account':
        return const ManageAccountScreen();
      default:
        return _buildEmptyPane();
    }
  }

  Widget _buildEmptyPane() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_outlined, size: AppIconSize.i56, color: context.colors.border),
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
              ? () => setState(() => _selectedKey = navigateKey)
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

  void _showLanguageSelection(BuildContext context, UiSettingsProvider uiSettings) {
    showModalBottomSheet(
      context: context,
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
                style: TextStyle(fontSize: AppFontSize.f11, fontWeight: AppFontWeight.bold, color: context.colors.primary, letterSpacing: 1.1),
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
          fontSize: AppFontSize.f11,
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
            _infoRow(context.l10n.settings_version, '1.0.0'),
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


  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Row(
          children: [
            Icon(Icons.help_outline, color: context.colors.primary),
            const SizedBox(width: AppSpacing.s8),
            Text(context.l10n.settings_helpSupport),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.chat, color: context.colors.success),
              title: Text(context.l10n.debtors_viaWhatsApp),
              subtitle: const Text(AppContact.supportPhone),
              onTap: () => _launchUrl(AppLinks.whatsApp(AppContact.supportPhone).toString()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.call, color: context.colors.primary),
              title: Text(context.l10n.common_call),
              subtitle: const Text(AppContact.supportPhone),
              onTap: () => _launchUrl(AppLinks.tel(AppContact.supportPhone).toString()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.email_outlined, color: context.colors.primary),
              title: Text(context.l10n.common_email),
              subtitle: const Text(AppContact.supportEmail),
              onTap: () => _launchUrl(AppLinks.mailto(AppContact.supportEmail).toString()),
            ),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
