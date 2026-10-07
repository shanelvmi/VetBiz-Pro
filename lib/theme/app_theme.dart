import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// Builds the app-wide [ThemeData] for a colour theme.
///
/// Moved here unchanged from `VetBizProApp.build` in main.dart, so the theme
/// lives with the rest of the look and can follow the colour theme chosen in
/// UI Settings. With the default theme (Kilimanjaro Green) the result is
/// identical to what main.dart built before.
class AppTheme {
  AppTheme._();

  static ThemeData build(AppColorTheme theme, Brightness brightness) {
    // Brand colors, defined once here so the WHOLE app's theme - text field
    // focus borders, the blinking cursor, date picker selections - uses them
    // automatically, instead of every screen needing to remember to override
    // Flutter's default blue individually.
    final Color primaryDeepGreen = theme.primary;
    final Color warmAmber = theme.accent;
    const Color offWhite = AppPalette.background;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryDeepGreen,
      brightness: brightness,
    ).copyWith(
      primary: primaryDeepGreen,
      secondary: warmAmber,
      surface: offWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: offWhite,
      // The blinking text cursor and the highlighted selection in every
      // text field, app-wide.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryDeepGreen,
        selectionColor: primaryDeepGreen.withValues(alpha: 0.3),
        selectionHandleColor: primaryDeepGreen,
      ),
      // The outline/underline every text field shows once focused
      // (tapped into), app-wide.
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryDeepGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
      ),
      // The calendar shown by every showDatePicker call, app-wide (header,
      // selected day, "today" outline).
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: primaryDeepGreen,
        headerForegroundColor: offWhite,
        todayBorder: BorderSide(color: primaryDeepGreen),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return offWhite;
          return primaryDeepGreen;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return offWhite;
          return null;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDeepGreen;
          return null;
        }),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
      ),
      // Buttons that don't explicitly set their own colors fall back to
      // these, instead of Material's default blue.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDeepGreen,
          foregroundColor: offWhite,
        ),
      ),
      // The colour roles screens read with `context.colors`.
      extensions: [AppColors.fromTheme(theme)],
    );
  }
}
