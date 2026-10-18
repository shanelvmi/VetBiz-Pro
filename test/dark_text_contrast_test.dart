import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K5 close-out: every text role on every surface role, in Dark, for all four
// themes, against the thresholds of docs/design/dark_mode.md section 5
// (4.5 for text, 3.0 for hints). A pair below its threshold fails unless it
// is a known exception listed here by name, with its reason and the floor
// it must not fall under.
void main() {
  const thresholds = {
    'textStrong': 4.5, 'textPrimary': 4.5, 'textSecondary': 4.5, 'textSoft': 4.5, 'textMuted': 4.5,
    'textHint': 3.0, 'textDisabled': 4.5, 'primary': 4.5, 'primaryNote': 4.5, 'brandTeal': 4.5,
    'successStrong': 4.5, 'dangerStrong': 4.5, 'dangerDeep': 4.5, 'warningStrong': 4.5, 'warningDeep': 4.5,
    'infoStrong': 4.5, 'infoDeep': 4.5, 'infoNoteText': 4.5, 'infoNoteTextSoft': 4.5, 'warningBannerText': 4.5,
    'dangerLabel': 4.5, 'roleOwnerStrong': 4.5, 'roleCoAdminStrong': 4.5, 'roleAssistantStrong': 4.5,
  };

  Map<String, Color> textRoles(AppColors c) => {
        'textStrong': c.textStrong, 'textPrimary': c.textPrimary, 'textSecondary': c.textSecondary,
        'textSoft': c.textSoft, 'textMuted': c.textMuted, 'textHint': c.textHint, 'textDisabled': c.textDisabled,
        'primary': c.primary, 'primaryNote': c.primaryNote, 'brandTeal': c.brandTeal,
        'successStrong': c.successStrong, 'dangerStrong': c.dangerStrong, 'dangerDeep': c.dangerDeep,
        'warningStrong': c.warningStrong, 'warningDeep': c.warningDeep, 'infoStrong': c.infoStrong,
        'infoDeep': c.infoDeep, 'infoNoteText': c.infoNoteText, 'infoNoteTextSoft': c.infoNoteTextSoft,
        'warningBannerText': c.warningBannerText, 'dangerLabel': c.dangerLabel,
        'roleOwnerStrong': c.roleOwnerStrong, 'roleCoAdminStrong': c.roleCoAdminStrong,
        'roleAssistantStrong': c.roleAssistantStrong,
      };

  Map<String, Color> surfaceRoles(AppColors c) =>
      {'surface': c.surface, 'surfaceMuted': c.surfaceMuted, 'background': c.background, 'raisedSurface': c.raisedSurface};

  // Known exceptions: "role on surface" -> (floor = the lowest ratio
  // computed in the four themes minus 0.2, as section 5 holds them; reason).
  // Lowest computed: textDisabled 3.50 on surface and raisedSurface, 3.34 on
  // surfaceMuted, 3.57 on background; brandTeal 3.90 on surfaceMuted.
  const exceptions = <String, (double, String)>{
    // Disabled controls are exempt in WCAG; light is 1.88 (section 5).
    'textDisabled on surface': (3.30, 'disabled controls, WCAG exempt'),
    'textDisabled on surfaceMuted': (3.14, 'disabled controls, WCAG exempt'),
    'textDisabled on background': (3.37, 'disabled controls, WCAG exempt'),
    'textDisabled on raisedSurface': (3.30, 'disabled controls, WCAG exempt'),
    // brandTeal is lifted to 4.5 on surface, where its uses sit (links on
    // the login card, Total Products, the operator badge), not on the
    // lighter surfaceMuted (section 3).
    'brandTeal on surfaceMuted': (3.70, 'lifted on surface, where it is used'),
  };

  for (final theme in AppColorTheme.all) {
    test('${theme.id}: every text role on every surface role in dark', () {
      final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
      final failures = <String>[];
      for (final t in textRoles(c).entries) {
        for (final s in surfaceRoles(c).entries) {
          final name = '${t.key} on ${s.key}';
          final ratio = ColorMath.contrast(t.value, s.value);
          final known = exceptions[name];
          if (known != null) {
            if (ratio < known.$1) failures.add('$name ${ratio.toStringAsFixed(2)} < floor ${known.$1} (${known.$2})');
          } else if (ratio < thresholds[t.key]!) {
            failures.add('$name ${ratio.toStringAsFixed(2)} < ${thresholds[t.key]}');
          }
        }
      }
      expect(failures, isEmpty, reason: theme.id);
    });
  }

  test('every text role has a threshold, and every exception names a real pair', () {
    final c = AppColors.fromTheme(AppColorTheme.pasture, brightness: Brightness.dark);
    expect(textRoles(c).keys.toSet(), thresholds.keys.toSet());
    final pairs = {for (final t in textRoles(c).keys) for (final s in surfaceRoles(c).keys) '$t on $s'};
    expect(pairs.containsAll(exceptions.keys), isTrue);
  });
}
