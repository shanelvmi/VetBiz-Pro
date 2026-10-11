import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/config/app_defaults.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';

/// Step 2F-0: the language setting and the plumbing behind it. The checks on
/// the texts themselves (both files complete, placeholders match) are in
/// l10n_test.dart from step 2F-1.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    L10n.setLocale(const Locale(AppDefaults.defaultLanguage));
  });

  /// A provider that has finished reading its saved settings.
  Future<UiSettingsProvider> loaded() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }

  testWidgets('switching the language changes the text a widget shows', (tester) async {
    final ui = UiSettingsProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: Consumer<UiSettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: s.locale,
          home: Builder(builder: (context) => Text(context.l10n.common_language)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await ui.setLocale('sw');
    await tester.pumpAndSettle();
    expect(find.text('Lugha'), findsOneWidget);
  });

  test('L10n.current follows the provider, and is moved before listeners hear', () async {
    final ui = await loaded();
    expect(L10n.current.common_language, 'Language');

    String? seenByListener;
    ui.addListener(() => seenByListener = L10n.current.common_language);
    await ui.setLocale('sw');
    expect(seenByListener, 'Lugha');
    expect(L10n.current.common_language, 'Lugha');

    await ui.setLocale('en');
    expect(L10n.current.common_language, 'Language');
  });

  test('the chosen language survives a restart', () async {
    final before = await loaded();
    await before.setLocale('sw');

    L10n.setLocale(const Locale(AppDefaults.defaultLanguage)); // a fresh start
    final after = await loaded();
    expect(after.languageCode, 'sw');
    expect(L10n.current.common_language, 'Lugha');
  });

  test('an unsupported saved language falls back to English', () async {
    SharedPreferences.setMockInitialValues({'ui_language': 'fr'});
    final ui = await loaded();
    expect(ui.languageCode, 'en');
    expect(L10n.current.common_language, 'Language');

    await ui.setLocale('fr'); // and can't be chosen either
    expect(ui.languageCode, 'en');
  });

  test('every supported language has an ARB file, and every ARB file is supported', () {
    final arbCodes = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.uri.pathSegments.last)?.group(1))
        .whereType<String>()
        .toSet();
    expect(arbCodes, AppDefaults.supportedLanguages.toSet());
    expect(AppDefaults.languageNames.keys.toSet(), AppDefaults.supportedLanguages.toSet());
    expect(AppDefaults.supportedLanguages, contains(AppDefaults.defaultLanguage));
  });
}
