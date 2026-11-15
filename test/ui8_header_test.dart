// UI8: the shared phone header of the signed-out pages (AuthPhoneHeader,
// AuthPhoneControls, AuthLanguageSwitch): the mark, the name and the
// tagline; EN | SW through UiSettingsProvider.setLocale; Light/Dark; Help;
// the one-line form when the keyboard is open; the roles it paints with.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/data/ui_theme_mode.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/auth_language_switch.dart';
import 'package:vetbiz_pro/widgets/auth_phone_header.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';

import 'helpers/real_font.dart';

const _tagline = 'A tagline';

Future<UiSettingsProvider> _pump(
  WidgetTester tester, {
  bool collapsed = false,
  VoidCallback? onHelp,
  Brightness brightness = Brightness.light,
  bool realFont = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final ui = (await tester.runAsync(() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }))!;
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: ui,
    child: Consumer<UiSettingsProvider>(
      builder: (context, ui, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: ui.locale,
        theme: _theme(brightness, realFont: realFont),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: AuthPhoneHeader(tagline: _tagline, collapsed: collapsed, onHelp: onHelp ?? () {}),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return ui;
}

ThemeData _theme(Brightness brightness, {required bool realFont}) {
  final t = AppTheme.build(AppColorTheme.pasture, brightness);
  return realFont ? t.copyWith(textTheme: t.textTheme.apply(fontFamily: realFontFamily)) : t;
}

AppColors _colors(WidgetTester tester) => tester.element(find.byType(AuthPhoneHeader)).colors;

void main() {
  setUpAll(loadRealFont);

  testWidgets('the mark in its tile, the name, the tagline and the three controls', (tester) async {
    await _pump(tester);
    expect(find.text(AppInfo.logoMark), findsOneWidget);
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.text(_tagline), findsOneWidget);
    expect(find.byType(AuthLanguageSwitch), findsOneWidget);
    expect(find.byType(AuthThemeToggle), findsOneWidget);
    expect(find.byKey(AuthPhoneControls.helpKey), findsOneWidget);
    expect(tester.getSize(find.byKey(AuthPhoneHeader.markKey)), const Size.square(AuthPhoneMetrics.markTile));
    // The controls sit at the header's right.
    final right = tester.getTopRight(find.byKey(AuthPhoneControls.helpKey)).dx;
    expect(right, greaterThan(360 - AuthPhoneMetrics.headerPaddingH - 1));
  });

  testWidgets('the roles: the tint, the mark tile, the selected language', (tester) async {
    for (final brightness in Brightness.values) {
      await _pump(tester, brightness: brightness);
      final c = _colors(tester);
      final tint = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(AuthPhoneTint), matching: find.byType(DecoratedBox)).first,
      );
      expect((tint.decoration as BoxDecoration).color, c.authFooterFill, reason: '$brightness');
      final mark = tester.widget<Container>(find.byKey(AuthPhoneHeader.markKey));
      expect((mark.decoration! as BoxDecoration).color, c.brandSurface, reason: '$brightness');
      expect(tester.widget<Text>(find.text(AppInfo.logoMark)).style!.color, c.onBrandSurface);
      expect(tester.widget<Text>(find.text('EN')).style!.color, c.onBrandSurface);
      expect(tester.widget<Text>(find.text('SW')).style!.color, c.textPrimary);
    }
  });

  testWidgets('EN | SW saves the language through setLocale and the page follows', (tester) async {
    final ui = await _pump(tester);
    expect(ui.languageCode, 'en');
    await tester.tap(find.byKey(AuthLanguageSwitch.segmentKey('sw')));
    await tester.pumpAndSettle();
    expect(ui.languageCode, 'sw');
    expect(tester.widget<Text>(find.text('SW')).style!.color, _colors(tester).onBrandSurface);
    await tester.tap(find.byKey(AuthLanguageSwitch.segmentKey('en')));
    await tester.pumpAndSettle();
    expect(ui.languageCode, 'en');
  });

  testWidgets('every control is a 48 px target', (tester) async {
    await _pump(tester);
    for (final code in ['en', 'sw']) {
      expect(tester.getSize(find.byKey(AuthLanguageSwitch.segmentKey(code))).height, kMinInteractiveDimension);
    }
    expect(tester.getSize(find.byKey(AuthPhoneControls.helpKey)), const Size.square(kMinInteractiveDimension));
    expect(tester.getSize(find.byType(AuthThemeToggle)), const Size.square(kMinInteractiveDimension));
  });

  testWidgets('Help calls back; Light/Dark switches the mode', (tester) async {
    var helped = 0;
    final ui = await _pump(tester, onHelp: () => helped++);
    await tester.tap(find.byKey(AuthPhoneControls.helpKey));
    expect(helped, 1);
    await tester.tap(find.byType(AuthThemeToggle));
    await tester.pump();
    expect(ui.themeMode, UiThemeMode.dark);
  });

  testWidgets('collapsed: one line, no tagline, the controls kept, the name whole at 360', (tester) async {
    await _pump(tester);
    final open = tester.getSize(find.byType(AuthPhoneHeader)).height;
    // In Roboto, as on a phone: the square test font is about twice as wide.
    await _pump(tester, collapsed: true, realFont: true);
    final closed = tester.getSize(find.byType(AuthPhoneHeader)).height;
    expect(find.text(_tagline), findsNothing);
    expect(find.byType(AuthPhoneControls), findsOneWidget);
    expect(tester.getSize(find.byKey(AuthPhoneHeader.markKey)), const Size.square(AuthPhoneMetrics.collapsedMark));
    expect(closed, lessThan(open / 2), reason: 'open $open, collapsed $closed');
    final name = tester.renderObject<RenderParagraph>(find.text(AppInfo.name));
    expect(name.didExceedMaxLines, isFalse);
  });
}
