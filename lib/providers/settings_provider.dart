import 'package:flutter/material.dart';

import '../config/app_defaults.dart';

class SettingsProvider with ChangeNotifier {
  // --- Your Existing States ---
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  bool _showTrash = false;
  bool get showTrash => _showTrash;

  String _exportFormat = 'PDF'; // or 'CSV'
  String get exportFormat => _exportFormat;

  // --- New Scalable Preference States ---
  // The display language lives in UiSettingsProvider (a saved device setting).
  String _selectedCurrency = AppDefaults.currencyCode;

  String get selectedCurrency => _selectedCurrency;

  // Centralized, scalable matrix definitions
  final List<Map<String, String>> supportedCurrencies = [
    {'code': AppDefaults.currencyCode, 'name': 'Tanzanian Shilling'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'UGX', 'name': 'Ugandan Shilling'},
    {'code': 'USD', 'name': 'United States Dollar'},
  ];

  // --- Your Existing Toggle Methods ---
  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void toggleTrash(bool value) {
    _showTrash = value;
    notifyListeners();
  }

  void setExportFormat(String format) {
    _exportFormat = format;
    notifyListeners();
  }

  // --- New Selection Setters ---
  void setCurrency(String code) {
    _selectedCurrency = code;
    notifyListeners();
  }
}