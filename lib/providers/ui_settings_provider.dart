import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_palette.dart';

/// How the app looks and lays itself out - the choices in UI Settings.
///
/// Personal to this device (like the sidebar's collapsed state), not part of
/// the account, so they live in local storage and are NOT cleared when the
/// user's data is reset on sign-out or refresh.
class UiSettingsProvider with ChangeNotifier {
  static const String _layoutFixedKey = 'ui_layout_fixed';
  static const String _colorThemeKey = 'ui_color_theme';

  bool _layoutFixed = false;
  String _colorThemeId = AppColorTheme.defaultId;
  bool _loaded = false;

  UiSettingsProvider() {
    _load();
  }

  /// True once the saved choices have been read.
  bool get loaded => _loaded;

  /// Layout Fixed Mode: the sidebar is held open (large screens) and its
  /// collapse button is hidden. The person's own collapsed/expanded choice is
  /// stored separately and left alone, so turning this off restores it.
  bool get layoutFixed => _layoutFixed;

  AppColorTheme get colorTheme => AppColorTheme.byId(_colorThemeId);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _layoutFixed = prefs.getBool(_layoutFixedKey) ?? false;
      // Only a theme that can actually be used is restored.
      final saved = AppColorTheme.byId(prefs.getString(_colorThemeKey));
      if (saved.available) _colorThemeId = saved.id;
    } catch (e) {
      // Settings are a convenience: if they can't be read, the defaults stand.
      debugPrint('[UI SETTINGS] could not read saved settings: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLayoutFixed(bool value) async {
    if (_layoutFixed == value) return;
    _layoutFixed = value;
    notifyListeners(); // the screen follows at once; saving happens behind it
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_layoutFixedKey, value);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save layout setting: $e');
    }
  }

  /// Chooses a colour theme. A theme that isn't available yet is ignored.
  Future<void> setColorTheme(String id) async {
    final theme = AppColorTheme.byId(id);
    if (!theme.available || theme.id == _colorThemeId) return;
    _colorThemeId = theme.id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_colorThemeKey, theme.id);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save colour theme: $e');
    }
  }
}
