import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/ui_theme_mode.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

/// K1 (docs/design/dark_mode.md section 7, item 5 and section 4's Material
/// widgets row): the System/Light/Dark setting and the dark ThemeData.
void main() {
  Future<UiSettingsProvider> loaded() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }

  test('the stored values, in order, and what they mean', () {
    expect(UiThemeMode.values.map((m) => m.key).toList(), ['system', 'light', 'dark']);
    expect(UiThemeMode.values.map((m) => m.themeMode).toList(), [ThemeMode.system, ThemeMode.light, ThemeMode.dark]);
    expect(UiThemeMode.defaultMode, UiThemeMode.system);
  });

  test('missing or unknown reads as the default (System, G1)', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await loaded()).themeMode, UiThemeMode.system);
    SharedPreferences.setMockInitialValues({'ui_theme_mode': 'midnight'});
    expect((await loaded()).themeMode, UiThemeMode.system);
    expect(UiThemeMode.fromKey(null), UiThemeMode.system);
  });

  for (final mode in UiThemeMode.values) {
    test('${mode.key} is saved and survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await loaded();
      // Start from a different value so the save is a real change.
      final other = mode == UiThemeMode.dark ? UiThemeMode.system : UiThemeMode.dark;
      await first.setThemeMode(other);
      await first.setThemeMode(mode);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui_theme_mode'), mode.key);
      expect((await loaded()).themeMode, mode);
    });
  }

  group('AppTheme.build for dark', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: colour scheme and widgets from the dark roles', () {
        final t = AppTheme.build(theme, Brightness.dark);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        final s = t.colorScheme;
        expect(s.brightness, Brightness.dark);
        expect(s.primary, c.primary);
        expect(s.onPrimary, c.onPrimary);
        expect(s.secondary, c.accent);
        expect(s.surface, c.surface);
        for (final container in [s.surfaceContainerLowest, s.surfaceContainerLow, s.surfaceContainer,
            s.surfaceContainerHigh, s.surfaceContainerHighest]) {
          expect(container, c.surfaceMuted);
        }
        expect(s.error, c.danger);
        expect(t.scaffoldBackgroundColor, c.background);
        expect(t.extension<AppColors>()!.primary, c.primary);
        expect(t.datePickerTheme.headerForegroundColor, c.surface);
        expect(t.datePickerTheme.headerBackgroundColor, c.primary);
        final enabled = t.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(enabled.borderSide.color, c.borderStrong);
      });
    }
  });
}
