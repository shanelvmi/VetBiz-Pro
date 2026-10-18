import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/announcement_message.dart';

// K5 (4): the Markdown quote box in an announcement message. Light keeps
// flutter_markdown's own fixed blue 100 box exactly; dark gets quoteFill.
void main() {
  Future<Decoration> quoteBox(WidgetTester tester, AppColorTheme theme, Brightness brightness, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(theme, Brightness.light),
      darkTheme: AppTheme.build(theme, Brightness.dark),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    ));
    final box = find.ancestor(of: find.text('quoted', findRichText: true), matching: find.byType(DecoratedBox)).first;
    return tester.widget<DecoratedBox>(box).decoration;
  }

  const message = {'message': '> quoted'};

  for (final theme in AppColorTheme.all) {
    test('${theme.id}: light quoteFill is the plugin default, blue 100', () {
      final c = AppColors.fromTheme(theme);
      final built = AppTheme.build(theme, Brightness.light);
      final plugin = MarkdownStyleSheet.fromTheme(ThemeData.localize(built, built.typography.englishLike)).blockquoteDecoration;
      expect(c.quoteFill, Colors.blue.shade100);
      expect(c.quoteFill.toARGB32(), 0xFFBBDEFB);
      expect(BoxDecoration(color: c.quoteFill, borderRadius: BorderRadius.circular(AppRadius.r2)), plugin);
    });

    testWidgets('${theme.id}: in light the announcement quote box is exactly the plugin default', (tester) async {
      final before = await quoteBox(tester, theme, Brightness.light, const MarkdownBody(data: '> quoted'));
      final after = await quoteBox(tester, theme, Brightness.light, const AnnouncementMessage(data: message));
      expect(after, before);
    });

    testWidgets('${theme.id}: in dark the quote text reads on quoteFill', (tester) async {
      final c = AppColors.fromTheme(theme, brightness: Brightness.dark);
      final light = AppColors.fromTheme(theme);
      final box = await quoteBox(tester, theme, Brightness.dark, const AnnouncementMessage(data: message));
      expect((box as BoxDecoration).color, c.quoteFill);
      expect(c.quoteFill.toARGB32(), 0xFF162B3B);
      final ink = AppTheme.build(theme, Brightness.dark).textTheme.bodyMedium!.color!;
      expect(ColorMath.contrast(ink, c.quoteFill), greaterThanOrEqualTo(4.5));
      // The plugin's blue under the dark theme's text, before K5.
      expect(ColorMath.contrast(ink, Colors.blue.shade100), lessThan(1.5));
      // A link in a quote reads at least as well as in light.
      expect(ColorMath.contrast(c.info, c.quoteFill), greaterThanOrEqualTo(ColorMath.contrast(light.info, light.quoteFill)));
    });

    test('${theme.id}: copyWith() and lerp(..., 0) keep quoteFill', () {
      for (final brightness in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: brightness);
        expect(c.copyWith().quoteFill, c.quoteFill);
        expect(c.lerp(AppColors.fromTheme(AppColorTheme.ledger), 0).quoteFill, c.quoteFill);
      }
    });
  }
}
