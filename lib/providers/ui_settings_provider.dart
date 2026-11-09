import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_defaults.dart';
import '../data/home_card_mode.dart';
import '../data/ui_theme_mode.dart';
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
  /// Public for UpdatesStore (AN6), which warms the posters for the saved
  /// language before this provider has loaded.
  static const String languageKey = 'ui_language';
  static const String _themeModeKey = 'ui_theme_mode';
  static const String _homeAmountsHiddenKey = 'ui_home_amounts_hidden';
  static const String _homeCardModeKey = 'ui_home_card_mode';

  bool _layoutFixed = false;
  String _colorThemeId = AppColorTheme.defaultId;
  String _languageCode = AppDefaults.defaultLanguage;
  UiThemeMode _themeMode = UiThemeMode.defaultMode;
  bool _homeAmountsHidden = false;
  HomeCardMode _homeCardMode = HomeCardMode.defaultMode;
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

  /// System, Light or Dark (Dark Mode). System follows the platform's
  /// setting, live (on the web: the browser's prefers-color-scheme).
  UiThemeMode get themeMode => _themeMode;

  /// NAV1: the phone Today card's eye. True while its amounts are masked;
  /// visible by default, remembered on this device only (never synced). It
  /// only changes what the card draws, never a figure.
  bool get homeAmountsHidden => _homeAmountsHidden;

  /// HUB2: the phone Home card's switch, Sales or Vet services; Sales by
  /// default, remembered on this device only.
  HomeCardMode get homeCardMode => _homeCardMode;

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
      final language = prefs.getString(languageKey);
      if (AppDefaults.supportedLanguages.contains(language)) {
        _languageCode = language!;
        L10n.setLocale(locale);
      }
      // An unknown or missing value leaves the default.
      _themeMode = UiThemeMode.fromKey(prefs.getString(_themeModeKey));
      _homeAmountsHidden = prefs.getBool(_homeAmountsHiddenKey) ?? false;
      _homeCardMode = HomeCardMode.fromKey(prefs.getString(_homeCardModeKey));
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

  Future<void> setHomeAmountsHidden(bool value) async {
    if (_homeAmountsHidden == value) return;
    _homeAmountsHidden = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_homeAmountsHiddenKey, value);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save the amounts choice: $e');
    }
  }

  Future<void> setHomeCardMode(HomeCardMode value) async {
    if (_homeCardMode == value) return;
    _homeCardMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeCardModeKey, value.key);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save the Home card choice: $e');
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
      await prefs.setString(languageKey, code);
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

  /// Chooses System, Light or Dark.
  Future<void> setThemeMode(UiThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.key);
    } catch (e) {
      debugPrint('[UI SETTINGS] could not save theme mode: $e');
    }
  }
}
