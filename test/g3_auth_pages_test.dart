import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';

// G3: the login page without the clutter, and the footer below the card on
// the sign-in pages. Written before the change (4c40bc8).

final _en = lookupAppLocalizations(const Locale('en'));

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The fake database, counting how often app_config is opened.
class _CountingFirestore implements FirebaseFirestore {
  _CountingFirestore(this.inner);

  final FakeFirebaseFirestore inner;
  int appConfigReads = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == Collections.appConfig) appConfigReads++;
    return inner.collection(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1200, 900),
    ThemeMode mode = ThemeMode.light,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        darkTheme: AppTheme.build(AppColorTheme.pasture, Brightness.dark),
        themeMode: mode,
        home: page,
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Widget login([FirebaseFirestore? db]) => LoginScreen(authService: _NoAuth(), firestore: db ?? FakeFirebaseFirestore());

  group('Login page', () {
    testWidgets('the removed texts are gone; the heading is one line', (tester) async {
      await pump(tester, login());
      for (final gone in const [
        'System Online',
        'Smart Business & Vet Services Monitor',
        'Welcome to',
        'Stay updated with the latest news and announcements.',
        'Secure. Reliable. Always Connected.',
        'Your trusted partner in animal health and business growth.',
        'Sign in to your facility',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.text(_en.login_welcomeBack), findsOneWidget);
    });

    testWidgets('keeps the announcements, Remember me, Forgot password and Create an account', (tester) async {
      await pump(tester, login());
      expect(find.text(_en.login_announcements), findsOneWidget);
      expect(find.text(_en.login_rememberMe), findsOneWidget);
      expect(find.text(_en.login_forgotPassword), findsOneWidget);
      expect(find.textContaining(_en.login_register, findRichText: true), findsOneWidget);
    });

    testWidgets('the footer sits below the card, full width', (tester) async {
      await pump(tester, login());
      final card = tester.getRect(find.byKey(AuthCard.surfaceKey));
      final footer = tester.getRect(find.byType(AuthFooter));
      expect(footer.top, greaterThanOrEqualTo(card.bottom));
      expect(footer.width, 1200);
    });

    testWidgets('reads the support contact once, whatever rebuilds', (tester) async {
      final db = _CountingFirestore(FakeFirebaseFirestore());
      await pump(tester, login(db));
      tester.view.physicalSize = const Size(390, 800);
      await tester.pump();
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      await tester.tap(find.byType(AuthThemeToggle));
      await tester.pump();
      expect(db.appConfigReads, 1);
    });

    for (final width in [360.0, 390.0, 768.0, 1200.0]) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in const [Locale('en'), Locale('sw')]) {
          testWidgets('no overflow at $width, ${mode.name}, ${locale.languageCode}', (tester) async {
            await pump(tester, login(), size: Size(width, 900), mode: mode, locale: locale);
            expect(tester.takeException(), isNull);
            expect(find.byType(AuthFooter), findsOneWidget);
          });
        }
      }
    }
  });
}
