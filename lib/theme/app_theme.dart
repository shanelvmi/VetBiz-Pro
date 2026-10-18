import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// Builds the app-wide [ThemeData] for a colour theme.
///
/// Moved here unchanged from `VetBizProApp.build` in main.dart, so the theme
/// lives with the rest of the look and can follow the colour theme chosen in
/// UI Settings. With the default theme (Pasture) the result is
/// identical to what main.dart built before.
///
/// [Brightness.dark] builds Dark Mode (docs/design/dark_mode.md section 4,
/// Material widgets): the colour scheme comes from the dark roles, so the
/// widgets Material colours itself (dialogs, snack bars, switches, chips,
/// menus) follow them. The light theme is built exactly as before.
class AppTheme {
  AppTheme._();

  static ThemeData build(AppColorTheme theme, Brightness brightness) {
    if (brightness == Brightness.dark) return _buildDark(theme);

    // Brand colors, defined once here so the WHOLE app's theme - text field
    // focus borders, the blinking cursor, date picker selections - uses them
    // automatically, instead of every screen needing to remember to override
    // Flutter's default blue individually.
    final Color primaryDeepGreen = theme.primary;
    final Color warmAmber = theme.accent;
    final Color offWhite = theme.background;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryDeepGreen,
      brightness: brightness,
    ).copyWith(
      primary: primaryDeepGreen,
      secondary: warmAmber,
      surface: offWhite,
    );

    return _themeData(
      colorScheme: colorScheme,
      page: offWhite,
      brand: primaryDeepGreen,
      onBrand: offWhite,
      enabledBorder: Colors.grey.shade400,
      colors: AppColors.fromTheme(theme),
    );
  }

  static ThemeData _buildDark(AppColorTheme theme) {
    final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: theme.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      surface: c.surface,
      surfaceContainerLowest: c.surfaceMuted,
      surfaceContainerLow: c.surfaceMuted,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceMuted,
      error: c.danger,
    );

    return _themeData(
      colorScheme: colorScheme,
      page: c.background,
      brand: c.primary,
      // The date picker's header and selected day, and button text, on the
      // light dark-mode primary: `surface`, not the page background.
      onBrand: c.surface,
      enabledBorder: c.borderStrong,
      colors: c,
    );
  }

  static ThemeData _themeData({
    required ColorScheme colorScheme,
    required Color page,
    required Color brand,
    required Color onBrand,
    required Color enabledBorder,
    required AppColors colors,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: page,
      // The blinking text cursor and the highlighted selection in every
      // text field, app-wide.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: brand.withValues(alpha: 0.3),
        selectionHandleColor: brand,
      ),
      // The outline/underline every text field shows once focused
      // (tapped into), app-wide.
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: brand, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: enabledBorder),
        ),
        floatingLabelStyle: TextStyle(color: brand),
      ),
      // The calendar shown by every showDatePicker call, app-wide (header,
      // selected day, "today" outline).
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: brand,
        headerForegroundColor: onBrand,
        todayBorder: BorderSide(color: brand),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onBrand;
          return brand;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onBrand;
          return null;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return null;
        }),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: brand),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: brand),
      ),
      // Buttons that don't explicitly set their own colors fall back to
      // these, instead of Material's default blue.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: onBrand,
        ),
      ),
      // The colour roles screens read with `context.colors`.
      extensions: [colors],
    );
  }
}
