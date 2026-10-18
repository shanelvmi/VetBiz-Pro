import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

/// The proof of "no visual change" for the token layer: every default value
/// equals the legacy value it replaces (Phase 2 spec, section 4).
void main() {
  // Compared as ARGB so `Colors.grey` (a MaterialColor) and a plain Color of
  // the same shade count as equal: what matters is the pixel colour.
  void same(Color actual, Color legacy, String role) =>
      expect(actual.toARGB32(), legacy.toARGB32(), reason: role);

  group('AppColors default (Kilimanjaro Green) equals the legacy colours', () {
    final c = AppColors.fromTheme(AppColorTheme.pasture);
    final legacy = <String, (Color, Color)>{
      'primary': (c.primary, AppPalette.primary),
      'accent': (c.accent, AppPalette.accent),
      'background': (c.background, AppPalette.background),
      'surface': (c.surface, Colors.white),
      'surfaceMuted': (c.surfaceMuted, Colors.grey[100]!),
      'onPrimary': (c.onPrimary, Colors.white),
      'onPrimaryMuted': (c.onPrimaryMuted, Colors.white70),
      'onPrimarySubtle': (c.onPrimarySubtle, Colors.white24),
      'textStrong': (c.textStrong, Colors.black),
      'textPrimary': (c.textPrimary, Colors.black87),
      'textSecondary': (c.textSecondary, Colors.black54),
      'textSoft': (c.textSoft, Colors.grey[700]!),
      'textMuted': (c.textMuted, Colors.grey[600]!),
      'textHint': (c.textHint, Colors.grey),
      'textDisabled': (c.textDisabled, Colors.grey[400]!),
      'borderStrong': (c.borderStrong, Colors.grey[400]!),
      'border': (c.border, Colors.grey[300]!),
      'divider': (c.divider, Colors.grey[200]!),
      'success': (c.success, Colors.green),
      'successStrong': (c.successStrong, Colors.green[700]!),
      'danger': (c.danger, Colors.red),
      'dangerAccent': (c.dangerAccent, Colors.redAccent),
      'dangerSoft': (c.dangerSoft, Colors.red[400]!),
      'dangerStrong': (c.dangerStrong, Colors.red[700]!),
      'dangerDeep': (c.dangerDeep, Colors.red[900]!),
      'warning': (c.warning, Colors.orange),
      'warningStrong': (c.warningStrong, Colors.orange[800]!),
      'info': (c.info, Colors.blue),
      'infoStrong': (c.infoStrong, Colors.blue[700]!),
      // Info notes (receipt previews, report review), as they were.
      'infoNote': (c.infoNote, Colors.blueGrey[400]!),
      'infoNoteText': (c.infoNoteText, Colors.blueGrey[600]!),
      'infoNoteTextSoft': (c.infoNoteTextSoft, Colors.blueGrey[500]!),
      // summary_card.dart's trend pill, as it was.
      'trendUp': (c.trendUp, const Color(0xFF10B981)),
      'trendDown': (c.trendDown, const Color(0xFFEF4444)),
      // The login and register alert fill, as it was.
      'dangerSurface': (c.dangerSurface, const Color(0xFFFFF1F0)),
      'scrim': (c.scrim, Colors.black),
      'shadow': (c.shadow, Colors.black),
      // Client-type category colours (clients_screen.dart), as they were.
      'chart1': (c.chart1, const Color(0xFF3D5A80)),
      'chart2': (c.chart2, const Color(0xFF6A4C93)),
      'chart3': (c.chart3, const Color(0xFFB56A00)),
      // Report summary tiles (report_tabbed_content.dart), as they were.
      'chart4': (c.chart4, Colors.purple),
      'chart5': (c.chart5, Colors.blueGrey),
      'chart6': (c.chart6, Colors.teal),
      'chart7': (c.chart7, Colors.indigo),
      'chart8': (c.chart8, Colors.amber.shade700),
      'chart9': (c.chart9, Colors.deepOrange),
      // Team role chips (manage_assistants_screen.dart), as they were.
      'roleOwner': (c.roleOwner, Colors.indigo),
      'roleOwnerStrong': (c.roleOwnerStrong, Colors.indigo[700]!),
      'roleCoAdmin': (c.roleCoAdmin, Colors.teal),
      'roleCoAdminStrong': (c.roleCoAdminStrong, Colors.teal[700]!),
      'roleAssistant': (c.roleAssistant, Colors.blueGrey),
      'roleAssistantStrong': (c.roleAssistantStrong, Colors.blueGrey[700]!),
    };

    for (final entry in legacy.entries) {
      test(entry.key, () => same(entry.value.$1, entry.value.$2, entry.key));
    }

    test('textHint is the same shade as grey[500]', () {
      same(c.textHint, Colors.grey[500]!, 'textHint');
    });

    test('copyWith with no arguments and lerp at 0 keep every role', () {
      final copy = c.copyWith();
      final lerped = c.lerp(AppColors.fromTheme(AppColorTheme.clinic), 0);
      for (final pair in [(copy, 'copyWith'), (lerped, 'lerp')]) {
        same(pair.$1.primary, c.primary, '${pair.$2} primary');
        same(pair.$1.textMuted, c.textMuted, '${pair.$2} textMuted');
        same(pair.$1.infoStrong, c.infoStrong, '${pair.$2} infoStrong');
      }
    });
  });

  // R2 (docs/design/parked_values.md): each parked value that became a role
  // keeps its EXACT old value, in every theme, so the screen is unchanged.
  // T0 may derive the brand-linked ones per theme; this test then changes.
  group('R2 roles hold the exact parked values', () {
    const pinned = <String, int>{
      'sidebarHover': 0xFF00796B, // teal 700
      'sidebarPress': 0xFF00695C, // teal 800
      'warningBannerText': 0xFFC77800,
      'warningBannerFill': 0xFFFFF6E7,
      'quickActionTintPrimary': 0xFFE3F0EC,
      'quickActionTintAccent': 0xFFFCEFD9,
      'chartService1': 0xFF5C7C99,
      'chartService2': 0xFF8FA998,
      'chartService3': 0xFFB98B6F,
      'chartService4': 0xFF9B8AA6,
      'brandTeal': 0xFF3E8E82,
      'brandTealGlow': 0xFF7EE8CB,
      'rolePlatformAdmin': 0xFF673AB7, // deepPurple
    };
    Map<String, Color> roles(AppColors c) => {
          'sidebarHover': c.sidebarHover,
          'sidebarPress': c.sidebarPress,
          'warningBannerText': c.warningBannerText,
          'warningBannerFill': c.warningBannerFill,
          'quickActionTintPrimary': c.quickActionTintPrimary,
          'quickActionTintAccent': c.quickActionTintAccent,
          'chartService1': c.chartService1,
          'chartService2': c.chartService2,
          'chartService3': c.chartService3,
          'chartService4': c.chartService4,
          'brandTeal': c.brandTeal,
          'brandTealGlow': c.brandTealGlow,
          'rolePlatformAdmin': c.rolePlatformAdmin,
        };

    for (final theme in AppColorTheme.all) {
      test('theme ${theme.id}', () {
        final c = AppColors.fromTheme(theme);
        final got = roles(c);
        expect(got.keys, pinned.keys);
        for (final e in pinned.entries) {
          expect(got[e.key]!.toARGB32(), e.value, reason: e.key);
        }
        // copyWith and lerp carry every new role.
        final other = AppColors.fromTheme(AppColorTheme.all.last);
        for (final copy in [c.copyWith(), c.lerp(other, 0)]) {
          final kept = roles(copy);
          for (final e in pinned.entries) {
            expect(kept[e.key]!.toARGB32(), e.value, reason: e.key);
          }
        }
      });
    }
  });

  group('AppTheme.build gives the theme main.dart used to build', () {
    final theme = AppTheme.build(AppColorTheme.pasture, Brightness.light);

    test('colour scheme and page background', () {
      expect(theme.useMaterial3, isTrue);
      same(theme.colorScheme.primary, AppPalette.primary, 'scheme primary');
      same(theme.colorScheme.secondary, AppPalette.accent, 'scheme secondary');
      same(theme.colorScheme.surface, AppPalette.background, 'scheme surface');
      expect(theme.colorScheme.brightness, Brightness.light);
      same(theme.scaffoldBackgroundColor, AppPalette.background, 'scaffold');
    });

    test('text selection', () {
      final s = theme.textSelectionTheme;
      same(s.cursorColor!, AppPalette.primary, 'cursor');
      same(s.selectionColor!, AppPalette.primary.withValues(alpha: 0.3), 'selection');
      same(s.selectionHandleColor!, AppPalette.primary, 'handle');
    });

    test('text field borders and floating label', () {
      final i = theme.inputDecorationTheme;
      final focused = i.focusedBorder! as OutlineInputBorder;
      same(focused.borderSide.color, AppPalette.primary, 'focused border');
      expect(focused.borderSide.width, 2);
      final enabled = i.enabledBorder! as OutlineInputBorder;
      same(enabled.borderSide.color, Colors.grey.shade400, 'enabled border');
      same(i.floatingLabelStyle!.color!, AppPalette.primary, 'floating label');
    });

    test('date picker', () {
      final d = theme.datePickerTheme;
      same(d.headerBackgroundColor!, AppPalette.primary, 'header bg');
      same(d.headerForegroundColor!, AppPalette.background, 'header fg');
      same(d.todayBorder!.color, AppPalette.primary, 'today border');
      same(d.todayForegroundColor!.resolve({})!, AppPalette.primary, 'today fg');
      same(d.todayForegroundColor!.resolve({WidgetState.selected})!, AppPalette.background,
          'today fg selected');
      expect(d.dayForegroundColor!.resolve({}), isNull);
      same(d.dayForegroundColor!.resolve({WidgetState.selected})!, AppPalette.background,
          'day fg selected');
      expect(d.dayBackgroundColor!.resolve({}), isNull);
      same(d.dayBackgroundColor!.resolve({WidgetState.selected})!, AppPalette.primary,
          'day bg selected');
      same(d.confirmButtonStyle!.foregroundColor!.resolve({})!, AppPalette.primary, 'confirm');
      same(d.cancelButtonStyle!.foregroundColor!.resolve({})!, AppPalette.primary, 'cancel');
    });

    test('buttons', () {
      same(theme.textButtonTheme.style!.foregroundColor!.resolve({})!, AppPalette.primary,
          'text button');
      final e = theme.elevatedButtonTheme.style!;
      same(e.backgroundColor!.resolve({})!, AppPalette.primary, 'elevated bg');
      same(e.foregroundColor!.resolve({})!, AppPalette.background, 'elevated fg');
    });

    test('AppColors is registered on the theme', () {
      final c = theme.extension<AppColors>();
      expect(c, isNotNull);
      same(c!.primary, AppPalette.primary, 'extension primary');
    });
  });

  group('dimension ladders hold the number in their name', () {
    test('font sizes', () {
      expect([
        AppFontSize.f9, AppFontSize.f10, AppFontSize.f10_5, AppFontSize.f11, AppFontSize.f11_5,
        AppFontSize.f12, AppFontSize.f12_5, AppFontSize.f13, AppFontSize.f13_5, AppFontSize.f14,
        AppFontSize.f14_5, AppFontSize.f15, AppFontSize.f16, AppFontSize.f17, AppFontSize.f18,
        AppFontSize.f19, AppFontSize.f20, AppFontSize.f22, AppFontSize.f24, AppFontSize.f28,
      ], [9, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 16, 17, 18, 19, 20, 22, 24, 28]);
    });

    test('font weights', () {
      expect(AppFontWeight.regular, FontWeight.normal);
      expect(AppFontWeight.medium, FontWeight.w500);
      expect(AppFontWeight.semibold, FontWeight.w600);
      expect(AppFontWeight.bold, FontWeight.w700);
      expect(AppFontWeight.extraBold, FontWeight.w800);
    });

    test('spacing', () {
      expect([
        AppSpacing.s2, AppSpacing.s3, AppSpacing.s4, AppSpacing.s6, AppSpacing.s8,
        AppSpacing.s10, AppSpacing.s12, AppSpacing.s14, AppSpacing.s16, AppSpacing.s18,
        AppSpacing.s20, AppSpacing.s22, AppSpacing.s24, AppSpacing.s28, AppSpacing.s32,
      ], [2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32]);
    });

    test('radius', () {
      expect([
        AppRadius.r4, AppRadius.r6, AppRadius.r7, AppRadius.r8, AppRadius.r10,
        AppRadius.r12, AppRadius.r14, AppRadius.r16, AppRadius.r20, AppRadius.r24, AppRadius.pill,
      ], [4, 6, 7, 8, 10, 12, 14, 16, 20, 24, 999]);
    });

    test('icon sizes, elevation, alpha', () {
      expect([
        AppIconSize.i12, AppIconSize.i14, AppIconSize.i16, AppIconSize.i18, AppIconSize.i20,
        AppIconSize.i22, AppIconSize.i24, AppIconSize.i32, AppIconSize.i40, AppIconSize.i48, AppIconSize.i56,
        AppIconSize.i64,
      ], [12, 14, 16, 18, 20, 22, 24, 32, 40, 48, 56, 64]);
      expect([AppElevation.e0, AppElevation.e1, AppElevation.e2, AppElevation.e6, AppElevation.e8],
          [0, 1, 2, 6, 8]);
      expect([
        AppAlpha.a05, AppAlpha.a10, AppAlpha.a15, AppAlpha.a20,
        AppAlpha.a30, AppAlpha.a40, AppAlpha.a50, AppAlpha.a70, AppAlpha.a85,
      ], [0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.7, 0.85]);
    });

    test('motion', () {
      expect(AppMotion.fast.inMilliseconds, 150);
      expect(AppMotion.normal.inMilliseconds, 220);
      expect(AppMotion.slow.inMilliseconds, 300);
      expect(AppMotion.slower.inMilliseconds, 400);
      expect(AppMotion.slowest.inMilliseconds, 500);
      expect(AppMotion.loop.inMilliseconds, 900);
      expect(AppMotion.colorCycle.inMilliseconds, 1400);
      expect(AppMotion.emphasis.inMilliseconds, 900);
      expect(AppMotion.float.inMilliseconds, 1400);
      expect(AppMotion.pulseSlow.inSeconds, 2);
      expect(AppMotion.toastShort.inSeconds, 2);
      expect(AppMotion.toastLong.inSeconds, 3);
      expect([
        AppMotion.toastSuccess, AppMotion.toastInfo, AppMotion.toastWarning,
        AppMotion.toastUndo, AppMotion.toastError,
      ].map((d) => d.inSeconds), [3, 4, 5, 6, 7]);
      expect(AppMotion.toastDetailed.inSeconds, 6);
    });

    test('feedback sizes', () {
      expect(AppSizes.toastMax, 400);
      expect(AppSizes.statusDot, 8);
      expect(AppSizes.toastIcon, 28);
      expect(AppSizes.minTapTarget, 40);
    });
  });
}
