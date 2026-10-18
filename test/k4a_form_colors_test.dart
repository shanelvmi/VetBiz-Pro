import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';

// K4a (docs/design/dark_mode.md section 8): forms, dialogs and the toasts in
// Dark. Light must not change by a single value in any theme.
void main() {
  group('K4a: onBrandInk and onBrandSurfaceMuted (ink on the brand header bars)', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: light is exactly what the screens use today', () {
        final c = AppColors.fromTheme(theme);
        // Header bars move primary -> brandSurface and onPrimary -> onBrandSurface.
        expect(c.brandSurface, c.primary);
        expect(c.onBrandSurface, c.onPrimary);
        // Add Product's header and category dialogs draw the page colour on the brand fill.
        expect(c.onBrandInk, c.background);
        expect(c.onBrandInk, theme.background);
        // The Browse Products drag handle.
        expect(c.onBrandSurfaceMuted, c.onPrimaryMuted);
        expect(c.onBrandSurfaceMuted, Colors.white70);
        expect(AppColors.fromTheme(theme, brightness: Brightness.light).onBrandInk, c.onBrandInk);
      });

      test('${theme.id}: dark keeps the brand fill and reads at least as well as light', () {
        final light = AppColors.fromTheme(theme);
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        expect(c.onBrandInk, c.onBrandSurface);
        expect(c.onBrandSurfaceMuted, Colors.white70);
        final ink = ColorMath.contrast(c.onBrandInk, c.brandSurface);
        expect(ink, greaterThanOrEqualTo(4.5));
        expect(ink, greaterThanOrEqualTo(ColorMath.contrast(light.onBrandInk, light.brandSurface)));
        final muted = ColorMath.contrast(ColorMath.composite(c.onBrandSurfaceMuted, c.brandSurface), c.brandSurface);
        expect(muted, greaterThanOrEqualTo(3.0));
        // The 95% brand fill of the category dialogs, over the dark page.
        final dialogFill = ColorMath.composite(c.brandSurface.withValues(alpha: 0.95), c.background);
        expect(ColorMath.contrast(c.onBrandInk, dialogFill), greaterThanOrEqualTo(4.5));
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep them', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          for (final copy in [c.copyWith(), c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0)]) {
            expect(copy.onBrandInk, c.onBrandInk);
            expect(copy.onBrandSurfaceMuted, c.onBrandSurfaceMuted);
          }
        }
      });

      test('${theme.id}: dialogs on raisedSurface stand off the dimmed page in dark', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        // Material's default barrier: black 54% over the page.
        final dimmedPage = ColorMath.composite(Colors.black54, c.background);
        expect(ColorMath.luminance(c.raisedSurface), greaterThan(ColorMath.luminance(c.background)));
        expect(ColorMath.deltaE(c.raisedSurface, dimmedPage),
            greaterThan(ColorMath.deltaE(c.background, dimmedPage)));
        expect(AppColors.fromTheme(theme).raisedSurface, theme.background);
      });
    }
  });

  group('K4a: the toasts in dark', () {
    final kinds = <(String, void Function(), IconData)>[
      ('success', () => AppFeedback.success('S'), Icons.check),
      ('info', () => AppFeedback.info('I'), Icons.info_outline),
      ('warning', () => AppFeedback.warning('W'), Icons.warning_amber_rounded),
      ('error', () => AppFeedback.error('E', error: Exception('x')), Icons.error_outline),
      ('undo', () => AppFeedback.undo('U', onUndo: () {}), Icons.delete_outline),
    ];

    for (final theme in AppColorTheme.all) {
      testWidgets('${theme.id}: every type is readable and the four types stay distinguishable', (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          scaffoldMessengerKey: AppFeedback.messengerKey,
          theme: AppTheme.build(theme, Brightness.dark),
          home: const Scaffold(body: SizedBox.expand()),
        ));
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        final glyphs = <String, Color>{};
        for (final (name, show, glyph) in kinds) {
          show();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          final icon = tester.widget<Icon>(find.byIcon(glyph));
          final badge = tester.widget<Container>(find.ancestor(of: find.byIcon(glyph), matching: find.byType(Container)).first);
          final fill = ColorMath.composite((badge.decoration! as BoxDecoration).color!, c.surface);
          expect(ColorMath.contrast(icon.color!, fill), greaterThanOrEqualTo(3.0), reason: '$name glyph');
          final title = tester.widget<Text>(find.text(name[0].toUpperCase()));
          expect(ColorMath.contrast(ColorMath.composite(title.style!.color!, c.surface), c.surface),
              greaterThanOrEqualTo(4.5), reason: '$name title');
          glyphs[name] = icon.color!;
          await tester.pump(const Duration(seconds: 10));
          await tester.pumpAndSettle();
        }
        // The undo glyph is grey on purpose; the four coloured types must differ.
        final coloured = ['success', 'info', 'warning', 'error'];
        for (var i = 0; i < coloured.length; i++) {
          for (var j = i + 1; j < coloured.length; j++) {
            expect(ColorMath.deltaE(glyphs[coloured[i]]!, glyphs[coloured[j]]!), greaterThanOrEqualTo(10),
                reason: '${coloured[i]} vs ${coloured[j]}');
          }
        }
        // The action buttons (Retry, Undo) and Details on the card.
        expect(ColorMath.contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(ColorMath.composite(c.textSecondary, c.surface), c.surface), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
