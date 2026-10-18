import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/screens/dashboard/dashboard_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// K2 moved the dashboard's brand areas from primary/onPrimary to
// brandSurface/onBrandSurface, and the light ink on them to a dark-only
// switch. Light must not change by a single value in any theme.
void main() {
  group('K2: light is unchanged in every theme', () {
    for (final theme in AppColorTheme.all) {
      test('${theme.id}: brandSurface = primary, onBrandSurface = onPrimary, onAccent = textPrimary', () {
        final c = AppColors.fromTheme(theme, brightness: Brightness.light);
        expect(c.brandSurface, c.primary);
        expect(c.onBrandSurface, c.onPrimary);
        expect(c.onAccent, c.textPrimary);
      });
    }
  });

  group('K2: sidebar ink', () {
    Future<Color?> iconColor(WidgetTester tester, AppColorTheme theme, Brightness brightness) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(theme, brightness),
        home: Scaffold(
          body: SizedBox(width: 250, child: DrawerHoverItem(icon: Icons.store, title: 'x', onTap: () {})),
        ),
      ));
      await tester.pumpAndSettle();
      return tester.widget<Icon>(find.byIcon(Icons.store)).color;
    }

    for (final theme in AppColorTheme.all) {
      testWidgets('${theme.id}: light keeps background, dark uses onBrandSurface', (tester) async {
        final light = AppColors.fromTheme(theme, brightness: Brightness.light);
        final dark = AppColors.fromTheme(theme, brightness: Brightness.dark);
        expect(await iconColor(tester, theme, Brightness.light), light.background);
        expect(await iconColor(tester, theme, Brightness.dark), dark.onBrandSurface);
      });
    }
  });
}
