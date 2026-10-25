import 'package:flutter/material.dart';

/// The Dark Mode choice in UI Settings, saved on the device under
/// `ui_theme_mode` (docs/design/dark_mode.md section 6). [key] is the stored
/// string and never changes; what is shown comes from the ARB.
enum UiThemeMode {
  system('system', ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const UiThemeMode(this.key, this.themeMode);

  final String key;
  final ThemeMode themeMode;

  /// System (G1): a person who has not chosen sees the app the way their
  /// device or browser is set. It was Light until the dark screens were
  /// finished (K5); a saved Light or Dark is kept.
  static const UiThemeMode defaultMode = system;

  /// The choice for a stored value. Unknown or missing gives [defaultMode].
  static UiThemeMode fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return defaultMode;
  }
}
