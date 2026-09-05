import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  // --- Your Existing States ---
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  bool _showTrash = false;
  bool get showTrash => _showTrash;

  String _exportFormat = 'PDF'; // or 'CSV'
  String get exportFormat => _exportFormat;

  // --- New Scalable Preference States ---
  String _selectedCurrency = 'TZS';
  String _selectedLanguage = 'en';

  String get selectedCurrency => _selectedCurrency;
  String get selectedLanguage => _selectedLanguage;

  // Centralized, scalable matrix definitions
  final List<Map<String, String>> supportedCurrencies = [
    {'code': 'TZS', 'name': 'Tanzanian Shilling'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'UGX', 'name': 'Ugandan Shilling'},
    {'code': 'USD', 'name': 'United States Dollar'},
  ];

  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'sw', 'name': 'Kiswahili'},
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

  void setLanguage(String code) {
    _selectedLanguage = code;
    notifyListeners();
  }
}