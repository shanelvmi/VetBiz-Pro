import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

/// RW2a: pumps [child] in the app's theme and texts at a window [size], the
/// way the wizard widgets sit inside the auth card (on `surface`).
Future<void> pumpWizard(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppColorTheme theme = AppColorTheme.pasture,
  Locale locale = const Locale('en'),
  double keyboard = 0,
  bool scaffoldBar = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.build(theme, brightness),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    darkTheme: AppTheme.build(theme, Brightness.dark),
    home: scaffoldBar
        ? Scaffold(body: const SizedBox.expand(), bottomNavigationBar: child)
        : Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pump();
}
