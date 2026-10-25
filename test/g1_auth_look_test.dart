import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/ui_theme_mode.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_background.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';

// G1 (the owner's gap list: the auth look). Written before the code:
// (1) a person who has not chosen gets System; a saved Light or Dark is kept;
// (2) Login and Register sit on a flat theme colour: no image, no poster read;
// (3) the header's sun/moon is a real button that saves Light or Dark;
// (4) Login and Register share one card: the same width at 1200 and 390;
// and neither overflows at 360 or 390, in Light or Dark.

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

enum _Screen { login, register }

// Each group is switched on by the commit that implements it.
const _untilG1 = 'G1: until the implementation';

void main() {
  Future<UiSettingsProvider> loaded(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }

  // Inside a widget test the clock is fake: the saved settings are read for real.
  Future<UiSettingsProvider> settingsIn(WidgetTester tester, Map<String, Object> saved) async =>
      (await tester.runAsync(() => loaded(saved)))!;
  Future<String?> savedMode(WidgetTester tester) async =>
      tester.runAsync<String?>(() async => (await SharedPreferences.getInstance()).getString('ui_theme_mode'));

  Widget screenOf(_Screen s) => switch (s) {
        _Screen.login => LoginScreen(authService: _NoAuth(), firestore: FakeFirebaseFirestore()),
        _Screen.register => RegisterScreen(firestore: FakeFirebaseFirestore()),
      };

  Widget app(UiSettingsProvider ui, Widget home) => ChangeNotifierProvider.value(
        value: ui,
        child: Consumer<UiSettingsProvider>(
          builder: (_, s, __) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: s.locale,
            theme: AppTheme.build(s.colorTheme, Brightness.light),
            darkTheme: AppTheme.build(s.colorTheme, Brightness.dark),
            themeMode: s.themeMode.themeMode,
            home: home,
          ),
        ),
      );

  Future<void> pump(WidgetTester tester, UiSettingsProvider ui, _Screen s,
      {Size size = const Size(1200, 900), Brightness platform = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(app(ui, screenOf(s)));
    await tester.pump();
  }

  // Ends with every timer the screens started run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  AppColors colorsAt(WidgetTester tester, Finder f) => Theme.of(tester.element(f)).extension<AppColors>()!;

  group('(1) the default mode is System; a saved choice is kept', () {
    test('defaultMode is System', () {
      expect(UiThemeMode.defaultMode, UiThemeMode.system);
    });
    test('missing or unknown reads as System', () async {
      expect((await loaded({})).themeMode, UiThemeMode.system);
      expect((await loaded({'ui_theme_mode': 'midnight'})).themeMode, UiThemeMode.system);
    });
    test('a saved Light or Dark is kept', () async {
      expect((await loaded({'ui_theme_mode': 'light'})).themeMode, UiThemeMode.light);
      expect((await loaded({'ui_theme_mode': 'dark'})).themeMode, UiThemeMode.dark);
    });
  });

  group('(2) flat backgrounds', () {
    for (final s in _Screen.values) {
      for (final b in Brightness.values) {
        testWidgets('${s.name} in ${b.name}: no Image, the background role', (tester) async {
          final ui = await settingsIn(tester, {'ui_theme_mode': b == Brightness.dark ? 'dark' : 'light'});
          await pump(tester, ui, s);
          expect(find.byType(Image), findsNothing);
          final bg = find.byType(AuthBackground);
          expect(bg, findsOneWidget);
          final box = tester.widget<ColoredBox>(find.descendant(of: bg, matching: find.byType(ColoredBox)).first);
          expect(box.color, colorsAt(tester, bg).background);
          await finish(tester);
        });
      }
    }

    test('no poster read, no photo, no bundled background left', () {
      for (final path in ['lib/screens/login_screen.dart', 'lib/screens/register_screen.dart', 'lib/widgets/auth_background.dart']) {
        final src = File(path).readAsStringSync();
        for (final banned in ['login_poster', 'Image.network', 'Image.asset', 'background.jpeg', 'photoScrim']) {
          expect(src.contains(banned), isFalse, reason: '$path still has $banned');
        }
      }
      expect(File('assets/background.jpeg').existsSync(), isFalse);
      expect(File('pubspec.yaml').readAsStringSync().contains('assets/background.jpeg'), isFalse);
      expect(File('lib/screens/platform_admin/announcements_tab.dart').readAsStringSync().contains('login_poster'), isFalse);
    });
  });

  group('(3) the theme toggle', () {
    for (final s in _Screen.values) {
      testWidgets('${s.name}: moon in Light -> Dark, survives a rebuild, sun -> Light', (tester) async {
        final ui = await settingsIn(tester, {});
        await pump(tester, ui, s);
        final toggle = find.byType(AuthThemeToggle);
        expect(toggle, findsOneWidget);
        expect(ui.themeMode, UiThemeMode.system);
        expect(find.descendant(of: toggle, matching: find.byIcon(Icons.dark_mode_outlined)), findsOneWidget);
        expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
        final button = find.descendant(of: toggle, matching: find.byType(IconButton));
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(ui.themeMode, UiThemeMode.dark);
        expect(await savedMode(tester), 'dark');
        expect(Theme.of(tester.element(toggle)).brightness, Brightness.dark);
        expect(find.descendant(of: toggle, matching: find.byIcon(Icons.light_mode_outlined)), findsOneWidget);
        expect(find.byTooltip('Switch to light mode'), findsOneWidget);

        // A fresh tree on the same saved settings: still dark.
        await tester.pumpWidget(const SizedBox());
        await pump(tester, await settingsIn(tester, {'ui_theme_mode': 'dark'}), s);
        expect(Theme.of(tester.element(find.byType(AuthThemeToggle))).brightness, Brightness.dark);
        await tester.tap(find.descendant(of: find.byType(AuthThemeToggle), matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(await savedMode(tester), 'light');
        expect(Theme.of(tester.element(find.byType(AuthThemeToggle))).brightness, Brightness.light);
        await finish(tester);
      });

      testWidgets('${s.name}: System on a dark device shows the sun and chooses Light', (tester) async {
        final ui = await settingsIn(tester, {});
        await pump(tester, ui, s, platform: Brightness.dark);
        final toggle = find.byType(AuthThemeToggle);
        expect(find.descendant(of: toggle, matching: find.byIcon(Icons.light_mode_outlined)), findsOneWidget);
        await tester.tap(find.descendant(of: toggle, matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(ui.themeMode, UiThemeMode.light);
        await finish(tester);
      });
    }
  }, skip: _untilG1);

  group('(4) one card, and no overflow', () {
    for (final width in [1200.0, 390.0]) {
      testWidgets('both cards are the same width at $width', (tester) async {
        final sizes = <double>[];
        for (final s in _Screen.values) {
          await pump(tester, await settingsIn(tester, {}), s, size: Size(width, 900));
          sizes.add(tester.getSize(find.byKey(AuthCard.surfaceKey)).width);
          await finish(tester);
        }
        expect(sizes[0], sizes[1]);
        // Phones: the full width minus the page margins.
        if (width == 390) expect(sizes[0], lessThan(width));
      });
    }

    for (final s in _Screen.values) {
      for (final width in [360.0, 390.0]) {
        for (final mode in ['light', 'dark']) {
          testWidgets('${s.name} at $width in $mode: no overflow', (tester) async {
            await pump(tester, await settingsIn(tester, {'ui_theme_mode': mode}), s, size: Size(width, 800));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await finish(tester);
          });
        }
      }
    }
  }, skip: _untilG1);
}
