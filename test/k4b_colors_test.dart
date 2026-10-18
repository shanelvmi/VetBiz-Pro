import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K4b (docs/design/dark_mode.md section 8): sign-in and register, UI
// Settings, subscription, notifications, legal, the operator console and the
// K4a leftovers in Dark. Light must not change by a single value in any theme.
void main() {
  // Material's onSecondaryContainer for each theme seed, the label colour of
  // a selected ChoiceChip in light today.
  const chipInkLight = {'pasture': 0xFF324B4E, 'clinic': 0xFF3C4858, 'harvest': 0xFF5B4130, 'ledger': 0xFF3E4758};

  group('K4b: the new roles in light are exactly what the screens use today', () {
    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final c = AppColors.fromTheme(theme);
        expect(AppColors.fromTheme(theme, brightness: Brightness.light).dangerLabel, c.dangerLabel);
        // Login and register gradients, operator Go to Facility tile.
        expect(c.brandTealOnBrand, c.brandTeal);
        // The overlay on the sign-in photo: scrim at a20.
        expect(c.photoScrim, c.scrim.withValues(alpha: AppAlpha.a20));
        // Operator sidebar dividers.
        expect(c.onBrandSurfaceSubtle, c.onPrimarySubtle);
        expect(c.onBrandSurfaceSubtle, Colors.white24);
        // Activity log chips: Material's selected label and checkmark.
        expect(c.onAccentChip, AppTheme.build(theme, Brightness.light).colorScheme.onSecondaryContainer);
        expect(c.onAccentChip.toARGB32(), chipInkLight[theme.id]);
        // Was KEEP A21: Colors.redAccent[700].
        expect(c.dangerLabel, Colors.redAccent[700]);
        expect(c.dangerLabel.toARGB32(), 0xFFD50000);
      });
    }
  });

  group('K4b: the new roles in dark', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: values and contrast', () {
        final light = AppColors.fromTheme(theme);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        // brandSurface keeps its light value, so the teal on it does too.
        expect(c.brandTealOnBrand, light.brandTeal);
        expect(ColorMath.contrast(c.onBrandSurface, c.brandTealOnBrand),
            greaterThanOrEqualTo(ColorMath.contrast(light.onBrandSurface, light.brandTealOnBrand)));
        expect(c.photoScrim, Colors.black.withValues(alpha: AppAlpha.a50));
        expect(c.onBrandSurfaceSubtle, Colors.white24);
        expect(c.onAccentChip, c.onAccent);
        expect(ColorMath.contrast(c.onAccentChip, c.accent), greaterThanOrEqualTo(4.5));
        // Material's own selected label on the accent fill measured 1.39 to 1.96.
        final materialInk = AppTheme.build(theme, Brightness.dark).colorScheme.onSecondaryContainer;
        expect(ColorMath.contrast(materialInk, c.accent), lessThan(3.0));
        expect(c.dangerLabel.toARGB32(), 0xFFFF5B5B);
        for (final bg in [c.surface, c.surfaceMuted, c.background]) {
          expect(ColorMath.contrast(c.dangerLabel, bg), greaterThanOrEqualTo(4.5));
        }
        // On its card: the danger tint (dangerAccent 5%) over the surface.
        final tint = ColorMath.composite(c.dangerAccent.withValues(alpha: AppAlpha.a05), c.surface);
        expect(ColorMath.contrast(c.dangerLabel, tint), greaterThanOrEqualTo(4.5));
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep them', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          for (final copy in [c.copyWith(), c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0)]) {
            expect(copy.brandTealOnBrand, c.brandTealOnBrand);
            expect(copy.photoScrim, c.photoScrim);
            expect(copy.onBrandSurfaceSubtle, c.onBrandSurfaceSubtle);
            expect(copy.onAccentChip, c.onAccentChip);
            expect(copy.dangerLabel, c.dangerLabel);
          }
        }
      });

      test('${theme.id}: brand bars and their inks read in dark as in light', () {
        final light = AppColors.fromTheme(theme);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        // AppBars, sidebars, the login footer, the dropdown and report headers.
        expect(ColorMath.contrast(c.onBrandSurface, c.brandSurface), greaterThanOrEqualTo(4.5));
        // Muted labels and the sidebar divider keep their light contrast.
        double over(Color ink, AppColors r) => ColorMath.contrast(ColorMath.composite(ink, r.brandSurface), r.brandSurface);
        expect(over(c.onBrandSurfaceMuted, c), closeTo(over(light.onPrimaryMuted, light), 0.01));
        expect(over(c.onBrandSurfaceSubtle, c), closeTo(over(light.onPrimarySubtle, light), 0.01));
      });

      test('${theme.id}: UI Settings Light/Dark choice reads in dark (Material colours, no change)', () {
        final s = AppTheme.build(theme, Brightness.dark).colorScheme;
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        expect(ColorMath.contrast(s.onSecondaryContainer, s.secondaryContainer), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(s.onSurface, c.surface), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('K4b: the activity log chip draws the same ink in light', () {
    for (final theme in AppColorTheme.all) {
      testWidgets(theme.id, (tester) async {
        final c = AppColors.fromTheme(theme);
        Color? labelOf(String text) => DefaultTextStyle.of(tester.element(find.text(text))).style.color;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(theme, Brightness.light),
          home: Scaffold(
            body: Row(children: [
              ChoiceChip(label: const Text('before'), selected: true, onSelected: (_) {}, selectedColor: c.accent),
              ChoiceChip(
                label: const Text('after'),
                selected: true,
                onSelected: (_) {},
                selectedColor: c.accent,
                labelStyle: TextStyle(color: c.onAccentChip),
                checkmarkColor: c.onAccentChip,
              ),
              ChoiceChip(label: const Text('off'), selected: false, onSelected: (_) {}, selectedColor: c.accent),
            ]),
          ),
        ));
        expect(labelOf('after'), labelOf('before'));
        expect(labelOf('after'), c.onAccentChip);
        final before = tester.widget<RawChip>(find.ancestor(of: find.text('before'), matching: find.byType(RawChip)));
        expect(before.checkmarkColor, isNull);
        expect(labelOf('off'), isNot(c.onAccentChip));
      });
    }
  });
}
