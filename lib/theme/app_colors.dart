import 'package:flutter/material.dart';

import 'app_palette.dart';

/// The app's colours by ROLE (what a colour is for), registered on the theme.
///
/// Screens used to pick raw shades directly (`Colors.grey[600]`,
/// `Colors.black87`, ...), so a colour theme or Dark Mode had nothing to
/// change: there was no single place that said "this is muted text". Each role
/// here holds EXACTLY the legacy shade it replaces (Phase 2 spec, section 4.1),
/// so moving a screen onto these roles changes nothing visible. Tidying the
/// values (for example merging the two reds) is a separate, reviewed step.
///
/// Read with `context.colors` (see theme_context.dart).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.onPrimary,
    required this.onPrimaryMuted,
    required this.onPrimarySubtle,
    required this.textStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSoft,
    required this.textMuted,
    required this.textHint,
    required this.textDisabled,
    required this.borderStrong,
    required this.border,
    required this.divider,
    required this.success,
    required this.successStrong,
    required this.danger,
    required this.dangerAccent,
    required this.dangerSoft,
    required this.dangerStrong,
    required this.dangerDeep,
    required this.warning,
    required this.warningStrong,
    required this.info,
    required this.infoStrong,
  });

  // Brand - the only roles that vary by colour theme for now.
  final Color primary;
  final Color accent;
  final Color background;

  // Surfaces.
  /// Cards, sheets, dialogs, app bars, inputs (legacy `Colors.white` as a fill).
  final Color surface;
  final Color surfaceMuted;

  // Text and icons on a coloured (brand) fill.
  final Color onPrimary;
  final Color onPrimaryMuted;
  final Color onPrimarySubtle;

  // Text, strongest to faintest.
  final Color textStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textSoft;
  final Color textMuted;
  final Color textHint;
  final Color textDisabled;

  // Lines.
  final Color borderStrong;
  final Color border;
  final Color divider;

  // Statuses.
  final Color success;
  final Color successStrong;

  /// `danger` and `dangerAccent` are deliberately separate: both are used
  /// about 140 times and are visibly different reds. Merging them is a
  /// refinement (step 2R) decision, not a migration one.
  final Color danger;
  final Color dangerAccent;
  final Color dangerSoft;
  final Color dangerStrong;
  final Color dangerDeep;
  final Color warning;
  final Color warningStrong;
  final Color info;
  final Color infoStrong;

  /// The roles for a colour theme. Every value is the exact legacy shade.
  static AppColors fromTheme(AppColorTheme theme) => AppColors(
        primary: theme.primary,
        accent: theme.accent,
        background: AppPalette.background,
        surface: Colors.white,
        surfaceMuted: Colors.grey.shade100,
        onPrimary: Colors.white,
        onPrimaryMuted: Colors.white70,
        onPrimarySubtle: Colors.white24,
        textStrong: Colors.black,
        textPrimary: Colors.black87,
        textSecondary: Colors.black54,
        textSoft: Colors.grey.shade700,
        textMuted: Colors.grey.shade600,
        textHint: Colors.grey,
        textDisabled: Colors.grey.shade400,
        borderStrong: Colors.grey.shade400,
        border: Colors.grey.shade300,
        divider: Colors.grey.shade200,
        success: Colors.green,
        successStrong: Colors.green.shade700,
        danger: Colors.red,
        dangerAccent: Colors.redAccent,
        dangerSoft: Colors.red.shade400,
        dangerStrong: Colors.red.shade700,
        dangerDeep: Colors.red.shade900,
        warning: Colors.orange,
        warningStrong: Colors.orange.shade800,
        info: Colors.blue,
        infoStrong: Colors.blue.shade700,
      );

  @override
  AppColors copyWith({
    Color? primary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? onPrimary,
    Color? onPrimaryMuted,
    Color? onPrimarySubtle,
    Color? textStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textSoft,
    Color? textMuted,
    Color? textHint,
    Color? textDisabled,
    Color? borderStrong,
    Color? border,
    Color? divider,
    Color? success,
    Color? successStrong,
    Color? danger,
    Color? dangerAccent,
    Color? dangerSoft,
    Color? dangerStrong,
    Color? dangerDeep,
    Color? warning,
    Color? warningStrong,
    Color? info,
    Color? infoStrong,
  }) =>
      AppColors(
        primary: primary ?? this.primary,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        onPrimary: onPrimary ?? this.onPrimary,
        onPrimaryMuted: onPrimaryMuted ?? this.onPrimaryMuted,
        onPrimarySubtle: onPrimarySubtle ?? this.onPrimarySubtle,
        textStrong: textStrong ?? this.textStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textSoft: textSoft ?? this.textSoft,
        textMuted: textMuted ?? this.textMuted,
        textHint: textHint ?? this.textHint,
        textDisabled: textDisabled ?? this.textDisabled,
        borderStrong: borderStrong ?? this.borderStrong,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        success: success ?? this.success,
        successStrong: successStrong ?? this.successStrong,
        danger: danger ?? this.danger,
        dangerAccent: dangerAccent ?? this.dangerAccent,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        dangerStrong: dangerStrong ?? this.dangerStrong,
        dangerDeep: dangerDeep ?? this.dangerDeep,
        warning: warning ?? this.warning,
        warningStrong: warningStrong ?? this.warningStrong,
        info: info ?? this.info,
        infoStrong: infoStrong ?? this.infoStrong,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: l(primary, other.primary),
      accent: l(accent, other.accent),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryMuted: l(onPrimaryMuted, other.onPrimaryMuted),
      onPrimarySubtle: l(onPrimarySubtle, other.onPrimarySubtle),
      textStrong: l(textStrong, other.textStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textSoft: l(textSoft, other.textSoft),
      textMuted: l(textMuted, other.textMuted),
      textHint: l(textHint, other.textHint),
      textDisabled: l(textDisabled, other.textDisabled),
      borderStrong: l(borderStrong, other.borderStrong),
      border: l(border, other.border),
      divider: l(divider, other.divider),
      success: l(success, other.success),
      successStrong: l(successStrong, other.successStrong),
      danger: l(danger, other.danger),
      dangerAccent: l(dangerAccent, other.dangerAccent),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      dangerStrong: l(dangerStrong, other.dangerStrong),
      dangerDeep: l(dangerDeep, other.dangerDeep),
      warning: l(warning, other.warning),
      warningStrong: l(warningStrong, other.warningStrong),
      info: l(info, other.info),
      infoStrong: l(infoStrong, other.infoStrong),
    );
  }
}
