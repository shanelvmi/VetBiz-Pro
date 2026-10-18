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
    required this.infoNote,
    required this.infoNoteText,
    required this.infoNoteTextSoft,
    required this.trendUp,
    required this.trendDown,
    required this.dangerSurface,
    required this.scrim,
    required this.shadow,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.chart6,
    required this.chart7,
    required this.chart8,
    required this.chart9,
    required this.roleOwner,
    required this.roleOwnerStrong,
    required this.roleCoAdmin,
    required this.roleCoAdminStrong,
    required this.roleAssistant,
    required this.roleAssistantStrong,
    required this.sidebarHover,
    required this.sidebarPress,
    required this.warningBannerText,
    required this.warningBannerFill,
    required this.quickActionTintPrimary,
    required this.quickActionTintAccent,
    required this.chartService1,
    required this.chartService2,
    required this.chartService3,
    required this.chartService4,
    required this.brandTeal,
    required this.brandTealGlow,
    required this.rolePlatformAdmin,
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

  // Quiet info notes (an info_outline icon and a line of help text): the
  // receipt previews and the report review. Blue-grey, not the textHint
  // grey; exact legacy shades. `infoNote` is the icon (blueGrey[400]),
  // `infoNoteText` the receipt notes' text (blueGrey[600]) and
  // `infoNoteTextSoft` the report review note's text (blueGrey[500]).
  final Color infoNote;
  final Color infoNoteText;
  final Color infoNoteTextSoft;

  // The KPI trend pill (summary_card.dart). Its own green and red, not
  // `success`/`danger`: no existing role is within 12 on every channel.
  final Color trendUp;
  final Color trendDown;

  // The fill of the login and register error alerts: a pale pink, exact
  // legacy value (owner decision after D8; surfaceMuted lost the tint).
  final Color dangerSurface;

  // Darkening layers, not text: a scrim over a photo, and card shadows.
  // Kept apart from textStrong because Dark Mode turns text light, and
  // these must stay dark.
  final Color scrim;
  final Color shadow;

  // Category colours, exact legacy values (spec 4.1: "chart or category
  // colour -> chart1..chartN"). Today: client types Vet, Wholesaler and
  // Retailer (clients_screen.dart); chart1 is also the dashboard's
  // services colour (dashboard_screen.dart, not yet migrated). chart4..6
  // are the report summary tiles Debt Repayments (purple), Transactions
  // (blueGrey) and Services Performed (teal) in report_tabbed_content.dart.
  // chart5 and chart6 hold the same values as roleAssistant and roleCoAdmin,
  // but for a different purpose, so they are separate roles. Activity types
  // (activity_type_style.dart) reuse chart4 (Services), chart6 (Clients)
  // and chart7 (Transactions, indigo). Notification types
  // (notification_model.dart) add chart8 (Reorder Soon, amber 700) and
  // chart9 (Debt Reminder, deep orange).
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;
  final Color chart6;
  final Color chart7;
  final Color chart8;
  final Color chart9;

  // Team roles (manage_assistants_screen.dart role chips): a light fill of
  // the base colour with the Strong shade as the label. Exact legacy values.
  final Color roleOwner;
  final Color roleOwnerStrong;
  final Color roleCoAdmin;
  final Color roleCoAdminStrong;
  final Color roleAssistant;
  final Color roleAssistantStrong;

  // Parked values given a role in R2 (docs/design/parked_values.md, owner
  // approved): exact legacy values, so nothing changes on screen. The same
  // in every theme for now; T0 derives the brand-linked ones per theme.
  // Drawer item hover and the platform-admin button press (dashboard).
  final Color sidebarHover;
  final Color sidebarPress;

  // The subscription banner's text and icon, and its fill (warning, not
  // a theme colour).
  final Color warningBannerText;
  final Color warningBannerFill;

  // Quick-action tints: Record Visit (of the primary), Add Product (of the
  // accent). Brand-linked.
  final Color quickActionTintPrimary;
  final Color quickActionTintAccent;

  // The services palette: steel blue (also the dashboard chart's
  // Services), sage, terracotta, lavender (the "Other" slice) on insights.
  final Color chartService1;
  final Color chartService2;
  final Color chartService3;
  final Color chartService4;

  // The login teal and its light glow (login and register gradients); the
  // teal is also the insights accent, the Total Products metric and the
  // operator sidebar badge. Brand-linked.
  final Color brandTeal;
  final Color brandTealGlow;

  // The Platform Admin chip, icon and avatar (users_tab.dart).
  final Color rolePlatformAdmin;

  /// The roles for a colour theme. Every value is the exact legacy shade.
  static AppColors fromTheme(AppColorTheme theme) => AppColors(
        primary: theme.primary,
        accent: theme.accent,
        background: theme.background,
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
        infoNote: Colors.blueGrey.shade400,
        infoNoteText: Colors.blueGrey.shade600,
        infoNoteTextSoft: Colors.blueGrey.shade500,
        trendUp: const Color(0xFF10B981),
        trendDown: const Color(0xFFEF4444),
        dangerSurface: const Color(0xFFFFF1F0),
        scrim: Colors.black,
        shadow: Colors.black,
        chart1: const Color(0xFF3D5A80),
        chart2: const Color(0xFF6A4C93),
        chart3: const Color(0xFFB56A00),
        chart4: Colors.purple,
        chart5: Colors.blueGrey,
        chart6: Colors.teal,
        chart7: Colors.indigo,
        chart8: Colors.amber.shade700,
        chart9: Colors.deepOrange,
        roleOwner: Colors.indigo,
        roleOwnerStrong: Colors.indigo.shade700,
        roleCoAdmin: Colors.teal,
        roleCoAdminStrong: Colors.teal.shade700,
        roleAssistant: Colors.blueGrey,
        roleAssistantStrong: Colors.blueGrey.shade700,
        sidebarHover: Colors.teal.shade700,
        sidebarPress: Colors.teal.shade800,
        warningBannerText: const Color(0xFFC77800),
        warningBannerFill: const Color(0xFFFFF6E7),
        quickActionTintPrimary: const Color(0xFFE3F0EC),
        quickActionTintAccent: const Color(0xFFFCEFD9),
        chartService1: const Color(0xFF5C7C99),
        chartService2: const Color(0xFF8FA998),
        chartService3: const Color(0xFFB98B6F),
        chartService4: const Color(0xFF9B8AA6),
        brandTeal: const Color(0xFF3E8E82),
        brandTealGlow: const Color(0xFF7EE8CB),
        rolePlatformAdmin: Colors.deepPurple,
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
    Color? infoNote,
    Color? infoNoteText,
    Color? infoNoteTextSoft,
    Color? trendUp,
    Color? trendDown,
    Color? dangerSurface,
    Color? scrim,
    Color? shadow,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? chart6,
    Color? chart7,
    Color? chart8,
    Color? chart9,
    Color? roleOwner,
    Color? roleOwnerStrong,
    Color? roleCoAdmin,
    Color? roleCoAdminStrong,
    Color? roleAssistant,
    Color? roleAssistantStrong,
    Color? sidebarHover,
    Color? sidebarPress,
    Color? warningBannerText,
    Color? warningBannerFill,
    Color? quickActionTintPrimary,
    Color? quickActionTintAccent,
    Color? chartService1,
    Color? chartService2,
    Color? chartService3,
    Color? chartService4,
    Color? brandTeal,
    Color? brandTealGlow,
    Color? rolePlatformAdmin,
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
        infoNote: infoNote ?? this.infoNote,
        infoNoteText: infoNoteText ?? this.infoNoteText,
        infoNoteTextSoft: infoNoteTextSoft ?? this.infoNoteTextSoft,
        trendUp: trendUp ?? this.trendUp,
        trendDown: trendDown ?? this.trendDown,
        dangerSurface: dangerSurface ?? this.dangerSurface,
        scrim: scrim ?? this.scrim,
        shadow: shadow ?? this.shadow,
        chart1: chart1 ?? this.chart1,
        chart2: chart2 ?? this.chart2,
        chart3: chart3 ?? this.chart3,
        chart4: chart4 ?? this.chart4,
        chart5: chart5 ?? this.chart5,
        chart6: chart6 ?? this.chart6,
        chart7: chart7 ?? this.chart7,
        chart8: chart8 ?? this.chart8,
        chart9: chart9 ?? this.chart9,
        roleOwner: roleOwner ?? this.roleOwner,
        roleOwnerStrong: roleOwnerStrong ?? this.roleOwnerStrong,
        roleCoAdmin: roleCoAdmin ?? this.roleCoAdmin,
        roleCoAdminStrong: roleCoAdminStrong ?? this.roleCoAdminStrong,
        roleAssistant: roleAssistant ?? this.roleAssistant,
        roleAssistantStrong: roleAssistantStrong ?? this.roleAssistantStrong,
        sidebarHover: sidebarHover ?? this.sidebarHover,
        sidebarPress: sidebarPress ?? this.sidebarPress,
        warningBannerText: warningBannerText ?? this.warningBannerText,
        warningBannerFill: warningBannerFill ?? this.warningBannerFill,
        quickActionTintPrimary: quickActionTintPrimary ?? this.quickActionTintPrimary,
        quickActionTintAccent: quickActionTintAccent ?? this.quickActionTintAccent,
        chartService1: chartService1 ?? this.chartService1,
        chartService2: chartService2 ?? this.chartService2,
        chartService3: chartService3 ?? this.chartService3,
        chartService4: chartService4 ?? this.chartService4,
        brandTeal: brandTeal ?? this.brandTeal,
        brandTealGlow: brandTealGlow ?? this.brandTealGlow,
        rolePlatformAdmin: rolePlatformAdmin ?? this.rolePlatformAdmin,
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
      infoNote: l(infoNote, other.infoNote),
      infoNoteText: l(infoNoteText, other.infoNoteText),
      infoNoteTextSoft: l(infoNoteTextSoft, other.infoNoteTextSoft),
      trendUp: l(trendUp, other.trendUp),
      trendDown: l(trendDown, other.trendDown),
      dangerSurface: l(dangerSurface, other.dangerSurface),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
      chart1: l(chart1, other.chart1),
      chart2: l(chart2, other.chart2),
      chart3: l(chart3, other.chart3),
      chart4: l(chart4, other.chart4),
      chart5: l(chart5, other.chart5),
      chart6: l(chart6, other.chart6),
      chart7: l(chart7, other.chart7),
      chart8: l(chart8, other.chart8),
      chart9: l(chart9, other.chart9),
      roleOwner: l(roleOwner, other.roleOwner),
      roleOwnerStrong: l(roleOwnerStrong, other.roleOwnerStrong),
      roleCoAdmin: l(roleCoAdmin, other.roleCoAdmin),
      roleCoAdminStrong: l(roleCoAdminStrong, other.roleCoAdminStrong),
      roleAssistant: l(roleAssistant, other.roleAssistant),
      roleAssistantStrong: l(roleAssistantStrong, other.roleAssistantStrong),
      sidebarHover: l(sidebarHover, other.sidebarHover),
      sidebarPress: l(sidebarPress, other.sidebarPress),
      warningBannerText: l(warningBannerText, other.warningBannerText),
      warningBannerFill: l(warningBannerFill, other.warningBannerFill),
      quickActionTintPrimary: l(quickActionTintPrimary, other.quickActionTintPrimary),
      quickActionTintAccent: l(quickActionTintAccent, other.quickActionTintAccent),
      chartService1: l(chartService1, other.chartService1),
      chartService2: l(chartService2, other.chartService2),
      chartService3: l(chartService3, other.chartService3),
      chartService4: l(chartService4, other.chartService4),
      brandTeal: l(brandTeal, other.brandTeal),
      brandTealGlow: l(brandTealGlow, other.brandTealGlow),
      rolePlatformAdmin: l(rolePlatformAdmin, other.rolePlatformAdmin),
    );
  }
}
