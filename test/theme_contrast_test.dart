import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

/// T1 (docs/design/themes.md sections 2, 5, 7 and 10): every theme builds a
/// full AppColors, only the brand-linked roles differ between themes, and
/// every contrast pair passes, computed here. The tests loop over
/// AppColorTheme.all, so a theme added later is checked with no edit here.
void main() {
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
      };

  // The roles that follow the theme: its three base colours and what is
  // derived from them. Everything else must be the same in every theme.
  const themed = {
    'primary', 'accent', 'background', 'textMuted', 'sidebarHover', 'sidebarPress',
    'brandTeal', 'brandTealGlow', 'quickActionTintPrimary', 'quickActionTintAccent',
  };

  group('each theme builds a full AppColors', () {
    test('every role is listed here (the constructor has 65)', () {
      expect(allRoles(AppColors.fromTheme(AppColorTheme.pasture)).length, 65);
    });

    for (final theme in AppColorTheme.all) {
      test('${theme.id}: base colours, and copyWith()/lerp(..., 0) keep every role', () {
        final c = AppColors.fromTheme(theme);
        expect(c.primary, theme.primary);
        expect(c.accent, theme.accent);
        expect(c.background, theme.background);
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

    test('no non-brand role differs between any two themes', () {
      final pasture = allRoles(AppColors.fromTheme(AppColorTheme.pasture));
      for (final theme in AppColorTheme.all) {
        final roles = allRoles(AppColors.fromTheme(theme));
        for (final e in roles.entries) {
          if (themed.contains(e.key)) continue;
          expect(e.value.toARGB32(), pasture[e.key]!.toARGB32(), reason: '${theme.id} ${e.key}');
        }
      }
    });
  });

  group('contrast, computed (WCAG 2.1)', () {
    // (name, foreground, background, threshold): 4.5 for text, 3.0 for
    // icons, large text and the accent on the primary.
    final pairs = <(String, Color Function(AppColors), Color Function(AppColors), double)>[
      // Section 2 (D10).
      ('onPrimary on primary', (c) => c.onPrimary, (c) => c.primary, 4.5),
      ('primary on background', (c) => c.primary, (c) => c.background, 4.5),
      ('textPrimary on accent', (c) => c.textPrimary, (c) => c.accent, 4.5),
      ('textStrong on accent', (c) => c.textStrong, (c) => c.accent, 4.5),
      ('accent on primary', (c) => c.accent, (c) => c.primary, 3.0),
      // Section 7: text roles on the surface roles.
      for (final (n, fg) in <(String, Color Function(AppColors))>[
        ('textStrong', (c) => c.textStrong),
        ('textPrimary', (c) => c.textPrimary),
        ('textSecondary', (c) => c.textSecondary),
        ('textSoft', (c) => c.textSoft),
      ]) ...[
        ('$n on surface', fg, (c) => c.surface, 4.5),
        ('$n on surfaceMuted', fg, (c) => c.surfaceMuted, 4.5),
        ('$n on background', fg, (c) => c.background, 4.5),
      ],
      ('textMuted on surface', (c) => c.textMuted, (c) => c.surface, 4.5),
      ('textMuted on background', (c) => c.textMuted, (c) => c.background, 4.5),
      // Section 7: on brand fills.
      ('onPrimary on sidebarHover', (c) => c.onPrimary, (c) => c.sidebarHover, 4.5),
      ('onPrimary on sidebarPress', (c) => c.onPrimary, (c) => c.sidebarPress, 4.5),
      ('onPrimaryMuted on primary', (c) => c.onPrimaryMuted, (c) => c.primary, 4.5),
      ('onPrimaryMuted on sidebarHover (secondary line, 3.44 in Pasture today)', (c) => c.onPrimaryMuted,
          (c) => c.sidebarHover, 3.0),
      ('primary on surface', (c) => c.primary, (c) => c.surface, 4.5),
      ('primary on quickActionTintPrimary', (c) => c.primary, (c) => c.quickActionTintPrimary, 4.5),
      ('textPrimary on quickActionTintAccent', (c) => c.textPrimary, (c) => c.quickActionTintAccent, 4.5),
      ('brandTeal on surface (login links, 3.89 in Pasture today; LATER: use primary)', (c) => c.brandTeal,
          (c) => c.surface, 3.0),
      ('brandTealGlow on primary', (c) => c.brandTealGlow, (c) => c.primary, 4.5),
      // Section 5: semantic roles where they sit (cards and chips on surface).
      ('infoStrong on surface (text)', (c) => c.infoStrong, (c) => c.surface, 4.5),
      ('info on surface (icon)', (c) => c.info, (c) => c.surface, 3.0),
      ('warningStrong on surface (icon)', (c) => c.warningStrong, (c) => c.surface, 3.0),
      ('dangerAccent on surface (icon)', (c) => c.dangerAccent, (c) => c.surface, 3.0),
      ('dangerDeep on dangerSurface (alert text)', (c) => c.dangerDeep, (c) => c.dangerSurface, 4.5),
      // Section 5: on each theme's background.
      for (final (n, fg) in <(String, Color Function(AppColors))>[
        ('infoNoteText', (c) => c.infoNoteText),
        ('dangerStrong', (c) => c.dangerStrong),
        ('dangerDeep', (c) => c.dangerDeep),
      ])
        ('$n on background', fg, (c) => c.background, 4.5),
      for (final (n, fg) in <(String, Color Function(AppColors))>[
        ('successStrong', (c) => c.successStrong),
        ('danger', (c) => c.danger),
        ('dangerSoft', (c) => c.dangerSoft),
        ('infoStrong', (c) => c.infoStrong),
        ('infoNote', (c) => c.infoNote),
        ('infoNoteTextSoft', (c) => c.infoNoteTextSoft),
        ('trendDown', (c) => c.trendDown),
        ('warningBannerText', (c) => c.warningBannerText),
      ])
        ('$n on background (icon)', fg, (c) => c.background, 3.0),
    ];

    for (final theme in AppColorTheme.all) {
      test('${theme.id}: every pair passes its threshold', () {
        final c = AppColors.fromTheme(theme);
        for (final (name, fg, bg, min) in pairs) {
          final ratio = ColorMath.contrast(fg(c), bg(c));
          expect(ratio, greaterThanOrEqualTo(min), reason: '${theme.id}: $name = ${ratio.toStringAsFixed(2)}');
        }
      });
    }

    // Known fails: pairs that already fail their threshold in Pasture today
    // (or move under it by at most 0.2 on the new backgrounds), kept as they
    // are, with the reason. They are held at "no worse than Pasture - 0.2"
    // and must never be counted as text-role passes. K0 reviews them.
    final known = <(String, Color Function(AppColors), Color Function(AppColors), String)>[
      for (final (n, bg) in <(String, Color Function(AppColors))>[
        ('surface', (c) => c.surface),
        ('surfaceMuted', (c) => c.surfaceMuted),
        ('background', (c) => c.background),
      ]) ...[
        ('textHint on $n', (c) => c.textHint, bg, 'hints and placeholders, not body text'),
        ('textDisabled on $n', (c) => c.textDisabled, bg, 'disabled controls (WCAG exempt)'),
      ],
      ('textMuted on surfaceMuted', (c) => c.textMuted, (c) => c.surfaceMuted,
          '4.23 in Pasture today; fills behind muted text are rare'),
      ('onPrimarySubtle on primary', (c) => c.onPrimarySubtle, (c) => c.primary, 'sidebar dividers, not text'),
      // Not here: infoStrong as text on the bare background (4.51 in
      // Pasture, 4.31 in Harvest, more than 0.2 lower). Section 5: it is
      // text on cards, so it is tested on surface at 4.5, and at 3.0 on the
      // background above.
      for (final (n, fg) in <(String, Color Function(AppColors))>[
        ('success', (c) => c.success),
        ('warning', (c) => c.warning),
        ('trendUp', (c) => c.trendUp),
      ])
        ('$n on background (icon)', fg, (c) => c.background, 'below 3:1 in Pasture today; icons and chips'),
      for (final (n, fg) in <(String, Color Function(AppColors))>[
        ('info', (c) => c.info),
        ('warningStrong', (c) => c.warningStrong),
        ('dangerAccent', (c) => c.dangerAccent),
      ])
        ('$n on background (icon)', fg, (c) => c.background, 'sits on cards and chips (tested on surface)'),
      ('warningBannerText on warningBannerFill at 0.92', (c) => c.warningBannerText,
          (c) => ColorMath.composite(c.warningBannerFill.withValues(alpha: 0.92), c.background),
          '3.23 in Pasture today; large banner text and icon'),
    ];

    test('known fails are held at no worse than Pasture - 0.2', () {
      final pasture = AppColors.fromTheme(AppColorTheme.pasture);
      for (final theme in AppColorTheme.all) {
        final c = AppColors.fromTheme(theme);
        for (final (name, fg, bg, reason) in known) {
          final floor = ColorMath.contrast(fg(pasture), bg(pasture)) - 0.2;
          final ratio = ColorMath.contrast(fg(c), bg(c));
          expect(ratio, greaterThanOrEqualTo(floor),
              reason: '${theme.id}: $name = ${ratio.toStringAsFixed(2)} ($reason)');
        }
      }
    });

    test('no theme\'s primary is close to a danger red (dE >= 20)', () {
      for (final theme in AppColorTheme.all) {
        final c = AppColors.fromTheme(theme);
        for (final red in [c.danger, c.dangerAccent, c.dangerSoft, c.dangerStrong, c.dangerDeep]) {
          expect(ColorMath.deltaE(c.primary, red), greaterThanOrEqualTo(20), reason: '${theme.id} $red');
        }
      }
    });

    test('ColorMath matches the published figures', () {
      expect(ColorMath.contrast(Colors.white, Colors.black), closeTo(21, 1e-9));
      expect(ColorMath.contrast(Colors.white, AppPalette.primary), closeTo(7.34, 0.005));
      // themes.md section 8: Harvest's primary vs dangerDeep, dE 24.7.
      expect(ColorMath.deltaE(AppColorTheme.harvest.primary, Colors.red.shade900), closeTo(24.7, 0.05));
    });
  });
}
