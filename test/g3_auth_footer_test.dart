import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/screens/legal/privacy_policy_screen.dart';
import 'package:vetbiz_pro/screens/legal/terms_of_service_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

import 'helpers/help_dialog_rows.dart';

// G3: the calm footer under the Login and Register cards. Written before the
// widget (39ff4b5).

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  final launched = <(Uri, LaunchMode)>[];
  Future<bool> fakeLaunch(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    launched.add((url, mode));
    return true;
  }

  setUp(launched.clear);

  Future<void> pump(
    WidgetTester tester,
    SupportContact contact, {
    Size size = const Size(1200, 900),
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(AppColorTheme.pasture, brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AuthFooter(store: SupportContactStore.seeded(contact), launcher: fakeLaunch),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<String> iconNames(WidgetTester tester) =>
      tester.widgetList<Tooltip>(find.ancestor(of: find.byType(FaIcon), matching: find.byType(Tooltip))).map((t) => t.message ?? '').toList();

  group('AuthFooter', () {
    testWidgets('wide: brand line, Support, Legal, copyright and version', (tester) async {
      await pump(tester, SupportContact.empty);
      for (final text in [
        AppInfo.name,
        _en.authFooter_support,
        _en.authFooter_helpContact,
        _en.authFooter_legal,
        _en.common_privacyPolicy,
        _en.common_termsOfService,
        _en.login_copyright(AppInfo.name),
        AppInfo.versionLabel,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Three columns side by side above AppBreakpoints.medium.
      final brand = tester.getTopLeft(find.text(AppInfo.name));
      final support = tester.getTopLeft(find.text(_en.authFooter_support));
      final legal = tester.getTopLeft(find.text(_en.authFooter_legal));
      expect(brand.dx < support.dx && support.dx < legal.dx, isTrue);
      expect((support.dy - legal.dy).abs(), lessThan(1));
    });

    testWidgets('Privacy Policy and Terms of Service open their screens', (tester) async {
      await pump(tester, SupportContact.empty);
      await tester.tap(find.text(_en.common_privacyPolicy));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.common_termsOfService));
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
    });

    testWidgets('Help and contact opens the same rows as the dashboard Help', (tester) async {
      await pump(tester, SupportContact.fromMap(helpDialogContact));
      await tester.tap(find.text(_en.authFooter_helpContact));
      await tester.pumpAndSettle();
      expect(helpDialogTexts(tester), helpDialogExpectedRows);
    });

    testWidgets('offline or empty: no icons, and Help and contact still opens', (tester) async {
      await pump(tester, SupportContact.empty);
      expect(find.byType(FaIcon), findsNothing);
      await tester.tap(find.text(_en.authFooter_helpContact));
      await tester.pumpAndSettle();
      expect(helpDialogTexts(tester), [_en.dashboard_contactSupport, _en.dashboard_supportIntro(AppInfo.name), _en.common_close]);
    });

    testWidgets('only the links that are set, in the fixed order, each named', (tester) async {
      await pump(
          tester,
          SupportContact.fromMap(const {
            'tiktok': 'tiktok.com/@vetbiz',
            'instagram': 'https://instagram.com/vetbiz',
            'facebook': 'www.facebook.com/vetbiz',
          }));
      expect(iconNames(tester), [_en.social_facebook, _en.social_instagram, _en.social_tiktok]);
      expect(find.bySemanticsLabel(_en.social_instagram), findsOneWidget);
    });

    testWidgets('javascript:, data: and ftp: values are ignored', (tester) async {
      await pump(
          tester,
          SupportContact.fromMap(const {
            'facebook': 'javascript:alert(1)',
            'instagram': 'data:text/html,hi',
            'x': 'ftp://x.com/vetbiz',
          }));
      expect(find.byType(FaIcon), findsNothing);
    });

    testWidgets('an icon opens its link outside the app', (tester) async {
      await pump(tester, SupportContact.fromMap(const {'x': 'x.com/vetbiz'}));
      await tester.tap(find.byType(FaIcon));
      await tester.pump();
      expect(launched, [(Uri.parse('https://x.com/vetbiz'), LaunchMode.externalApplication)]);
    });

    testWidgets('every link and icon is at least 48 px high', (tester) async {
      await pump(tester, SupportContact.fromMap(const {'facebook': 'facebook.com/v', 'youtube': 'youtube.com/v'}), size: const Size(390, 900));
      for (final text in [_en.authFooter_helpContact, _en.common_privacyPolicy, _en.common_termsOfService]) {
        final target = find.ancestor(of: find.text(text), matching: find.byType(HoverLink)).first; // G4: HoverLink, was InkWell
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48), reason: text);
      }
      for (final icon in tester.widgetList(find.byType(FaIcon))) {
        final target = find.ancestor(of: find.byWidget(icon), matching: find.byType(HoverLink)); // G4: HoverLink, was IconButton
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('phones: the columns stack (Support above Legal)', (tester) async {
      await pump(tester, SupportContact.empty, size: const Size(360, 900));
      final support = tester.getTopLeft(find.text(_en.authFooter_support));
      final legal = tester.getTopLeft(find.text(_en.authFooter_legal));
      expect(support.dy, lessThan(legal.dy));
    });

    final everyLink = SupportContact.fromMap(const {
      'facebook': 'facebook.com/v',
      'instagram': 'instagram.com/v',
      'x': 'x.com/v',
      'linkedin': 'linkedin.com/v',
      'youtube': 'youtube.com/v',
      'tiktok': 'tiktok.com/v',
    });
    for (final width in [360.0, 390.0, 768.0, 1200.0]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('en'), Locale('sw')]) {
          testWidgets('no overflow at $width, ${brightness.name}, ${locale.languageCode}', (tester) async {
            await pump(tester, everyLink, size: Size(width, 900), brightness: brightness, locale: locale);
            expect(tester.takeException(), isNull);
            expect(find.byType(FaIcon), findsNWidgets(6));
          });
        }
      }
    }
  });
}
