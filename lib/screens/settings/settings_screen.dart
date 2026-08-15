import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_role_provider.dart';

import 'manage_account_screen.dart';
import 'printer_settings_screen.dart';
import 'export_data_screen.dart';
import 'trash_screen.dart';
import '../subscription/subscription_screen.dart';
import 'business_profile_screen.dart';
import '../platform_admin/platform_admin_home_screen.dart';
import '../dashboard/stock_alerts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _isPlatformAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('platform_admins').doc(user.uid).get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2F5D62);
    final Color backgroundColor = const Color(0xFFFDFDF9);
    
    // Listening to your established app provider
    final settings = Provider.of<SettingsProvider>(context);
    const double cardElevation = 2.0; 


    final currentLanguageMap = settings.supportedLanguages.firstWhere(
      (element) => element['code'] == settings.selectedLanguage,
      orElse: () => {'code': 'en', 'name': 'English'},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
          _buildSectionTitle('Business Profile', primaryColor),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: _buildSettingsItem(
              icon: Icons.storefront_outlined,
              label: 'Logo & Business Details',
              primaryColor: primaryColor,
              isLast: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Subscription', primaryColor),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Subscription & Billing',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                ),
                FutureBuilder<bool>(
                  future: _isPlatformAdmin(),
                  builder: (context, snapshot) {
                    // Only shown to platform admins - previously this menu
                    // entry appeared for every facility's admin and assistant,
                    // who would just hit "access denied" after tapping it.
                    if (snapshot.data != true) return const SizedBox.shrink();

                    return _buildSettingsItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Platform Admin',
                      primaryColor: primaryColor,
                      isLast: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlatformAdminHomeScreen()),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          ],
          const SizedBox(height: 20),
          _buildSectionTitle('General', primaryColor),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StockAlertsScreen()),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.print_outlined,
                  label: 'Printer & Receipt Settings',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrinterSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () => _showHelpSupportDialog(context, primaryColor, backgroundColor),
                ),
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  label: 'App Info',
                  primaryColor: primaryColor,
                  isLast: true,
                  onTap: () => _showAppInfoDialog(context, primaryColor, backgroundColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Account & Data', primaryColor),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                _buildSettingsItem(
                  icon: Icons.delete_outline,
                  label: 'Trash / Deleted Items',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                _buildSettingsItem(
                  icon: Icons.import_export,
                  label: 'Export Data',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExportDataScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Manage Account',
                  primaryColor: primaryColor,
                  isLast: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageAccountScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Preferences', primaryColor),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.color_lens_outlined,
                  label: 'Theme Mode',
                  trailingText: 'System Defaults',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    // TODO: Implement theme switch block smoothly later
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.currency_exchange_outlined,
                  label: 'Currency',
                  trailingText: '🇹🇿 Tsh',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {}, // not a real choice - no picker to open
                ),
                _buildSettingsItem(
                  icon: Icons.language_outlined,
                  label: 'Language / Lugha',
                  trailingText: currentLanguageMap['name'],
                  primaryColor: primaryColor,
                  isLast: true,
                  onTap: () => _showLanguageSelection(context, settings, primaryColor, backgroundColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),
          const Center(
            child: Text(
              'VetBiz Pro • v1.0.0',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
          ),
        ),
      ),
    );
  }

  // --- Dynamic Bottom Sheets for Data Scalability ---

  void _showLanguageSelection(BuildContext context, SettingsProvider settings, Color primaryColor, Color backgroundColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT LANGUAGE / CHAGUA LUGHA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.1),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: settings.supportedLanguages.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final lang = settings.supportedLanguages[index];
                    final bool isSelected = lang['code'] == settings.selectedLanguage;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(lang['name']!),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? primaryColor : Colors.grey.shade300,
                      ),
                      onTap: () {
                        settings.setLanguage(lang['code']!);
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
    required Color primaryColor,
    required bool isLast,
    String? trailingText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Icon(icon, color: primaryColor.withValues(alpha: 0.85), size: 24),
          title: Text(
            label, 
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(
                Icons.chevron_right_rounded, 
                color: Colors.grey, 
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
            color: Colors.grey.shade200, 
            indent: 54,
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: primaryColor.withValues(alpha: 0.75),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context, Color primaryColor, Color backgroundColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: primaryColor),
            const SizedBox(width: 8),
            const Text('App Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('App Name', 'VetBiz Pro'),
            _infoRow('Version', '1.0.0'),
            _infoRow('Built For', 'Veterinary & agrovet business management'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  static const String _supportPhone = '+255719199916';
  static const String _supportEmail = 'shanelvmi@gmail.com';

  void _showHelpSupportDialog(BuildContext context, Color primaryColor, Color backgroundColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Row(
          children: [
            Icon(Icons.help_outline, color: primaryColor),
            const SizedBox(width: 8),
            const Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp'),
              subtitle: const Text(_supportPhone),
              onTap: () => _launchUrl('https://wa.me/${_supportPhone.replaceAll('+', '')}'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.call, color: primaryColor),
              title: const Text('Call'),
              subtitle: const Text(_supportPhone),
              onTap: () => _launchUrl('tel:$_supportPhone'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.email_outlined, color: primaryColor),
              title: const Text('Email'),
              subtitle: const Text(_supportEmail),
              onTap: () => _launchUrl('mailto:$_supportEmail'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: primaryColor)),
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