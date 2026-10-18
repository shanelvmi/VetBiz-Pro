import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/vetbiz_loading_indicator.dart';

import 'helpers/color_roles.dart';

// The startup loading screen (main.dart, _AuthLoadingScreen) sits on the light
// AppPalette.background page in every mode, so under a Dark app theme the
// roles it reads must still be Pasture light, value for value.
void main() {
  final pastureLight = allColorRoles(AppColors.fromTheme(AppColorTheme.pasture));

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name} app: the loading screen sees Pasture light', (tester) async {
        late AppColors seen;
        late Brightness seenBrightness;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(theme, Brightness.light),
          darkTheme: AppTheme.build(theme, Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: VetBizLoadingTheme(builder: (context) {
            seen = context.colors;
            seenBrightness = Theme.of(context).brightness;
            return const SizedBox();
          }),
        ));
        expect(seenBrightness, Brightness.light);
        expect(Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary, AppColorTheme.pasture.primary);
        final got = allColorRoles(seen);
        for (final e in pastureLight.entries) {
          expect(got[e.key]!.toARGB32(), e.value.toARGB32(), reason: e.key);
        }
      });
    }
  }
}
