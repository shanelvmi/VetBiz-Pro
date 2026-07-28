import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

import 'manage_account_screen.dart';
import 'printer_settings_screen.dart';
import 'export_data_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2F5D62);
    final Color backgroundColor = const Color(0xFFFDFDF9);
    
    // Listening to your established app provider
    final settings = Provider.of<SettingsProvider>(context);
    const double cardElevation = 2.0; 

    // Lookups to show the currently active configuration text right on the main tiles
    final currentCurrencyMap = settings.supportedCurrencies.firstWhere(
      (element) => element['code'] == settings.selectedCurrency,
      orElse: () => {'code': 'TZS', 'name': 'Tanzanian Shilling', 'flag': '🇹🇿'},
    );

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
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    // TODO: Open notifications screen
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
                  onTap: () {
                    // TODO: Open support screen
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  label: 'App Info',
                  primaryColor: primaryColor,
                  isLast: true,
                  onTap: () {
                    // TODO: Show app details
                  },
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
                _buildSettingsItem(
                  icon: Icons.delete_outline,
                  label: 'Trash / Deleted Items',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () {
                    // TODO: Navigate to TrashScreen
                  },
                ),
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
                  label: 'Currency Config',
                  trailingText: '${currentCurrencyMap['flag']} ${currentCurrencyMap['code']}',
                  primaryColor: primaryColor,
                  isLast: false,
                  onTap: () => _showCurrencySelection(context, settings, primaryColor, backgroundColor),
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
    );
  }

  // --- Dynamic Bottom Sheets for Data Scalability ---

  void _showCurrencySelection(BuildContext context, SettingsProvider settings, Color primaryColor, Color backgroundColor) {
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
                'SELECT SYSTEM CURRENCY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.1),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: settings.supportedCurrencies.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final currency = settings.supportedCurrencies[index];
                    final bool isSelected = currency['code'] == settings.selectedCurrency;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(currency['flag']!, style: const TextStyle(fontSize: 24)),
                      title: Text('${currency['name']} (${currency['code']})'),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? primaryColor : Colors.grey.shade300,
                      ),
                      onTap: () {
                        settings.setCurrency(currency['code']!);
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
          leading: Icon(icon, color: primaryColor.withOpacity(0.85), size: 24),
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
          color: primaryColor.withOpacity(0.75),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}