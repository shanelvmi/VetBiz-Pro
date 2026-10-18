import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/dark_derivation.dart';

/// K1 (docs/design/dark_mode.md section 7, items 1 to 4): every theme has a
/// full set of dark roles, the values are the design's, every contrast pair
/// of section 5 passes (computed here), and light is unchanged.
void main() {
  const dark = Brightness.dark;

  Map<String, Color> allRoles(AppColors c) => {
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
      };

  String hex(Color c) => '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';

  group('1. every dark role exists', () {
    test('68 roles', () {
      expect(allRoles(AppColors.fromTheme(AppColorTheme.pasture, brightness: dark)).length, 68);
    });

    for (final theme in AppColorTheme.all) {
      test('${theme.id}: copyWith() and lerp(..., 0) keep every dark role', () {
        final c = AppColors.fromTheme(theme, brightness: dark);
        final want = allRoles(c);
        final other = AppColors.fromTheme(theme == AppColorTheme.pasture ? AppColorTheme.ledger : AppColorTheme.pasture);
        for (final copy in [c.copyWith(), c.lerp(other, 0)]) {
          final got = allRoles(copy);
          for (final e in want.entries) {
            expect(got[e.key]!.toARGB32(), e.value.toARGB32(), reason: '${theme.id} ${e.key}');
          }
        }
      });
    }
  });

  group('2. the dark values (dark_mode.md section 3)', () {
    // Per theme, in the order of the section 3 table.
    const table = <String, Map<String, int>>{
      'pasture': {
        'background': 0xFF0E1718, 'surface': 0xFF162325, 'surfaceMuted': 0xFF1E2F31, 'primary': 0xFF509EA7,
        'accent': 0xFFFFB200, 'onPrimary': 0xFF0E1718, 'onAccent': 0xFF0E1718, 'brandSurface': 0xFF2F5D62,
        'sidebarHover': 0xFF00796B, 'sidebarPress': 0xFF00695C, 'brandTealGlow': 0xFF7EE8CB,
        'brandTeal': 0xFF419588, 'quickActionTintPrimary': 0xFF1B2F32, 'quickActionTintAccent': 0xFF3B3016,
      },
      'clinic': {
        'background': 0xFF0E1318, 'surface': 0xFF161E25, 'surfaceMuted': 0xFF1E2831, 'primary': 0xFF4992D1,
        'accent': 0xFF5BC0EB, 'onPrimary': 0xFF0E1318, 'onAccent': 0xFF0E1318, 'brandSurface': 0xFF0F4C81,
        'sidebarHover': 0xFF005A78, 'sidebarPress': 0xFF004F68, 'brandTealGlow': 0xFF7EDEE8,
        'brandTeal': 0xFF1195BA, 'quickActionTintPrimary': 0xFF1B2732, 'quickActionTintAccent': 0xFF16303B,
      },
      'harvest': {
        'background': 0xFF18120E, 'surface': 0xFF251C16, 'surfaceMuted': 0xFF31251E, 'primary': 0xFFB58463,
        'accent': 0xFFE3A72F, 'onPrimary': 0xFF18120E, 'onAccent': 0xFF18120E, 'brandSurface': 0xFF4A3426,
        'sidebarHover': 0xFF64391D, 'sidebarPress': 0xFF583219, 'brandTealGlow': 0xFFDDAA89,
        'brandTeal': 0xFFB07A58, 'quickActionTintPrimary': 0xFF32241B, 'quickActionTintAccent': 0xFF3B2F16,
      },
      'ledger': {
        'background': 0xFF0E1218, 'surface': 0xFF161C25, 'surfaceMuted': 0xFF1E2531, 'primary': 0xFF708DBA,
        'accent': 0xFF8B9CFF, 'onPrimary': 0xFF0E1218, 'onAccent': 0xFF0E1218, 'brandSurface': 0xFF1E293B,
        'sidebarHover': 0xFF013559, 'sidebarPress': 0xFF012D4A, 'brandTealGlow': 0xFF7ECEE8,
        'brandTeal': 0xFF518CAE, 'quickActionTintPrimary': 0xFF1B2332, 'quickActionTintAccent': 0xFF161C3B,
      },
    };

    // The same in every theme.
    const shared = <String, int>{
      'textStrong': 0xFFFFFFFF, 'textSoft': 0xFFBDBDBD, 'textMuted': 0xFF9E9E9E, 'textHint': 0xFF808080,
      'onBrandSurface': 0xFFFFFFFF, 'scrim': 0xFF000000, 'shadow': 0xFF000000,
      'success': 0xFF4CAF50, 'successStrong': 0xFF42A847, 'danger': 0xFFF44336, 'dangerAccent': 0xFFFF5252,
      'dangerSoft': 0xFFEF5350, 'dangerStrong': 0xFFE17272, 'dangerDeep': 0xFFE96F6F, 'warning': 0xFFFF9800,
      'warningStrong': 0xFFEF6C00, 'info': 0xFF2196F3, 'infoStrong': 0xFF4597E9, 'infoNote': 0xFF78909C,
      'infoNoteText': 0xFF7B97A4, 'infoNoteTextSoft': 0xFF7E99A6, 'trendUp': 0xFF10B981, 'trendDown': 0xFFEF4444,
      'warningBannerText': 0xFFD68100, 'warningBannerFill': 0xFF302412, 'dangerSurface': 0xFF321515,
      'chart1': 0xFF5177A9, 'chart2': 0xFF8667B0, 'chart3': 0xFFB56A00, 'chart4': 0xFFBC37D3,
      'chart5': 0xFF607D8B, 'chart6': 0xFF009688, 'chart7': 0xFF606FC7, 'chart8': 0xFFFFA000,
      'chart9': 0xFFFF5722, 'chartService1': 0xFF5C7C99, 'chartService2': 0xFF8FA998,
      'chartService3': 0xFFB98B6F, 'chartService4': 0xFF9B8AA6, 'roleOwner': 0xFF606FC7,
      'roleOwnerStrong': 0xFF8490DA, 'roleCoAdmin': 0xFF009688, 'roleCoAdminStrong': 0xFF00A794,
      'roleAssistant': 0xFF607D8B, 'roleAssistantStrong': 0xFF7E99A6, 'rolePlatformAdmin': 0xFF8861CD,
    };

    for (final theme in AppColorTheme.all) {
      test('${theme.id}: the table, the shared values and the translucent roles', () {
        final c = AppColors.fromTheme(theme, brightness: dark);
        final roles = allRoles(c);
        for (final e in {...table[theme.id]!, ...shared}.entries) {
          expect(hex(roles[e.key]!), hex(Color(e.value)), reason: '${theme.id} ${e.key}');
        }
        // White, and the dark background, at the design's opacities.
        final white = {'textPrimary': 0.87, 'textSecondary': 0.70, 'textDisabled': 0.38,
            'borderStrong': 0.30, 'border': 0.16, 'divider': 0.10};
        for (final e in white.entries) {
          expect(roles[e.key]!.toARGB32(), Colors.white.withValues(alpha: e.value).toARGB32(), reason: e.key);
        }
        expect(c.onPrimaryMuted.toARGB32(), c.background.withValues(alpha: 0.85).toARGB32());
        expect(c.onPrimarySubtle.toARGB32(), c.background.withValues(alpha: 0.24).toARGB32());
      });
    }

    test('the rules on a made-up theme: surfaces get lighter, every lift reaches its threshold', () {
      const t = AppColorTheme(
        id: 'made_up', name: 'Made up',
        primary: Color(0xFF5A1E4B), accent: Color(0xFF3FAF6A), background: Color(0xFFFAF8FA),
      );
      final c = AppColors.fromTheme(t, brightness: dark);
      final l = ColorMath.luminance;
      expect(l(c.background) < l(c.surface) && l(c.surface) < l(c.surfaceMuted), isTrue);
      expect(ColorMath.contrast(c.primary, c.surfaceMuted), greaterThanOrEqualTo(4.5));
      expect(ColorMath.contrast(c.brandTeal, c.surface), greaterThanOrEqualTo(4.5));
      expect(ColorMath.contrast(c.primary, c.quickActionTintPrimary), greaterThanOrEqualTo(4.5));
      expect(HSLColor.fromColor(c.primary).hue, closeTo(HSLColor.fromColor(t.primary).hue, 1));
      expect(c.brandSurface, t.primary);
      // A lift keeps the colour when it already passes, and otherwise
      // stops at the first step that does.
      const bg = Color(0xFF1E2F31);
      expect(DarkDerivation.lift(Colors.green, 3.0, bg), Colors.green);
      final lifted = DarkDerivation.lift(Colors.indigo, 3.0, bg);
      expect(ColorMath.contrast(lifted, bg), greaterThanOrEqualTo(3.0));
      final oneStepLess = HSLColor.fromColor(lifted).withLightness(HSLColor.fromColor(lifted).lightness - 0.01).toColor();
      expect(ColorMath.contrast(oneStepLess, bg), lessThan(3.0));
    });
  });

  group('3. contrast in dark, every theme (dark_mode.md section 5)', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: every pair at its threshold', () {
        final c = AppColors.fromTheme(theme, brightness: dark);
        void pass(String name, Color fg, Color bg, double min) =>
            expect(ColorMath.contrast(fg, bg), greaterThanOrEqualTo(min), reason: '${theme.id} $name');

        final fills = {'surface': c.surface, 'surfaceMuted': c.surfaceMuted, 'background': c.background};
        final text = {'textStrong': c.textStrong, 'textPrimary': c.textPrimary, 'textSecondary': c.textSecondary,
            'textSoft': c.textSoft, 'textMuted': c.textMuted, 'primary': c.primary};
        for (final f in fills.entries) {
          for (final t in text.entries) {
            pass('${t.key} on ${f.key}', t.value, f.value, 4.5);
          }
          pass('textHint on ${f.key}', c.textHint, f.value, 3.0);
        }
        pass('onPrimary on primary', c.onPrimary, c.primary, 4.5);
        pass('onPrimaryMuted on primary', c.onPrimaryMuted, c.primary, 4.5);
        pass('accent on surface', c.accent, c.surface, 3.0);
        pass('onAccent on accent', c.onAccent, c.accent, 4.5);
        for (final f in {'brandSurface': c.brandSurface, 'sidebarHover': c.sidebarHover, 'sidebarPress': c.sidebarPress}.entries) {
          pass('onBrandSurface on ${f.key}', c.onBrandSurface, f.value, 4.5);
        }
        pass('brandTealGlow on brandSurface', c.brandTealGlow, c.brandSurface, 4.5);
        pass('brandTeal on surface', c.brandTeal, c.surface, 4.5);
        pass('primary on quickActionTintPrimary', c.primary, c.quickActionTintPrimary, 4.5);
        pass('textPrimary on quickActionTintAccent', c.textPrimary, c.quickActionTintAccent, 4.5);
        pass('warningBannerText on warningBannerFill', c.warningBannerText, c.warningBannerFill, 4.5);
        pass('dangerDeep on dangerSurface', c.dangerDeep, c.dangerSurface, 4.5);

        final marks = {'success': c.success, 'danger': c.danger, 'dangerAccent': c.dangerAccent,
            'dangerSoft': c.dangerSoft, 'warning': c.warning, 'info': c.info, 'infoNote': c.infoNote,
            'trendUp': c.trendUp, 'trendDown': c.trendDown, 'chart1': c.chart1, 'chart2': c.chart2,
            'chart3': c.chart3, 'chart4': c.chart4, 'chart5': c.chart5, 'chart6': c.chart6, 'chart7': c.chart7,
            'chart8': c.chart8, 'chart9': c.chart9, 'chartService1': c.chartService1,
            'chartService2': c.chartService2, 'chartService3': c.chartService3, 'chartService4': c.chartService4,
            'roleOwner': c.roleOwner, 'roleCoAdmin': c.roleCoAdmin, 'roleAssistant': c.roleAssistant,
            'rolePlatformAdmin': c.rolePlatformAdmin};
        final inks = {'successStrong': c.successStrong, 'dangerStrong': c.dangerStrong, 'dangerDeep': c.dangerDeep,
            'warningStrong': c.warningStrong, 'infoStrong': c.infoStrong, 'infoNoteText': c.infoNoteText,
            'infoNoteTextSoft': c.infoNoteTextSoft, 'warningBannerText': c.warningBannerText,
            'roleOwnerStrong': c.roleOwnerStrong, 'roleCoAdminStrong': c.roleCoAdminStrong,
            'roleAssistantStrong': c.roleAssistantStrong};
        for (final f in fills.entries) {
          for (final m in marks.entries) {
            pass('${m.key} on ${f.key}', m.value, f.value, 3.0);
          }
          for (final i in inks.entries) {
            pass('${i.key} on ${f.key}', i.value, f.value, 4.5);
          }
        }
      });
    }

    // Known, kept (section 5): held at "no worse than computed minus 0.2".
    // textDisabled: disabled controls are exempt in WCAG, and light is 1.88.
    // onPrimarySubtle: sidebar dividers, not text.
    const textDisabledLowest = {'pasture': 3.34, 'clinic': 3.44, 'harvest': 3.42, 'ledger': 3.47};
    const onPrimarySubtle = {'pasture': 1.50, 'clinic': 1.49, 'harvest': 1.50, 'ledger': 1.51};
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: the known fails get no worse', () {
        final c = AppColors.fromTheme(theme, brightness: dark);
        for (final f in [c.surface, c.surfaceMuted, c.background]) {
          expect(ColorMath.contrast(c.textDisabled, f), greaterThanOrEqualTo(textDisabledLowest[theme.id]! - 0.2));
        }
        expect(ColorMath.contrast(c.onPrimarySubtle, c.primary), greaterThanOrEqualTo(onPrimarySubtle[theme.id]! - 0.2));
      });
    }
  });

  group('4. light is unchanged', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: no brightness = light, and the new roles equal primary, onPrimary, textPrimary', () {
        final byDefault = allRoles(AppColors.fromTheme(theme));
        final light = allRoles(AppColors.fromTheme(theme, brightness: Brightness.light));
        for (final e in byDefault.entries) {
          expect(light[e.key]!.toARGB32(), e.value.toARGB32(), reason: '${theme.id} ${e.key}');
        }
        expect(light['brandSurface'], light['primary']);
        expect(light['onBrandSurface'], light['onPrimary']);
        expect(light['onAccent'], light['textPrimary']);
      });
    }
  });
}
