import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_consent_row.dart';

// G4: every plain clickable text on Login and Register is the shared
// HoverLink; the hand-written hover code is gone. Written before the switch:
// run against the old screens, each test fails (no HoverLink, the old code).
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues({});
    final ui = (await tester.runAsync(() async {
      final p = UiSettingsProvider();
      while (!p.loaded) {
        await Future<void>.delayed(Duration.zero);
      }
      return p;
    }))!;
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ui,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        home: home,
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  bool isHoverLink(WidgetTester tester, String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(HoverLink)).evaluate().isNotEmpty;

  testWidgets('Login: Forgot password and Register are HoverLinks', (tester) async {
    await pump(tester, LoginScreen(authService: _NoAuth(), firestore: FakeFirebaseFirestore()));
    expect(isHoverLink(tester, _en.login_forgotPassword), isTrue);
    expect(isHoverLink(tester, _en.login_register), isTrue);
  }, skip: _skip);

  testWidgets('Register: the terms line names are HoverLinks', (tester) async {
    await pump(tester, RegisterScreen(firestore: FakeFirebaseFirestore()));
    final links = find.descendant(of: find.byType(HoverLink), matching: find.byType(Text));
    final labels = tester.widgetList<Text>(links).map((t) => t.data).toSet();
    expect(labels, containsAll([_en.common_termsOfService, _en.common_privacyPolicy]));
  }, skip: _skip);

  testWidgets('WizardConsentRow: its names are HoverLinks, underlined at rest', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(
        body: WizardConsentRow(
          onChanged: (_) {},
          text: 'I agree to the Terms of Service and the Privacy Policy.',
          links: [
            WizardLink(label: 'Terms of Service', onTap: () {}),
            WizardLink(label: 'Privacy Policy', onTap: () {}),
          ],
        ),
      ),
    ));
    expect(tester.widgetList<HoverLink>(find.byType(HoverLink)).map((l) => (l.label, l.underlineAtRest)),
        [('Terms of Service', true), ('Privacy Policy', true)]);
  }, skip: _skip);

  test('the hand-written hover code is gone', () {
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final register = File('lib/screens/register_screen.dart').readAsStringSync();
    final consent = File('lib/widgets/wizard/wizard_consent_row.dart').readAsStringSync();
    expect(login, isNot(contains('isForgotHovered')));
    expect(login, isNot(contains('isRegisterHovered')));
    expect(register, isNot(contains('_LegalLink')));
    expect(consent, isNot(contains('TapGestureRecognizer')));
  }, skip: _skip);
}
