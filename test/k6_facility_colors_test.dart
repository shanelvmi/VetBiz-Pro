import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/screens/facilities/select_facility_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K6: the Select Facility screen and the facility picker in Dark (ledger
// LATER (8)). Light must not change by a single value in any theme.
void main() {
  Color tint(Color c, double a, Color over) => ColorMath.composite(c.withValues(alpha: a), over);

  group('K6: the new roles in light are exactly what the screens used', () {
    for (final theme in AppColorTheme.all) {
      test(theme.id, () {
        final c = AppColors.fromTheme(theme);
        expect(AppColors.fromTheme(theme, brightness: Brightness.light).selectedCardFill, c.selectedCardFill);
        // Select Facility: accent 30%, primary ink and border.
        expect(c.selectedCardFill, c.accent.withValues(alpha: AppAlpha.a30));
        expect(c.selectedCardFill, theme.accent.withValues(alpha: AppAlpha.a30));
        expect(c.selectableCardInk, c.primary);
        expect(c.selectableCardInk, theme.primary);
        // Picker type chips: the label was the type colour itself.
        expect(c.infoChipLabel, c.info);
        expect(c.chart4ChipLabel, c.chart4);
        expect(c.chart4ChipLabel, Colors.purple);
        // The Select Facility bar and the picker header.
        expect(c.brandSurface, c.primary);
        expect(c.onBrandInk, c.background);
        expect(c.onBrandSurface, c.onPrimary);
        expect(c.onBrandSurface, c.surface);
        expect(c.onBrandSurfaceMuted, c.onPrimaryMuted);
      });
    }
  });

  group('K6: the new roles in dark', () {
    // Before K6, measured with the roles the screens used then.
    const before = {
      'pasture': (2.99, 2.55, 4.16),
      'clinic': (2.98, 2.57, 4.04),
      'harvest': (3.07, 2.63, 4.09),
      'ledger': (3.21, 2.74, 4.03),
    };
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: the Select Facility card', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        final oldFill = tint(c.accent, AppAlpha.a30, c.background);
        final (oldName, oldType, oldUnselectedType) = before[theme.id]!;
        expect(ColorMath.contrast(c.primary, oldFill), closeTo(oldName, 0.01));
        expect(ColorMath.contrast(c.primary.withValues(alpha: AppAlpha.a85), oldFill), closeTo(oldType, 0.01));
        expect(ColorMath.contrast(c.primary.withValues(alpha: AppAlpha.a85), c.surface), closeTo(oldUnselectedType, 0.01));

        expect(c.selectedCardFill, c.quickActionTintAccent);
        expect(c.selectedCardFill.a, 1.0);
        for (final fill in [c.selectedCardFill, c.surface]) {
          expect(ColorMath.contrast(c.selectableCardInk, fill), greaterThanOrEqualTo(4.5));
          expect(ColorMath.contrast(c.selectableCardInk.withValues(alpha: AppAlpha.a85), fill), greaterThanOrEqualTo(4.5));
        }
        // The selected border shows the state against the page and the fill.
        expect(ColorMath.contrast(c.selectableCardInk, c.background), greaterThanOrEqualTo(3.0));
        expect(ColorMath.contrast(c.selectableCardInk, c.selectedCardFill), greaterThanOrEqualTo(3.0));
        // Still the theme's hue.
        expect(HSLColor.fromColor(c.selectableCardInk).hue, closeTo(HSLColor.fromColor(c.primary).hue, 1.0));
        // The bar and the Proceed button.
        expect(ColorMath.contrast(c.onBrandInk, c.brandSurface), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.background, c.primary), greaterThanOrEqualTo(4.5));
      });

      test('${theme.id}: the facility picker', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
        final defaultCard = tint(c.primary, AppAlpha.a05, c.surface);
        for (final card in [c.surface, defaultCard]) {
          for (final (mark, label) in [(c.success, c.success), (c.info, c.infoChipLabel), (c.chart4, c.chart4ChipLabel)]) {
            expect(ColorMath.contrast(label, tint(mark, AppAlpha.a10, card)), greaterThanOrEqualTo(4.5));
          }
          expect(ColorMath.contrast(c.textMuted, card), greaterThanOrEqualTo(4.5));
        }
        // Before K6 the Other chip (chart4) measured 3.08 to 3.47.
        expect(ColorMath.contrast(c.chart4, tint(c.chart4, AppAlpha.a10, c.surface)), lessThan(4.5));
        // Header on brandSurface: name, tagline, account; the logo plate.
        expect(ColorMath.contrast(c.onBrandSurface, c.brandSurface), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.onBrandSurfaceMuted, c.brandSurface), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.brandSurface, c.onBrandSurface), greaterThanOrEqualTo(4.5));
        // Title, intro and footer on the page.
        expect(ColorMath.contrast(c.primary, c.surfaceMuted), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.textMuted, c.surfaceMuted), greaterThanOrEqualTo(4.5));
        expect(ColorMath.contrast(c.textHint, c.surfaceMuted), greaterThanOrEqualTo(3.0));
      });

      test('${theme.id}: copyWith() and lerp(..., 0) keep the K6 roles', () {
        for (final brightness in Brightness.values) {
          final c = AppColors.fromTheme(theme, brightness: brightness);
          final other = AppColors.fromTheme(AppColorTheme.ledger);
          for (final copy in [c.copyWith(), c.lerp(other, 0)]) {
            expect(copy.selectedCardFill.toARGB32(), c.selectedCardFill.toARGB32());
            expect(copy.selectableCardInk.toARGB32(), c.selectableCardInk.toARGB32());
            expect(copy.infoChipLabel.toARGB32(), c.infoChipLabel.toARGB32());
            expect(copy.chart4ChipLabel.toARGB32(), c.chart4ChipLabel.toARGB32());
          }
        }
      });
    }
  });

  group('K6: both screens built in Dark, text on its fill reaches 4.5', () {
    // The fill a widget is drawn on: every DecoratedBox and Material colour
    // above it, composited from the outermost opaque one inwards.
    Color fillBehind(WidgetTester tester, Finder finder) {
      final fills = <Color>[];
      tester.element(finder).visitAncestorElements((e) {
        final w = e.widget;
        Color? fill;
        if (w is DecoratedBox && w.decoration is BoxDecoration) fill = (w.decoration as BoxDecoration).color;
        if (w is Material && w.type != MaterialType.transparency) fill = w.color;
        if (fill != null && fill.a > 0) fills.add(fill);
        return fill == null || fill.a < 1;
      });
      var result = fills.removeLast();
      for (final f in fills.reversed) {
        result = ColorMath.composite(f, result);
      }
      return result;
    }

    Color inkOf(WidgetTester tester, Finder finder) =>
        tester.renderObject<RenderParagraph>(find.descendant(of: finder, matching: find.byType(RichText)).first).text.style!.color!;

    void expectReadable(WidgetTester tester, String text) {
      final finder = find.text(text).first;
      final ratio = ColorMath.contrast(inkOf(tester, finder), fillBehind(tester, finder));
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '"$text" measured ${ratio.toStringAsFixed(2)}');
    }

    Widget app(AppColorTheme theme, Widget Function() screen, {Object? arguments}) => MaterialApp(
          theme: AppTheme.build(theme, Brightness.light),
          darkTheme: AppTheme.build(theme, Brightness.dark),
          themeMode: ThemeMode.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => screen(),
            settings: RouteSettings(name: settings.name, arguments: arguments),
          ),
        );

    final facilities = [
      {'facilityId': 'f1', 'facilityName': 'Mlimani Agrovet', 'facilityType': 'Agrovet'},
      {'facilityId': 'f2', 'facilityName': 'Moshi Vet Centre', 'facilityType': 'Vet Clinic'},
      {'facilityId': 'f3', 'facilityName': 'Arusha Lab', 'facilityType': 'Lab'},
    ];

    for (final theme in AppColorTheme.all) {
      testWidgets('${theme.id}: Select Facility, unselected and selected', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(theme, () => const SelectFacilityScreen(), arguments: {'facilities': facilities, 'role': 'admin'}));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(tester.element(find.byType(SelectFacilityScreen)))!;
        for (final f in facilities) {
          expectReadable(tester, f['facilityName']!);
          expectReadable(tester, l10n.facilityTypeLabel(f['facilityType']!));
        }
        expectReadable(tester, l10n.selectFacility_clickToSelect);
        expectReadable(tester, l10n.selectFacility_title);

        await tester.tap(find.text('Moshi Vet Centre'));
        await tester.pumpAndSettle();
        expect(fillBehind(tester, find.text('Moshi Vet Centre')),
            AppColors.fromTheme(theme, brightness: Brightness.dark).selectedCardFill);
        expectReadable(tester, 'Moshi Vet Centre');
        expectReadable(tester, l10n.facilityTypeLabel('Vet Clinic'));
        expectReadable(tester, l10n.selectFacility_selected);
        expectReadable(tester, l10n.selectFacility_proceed);
      });

      testWidgets('${theme.id}: the facility picker', (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // No Firebase app in tests: the enrichment fetch fails, which the
        // screen treats as non-fatal (name and type per card).
        await tester.pumpWidget(app(theme, () => FacilityPickerScreen(facilities: facilities, role: 'admin')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final l10n = AppLocalizations.of(tester.element(find.byType(FacilityPickerScreen)))!;
        for (final f in facilities) {
          expectReadable(tester, f['facilityName']!);
          expectReadable(tester, l10n.facilityTypeLabel(f['facilityType']!));
        }
        expectReadable(tester, l10n.facilityPicker_title);
        expectReadable(tester, l10n.facilityPicker_intro);
        expectReadable(tester, l10n.facilityPicker_tagline);
        expectReadable(tester, l10n.facilityPicker_openFacility);
        expectReadable(tester, l10n.facilityPicker_locationNotSet);
      });
    }
  });
}
