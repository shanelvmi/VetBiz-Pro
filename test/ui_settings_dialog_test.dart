import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/ui_theme_mode.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/settings/ui_settings_dialog.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

/// T1 (docs/design/themes.md section 10.6): the UI Settings dialog offers
/// the four themes, all selectable, and choosing one rebuilds the app in it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('four selectable themes; choosing one rebuilds the app', (tester) async {
    final ui = UiSettingsProvider();
    late BuildContext appContext;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: Consumer<UiSettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: s.locale,
          theme: AppTheme.build(s.colorTheme, Brightness.light),
          home: Builder(builder: (context) {
            appContext = context;
            return const Scaffold();
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    Color primary() => Theme.of(appContext).extension<AppColors>()!.primary;
    expect(primary(), AppColorTheme.pasture.primary);

    showUiSettingsDialog(appContext);
    await tester.pumpAndSettle();
    for (final name in ['Pasture', 'Clinic', 'Harvest', 'Ledger']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // Nothing is "Coming soon" any more (Dark Mode works since K1).
    expect(find.text('Coming soon'), findsNothing);

    for (final theme in [AppColorTheme.clinic, AppColorTheme.harvest, AppColorTheme.ledger, AppColorTheme.pasture]) {
      await tester.tap(find.text(theme.name));
      await tester.pumpAndSettle();
      expect(ui.colorTheme.id, theme.id);
      expect(primary(), theme.primary, reason: theme.id);
    }
  });

  testWidgets('the theme names are shown in Kiswahili', (tester) async {
    SharedPreferences.setMockInitialValues({'ui_language': 'sw'});
    final ui = UiSettingsProvider();
    late BuildContext appContext;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: Consumer<UiSettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: s.locale,
          theme: AppTheme.build(s.colorTheme, Brightness.light),
          home: Builder(builder: (context) {
            appContext = context;
            return const Scaffold();
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    showUiSettingsDialog(appContext);
    await tester.pumpAndSettle();
    final sw = lookupAppLocalizations(const Locale('sw'));
    for (final t in AppColorTheme.all) {
      expect(find.text(sw.colorThemeLabel(t.id)), findsOneWidget, reason: t.id);
    }
  });

  testWidgets('Dark Mode: System, Light, Dark; choosing Dark rebuilds the app dark', (tester) async {
    final ui = UiSettingsProvider();
    late BuildContext appContext;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: Consumer<UiSettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: s.locale,
          theme: AppTheme.build(s.colorTheme, Brightness.light),
          darkTheme: AppTheme.build(s.colorTheme, Brightness.dark),
          themeMode: s.themeMode.themeMode,
          home: Builder(builder: (context) {
            appContext = context;
            return const Scaffold();
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    AppColors colors() => Theme.of(appContext).extension<AppColors>()!;
    final light = AppColors.fromTheme(AppColorTheme.pasture);
    final dark = AppColors.fromTheme(AppColorTheme.pasture, brightness: Brightness.dark);
    // A fresh install: System (G1), on a light platform here.
    expect(ui.themeMode, UiThemeMode.system);
    expect(colors().surface, light.surface);

    showUiSettingsDialog(appContext);
    await tester.pumpAndSettle();
    for (final label in ['System', 'Light', 'Dark']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.widget<SegmentedButton<UiThemeMode>>(find.byType(SegmentedButton<UiThemeMode>)).selected,
        {UiThemeMode.system});

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(ui.themeMode, UiThemeMode.dark);
    expect(Theme.of(appContext).brightness, Brightness.dark);
    expect(colors().surface, dark.surface);
    expect(colors().primary, dark.primary);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(ui.themeMode, UiThemeMode.light);
    expect(colors().surface, light.surface);
    expect(colors().primary, light.primary);
  });
}
