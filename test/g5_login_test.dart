import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

// G5 (the owner's corrections after testing), the login card: "Forgot
// password?" at the far right of the Remember me line, and the Sign in
// button without the fixed arrow at its right edge. Written before the
// fixes, skipped until they exist.
const _skip = true;

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<AppLocalizations> pump(WidgetTester tester, {required Size size, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final ui =
        (await tester.runAsync(() async {
          final p = UiSettingsProvider();
          while (!p.loaded) {
            await Future<void>.delayed(Duration.zero);
          }
          return p;
        }))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ui,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
          home: LoginScreen(authService: _NoAuth(), firestore: FakeFirebaseFirestore()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return lookupAppLocalizations(locale);
  }

  group('Remember me and Forgot password', () {
    for (final (width, locale) in const [(1200.0, Locale('en')), (1200.0, Locale('sw')), (390.0, Locale('en')), (390.0, Locale('sw')), (360.0, Locale('sw'))]) {
      testWidgets('$width ${locale.languageCode}: Forgot password at the far right, or under Remember me', (tester) async {
        final l10n = await pump(tester, size: Size(width, 900), locale: locale);
        final remember = tester.getRect(find.text(l10n.login_rememberMe));
        final checkbox = tester.getRect(find.byType(Checkbox));
        final forgot = tester.getRect(find.ancestor(of: find.text(l10n.login_forgotPassword), matching: find.byType(HoverLink)));
        // The password field spans the card's content: the line's width.
        final field = tester.getRect(find.byWidgetPredicate((w) => w is TextField && w.obscureText));
        final oneLine = forgot.top < remember.bottom;
        if (oneLine) {
          expect(forgot.right, closeTo(field.right, 1), reason: 'at the far right');
          expect(forgot.left - remember.right, greaterThanOrEqualTo(AppSpacing.s16), reason: 'the gap');
        } else {
          // The fallback: under Remember me, at the left.
          expect(forgot.top, greaterThanOrEqualTo(checkbox.bottom));
          expect(forgot.left, closeTo(field.left, 1));
        }
        if (width == 1200) expect(oneLine, isTrue, reason: 'room for both on a wide card');
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }
  });

  group('the Sign in button', () {
    testWidgets('only the sliding circled arrow; no fixed arrow at the right', (tester) async {
      final l10n = await pump(tester, size: const Size(1200, 900));
      final button = find.ancestor(of: find.text(l10n.login_loginButton), matching: find.byType(MouseRegion)).first;
      final arrows = find.descendant(of: button, matching: find.byIcon(Icons.arrow_forward));
      expect(arrows, findsOneWidget);
      // The one left is the circled one.
      final circle = tester.widget<Container>(find.ancestor(of: arrows, matching: find.byType(Container)).first);
      expect((circle.decoration! as BoxDecoration).shape, BoxShape.circle);
    }, skip: _skip);
  });
}
