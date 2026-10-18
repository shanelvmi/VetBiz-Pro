import 'dart:ui';

import 'package:vetbiz_pro/theme/app_colors.dart';

/// Every AppColors role by name (the 68 of dark_mode_test plus K3's warningDeep and infoDeep), so a test
/// can compare two sets of roles value for value.
Map<String, Color> allColorRoles(AppColors c) => {
      'primary': c.primary, 'accent': c.accent, 'background': c.background,
      'surface': c.surface, 'surfaceMuted': c.surfaceMuted,
      'onPrimary': c.onPrimary, 'onPrimaryMuted': c.onPrimaryMuted, 'onPrimarySubtle': c.onPrimarySubtle,
      'textStrong': c.textStrong, 'textPrimary': c.textPrimary, 'textSecondary': c.textSecondary,
      'textSoft': c.textSoft, 'textMuted': c.textMuted, 'textHint': c.textHint, 'textDisabled': c.textDisabled,
      'borderStrong': c.borderStrong, 'border': c.border, 'divider': c.divider,
      'success': c.success, 'successStrong': c.successStrong,
      'danger': c.danger, 'dangerAccent': c.dangerAccent, 'dangerSoft': c.dangerSoft,
      'dangerStrong': c.dangerStrong, 'dangerDeep': c.dangerDeep,
      'warning': c.warning, 'warningStrong': c.warningStrong, 'info': c.info, 'infoStrong': c.infoStrong,
      'infoNote': c.infoNote, 'infoNoteText': c.infoNoteText, 'infoNoteTextSoft': c.infoNoteTextSoft,
      'trendUp': c.trendUp, 'trendDown': c.trendDown, 'dangerSurface': c.dangerSurface,
      'scrim': c.scrim, 'shadow': c.shadow,
      'chart1': c.chart1, 'chart2': c.chart2, 'chart3': c.chart3, 'chart4': c.chart4, 'chart5': c.chart5,
      'chart6': c.chart6, 'chart7': c.chart7, 'chart8': c.chart8, 'chart9': c.chart9,
      'roleOwner': c.roleOwner, 'roleOwnerStrong': c.roleOwnerStrong,
      'roleCoAdmin': c.roleCoAdmin, 'roleCoAdminStrong': c.roleCoAdminStrong,
      'roleAssistant': c.roleAssistant, 'roleAssistantStrong': c.roleAssistantStrong,
      'sidebarHover': c.sidebarHover, 'sidebarPress': c.sidebarPress,
      'warningBannerText': c.warningBannerText, 'warningBannerFill': c.warningBannerFill,
      'quickActionTintPrimary': c.quickActionTintPrimary, 'quickActionTintAccent': c.quickActionTintAccent,
      'chartService1': c.chartService1, 'chartService2': c.chartService2,
      'chartService3': c.chartService3, 'chartService4': c.chartService4,
      'brandTeal': c.brandTeal, 'brandTealGlow': c.brandTealGlow, 'rolePlatformAdmin': c.rolePlatformAdmin,
      'brandSurface': c.brandSurface, 'onBrandSurface': c.onBrandSurface, 'onAccent': c.onAccent,
      'warningDeep': c.warningDeep, 'infoDeep': c.infoDeep,
    };
