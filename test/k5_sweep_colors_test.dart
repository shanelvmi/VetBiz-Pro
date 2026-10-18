import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

// K5 (5): the sweep of the raw colours left on themed screens (the R1
// allowlist). The operator's user status chips (were KEEP A23, A24) get
// roles; the four remaining KEEP colours are shown to read in dark.
void main() {
  Future<Color> chipInk(WidgetTester tester, AppColorTheme theme, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(theme, Brightness.light),
      darkTheme: AppTheme.build(theme, Brightness.dark),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: const Scaffold(body: Chip(label: Text('Awaiting Approval'))),
    ));
    return DefaultTextStyle.of(tester.element(find.text('Awaiting Approval'))).style.color!;
  }

  for (final theme in AppColorTheme.all) {
    test('${theme.id}: light status chip fills are exactly blue 100 and orange 100', () {
      final c = AppColors.fromTheme(theme);
      expect(c.statusPendingFill, Colors.blue.shade100);
      expect(c.statusOtherFill, Colors.orange.shade100);
      expect(c.statusPendingFill.toARGB32(), 0xFFBBDEFB);
      expect(c.statusOtherFill.toARGB32(), 0xFFFFE0B2);
    });

    testWidgets('${theme.id}: the chip label reads on the status fills in dark', (tester) async {
      final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
      expect(c.statusPendingFill.toARGB32(), 0xFF162B3B);
      expect(c.statusOtherFill.toARGB32(), 0xFF3B2C16);
      final ink = await chipInk(tester, theme, Brightness.dark);
      for (final fill in [c.statusPendingFill, c.statusOtherFill]) {
        expect(ColorMath.contrast(ink, fill), greaterThanOrEqualTo(4.5));
      }
      // The light fills under the dark chip text, before K5: 1.21 to 1.35.
      expect(ColorMath.contrast(ink, Colors.blue.shade100), lessThan(1.5));
      expect(ColorMath.contrast(ink, Colors.orange.shade100), lessThan(1.5));
    });

    testWidgets('${theme.id}: in light the chip label still reads as before', (tester) async {
      final c = AppColors.fromTheme(theme);
      final ink = await chipInk(tester, theme, Brightness.light);
      for (final fill in [c.statusPendingFill, c.statusOtherFill]) {
        expect(ColorMath.contrast(ink, fill), greaterThanOrEqualTo(4.5));
      }
    });

    test('${theme.id}: the KEEP colours read in dark (no change needed)', () {
      final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
      // A4 empty-team icon (teal 300) on the page.
      expect(ColorMath.contrast(Colors.teal.shade300, c.background), greaterThanOrEqualTo(3.0));
      // A9 the bell's blinking dot (redAccent) on the header.
      expect(ColorMath.contrast(Colors.redAccent, c.surface), greaterThanOrEqualTo(3.0));
      // A18 the debt category amber: icon, left border and chip on cards.
      for (final bg in [c.surface, c.surfaceMuted, c.background]) {
        expect(ColorMath.contrast(const Color(0xFFE59A00), bg), greaterThanOrEqualTo(3.0));
      }
      // A20 the System Online dot (greenAccent) on the brand footer.
      expect(ColorMath.contrast(Colors.greenAccent, c.brandSurface), greaterThanOrEqualTo(3.0));
    });

    test('${theme.id}: copyWith() and lerp(..., 0) keep the status fills', () {
      for (final brightness in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: brightness);
        for (final copy in [c.copyWith(), c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0)]) {
          expect(copy.statusPendingFill, c.statusPendingFill);
          expect(copy.statusOtherFill, c.statusOtherFill);
        }
      }
    });
  }
}
