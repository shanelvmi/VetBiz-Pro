import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_defaults.dart';
import '../l10n/l10n.dart';
import '../theme/app_palette.dart';

/// How the app looks and lays itself out - the choices in UI Settings.
///
/// Personal to this device (like the sidebar's collapsed state), not part of
/// the account, so they live in local storage and are NOT cleared when the
/// user's data is reset on sign-out or refresh.
class UiSettingsProvider with ChangeNotifier {
  static const String _layoutFixedKey = 'ui_layout_fixed';
  static const String _colorThemeKey = 'ui_color_theme';
  static const String _languageKey = 'ui_language';

  bool _layoutFixed = false;
  String _colorThemeId = AppColorTheme.defaultId;
  String _languageCode = AppDefaults.defaultLanguage;
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

  /// The app's display language, a code from AppDefaults.supportedLanguages.
  /// Dates and amounts keep their fixed formats whatever this is.
  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _layoutFixed = prefs.getBool(_layoutFixedKey) ?? false;
      // An unknown id falls back to Pasture (byId). An id saved by an older
      // build ('kilimanjaro') is written back as its new id once, so the old
      // id does not linger.
      final savedId = prefs.getString(_colorThemeKey);
      _colorThemeId = AppColorTheme.byId(savedId).id;
      if (AppColorTheme.isLegacyId(savedId)) {
        await prefs.setString(_colorThemeKey, _colorThemeId);
      }
      // Likewise only a language the app has texts for; anything else
      // (a code from an older or newer build) leaves the default.
      final language = prefs.getString(_languageKey);
      if (AppDefaults.supportedLanguages.contains(language)) {
        _languageCode = language!;
        L10n.setLocale(locale);
      }
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

  /// Chooses the display language. A code the app has no texts for is ignored.
  Future<void> setLocale(String code) async {
    if (!AppDefaults.supportedLanguages.contains(code) || code == _languageCode) return;
    _languageCode = code;
    // Before notifying: listeners that rebuild (and any L10n.current read
    // they make) must already see the new language.
    L10n.setLocale(locale);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, code);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save language: $e');
    }
  }

  /// Chooses a colour theme. An unknown id means Pasture (byId).
  Future<void> setColorTheme(String id) async {
    final theme = AppColorTheme.byId(id);
    if (theme.id == _colorThemeId) return;
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
