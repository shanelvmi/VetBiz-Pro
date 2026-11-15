// UI8: the phone help sheet (AuthHelpSheet), opened by the Help button of
// the signed-out pages on a phone. It holds what the footer holds, through
// the same links (AuthLink) and icons (AuthSocial): every link opens its
// target, the version shows, and the social icons only when some are saved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/screens/info/about_screen.dart';
import 'package:vetbiz_pro/screens/info/faq_screen.dart';
import 'package:vetbiz_pro/screens/info/how_to_use_screen.dart';
import 'package:vetbiz_pro/screens/legal/privacy_policy_screen.dart';
import 'package:vetbiz_pro/screens/legal/terms_of_service_screen.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_help_sheet.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

import 'helpers/help_dialog_rows.dart';

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  final launched = <(Uri, LaunchMode)>[];
  Future<bool> fakeLaunch(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    launched.add((url, mode));
    return true;
  }

  setUp(launched.clear);

  Future<void> open(WidgetTester tester, SupportContact contact, {Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = SupportContactStore.seeded(contact);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(AppColorTheme.pasture, brightness),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAuthHelpSheet(context, store: store, launcher: fakeLaunch),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a bottom sheet titled Help: the links, the copyright and the version', (tester) async {
    await open(tester, SupportContact.empty);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(_en.dashboard_help), findsOneWidget);
    for (final label in [
      _en.authFooter_faq,
      _en.authFooter_howToUse,
      _en.authFooter_about(AppInfo.name),
      _en.authFooter_helpContact,
      _en.common_termsOfService,
      _en.common_privacyPolicy,
      _en.login_copyright(AppInfo.name),
      _en.common_versionWithBuild(AppInfo.versionLabel, AppInfo.buildStamp),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  final pages = <String, Type>{
    _en.authFooter_faq: FaqScreen,
    _en.authFooter_howToUse: HowToUseScreen,
    _en.authFooter_about(AppInfo.name): AboutScreen,
    _en.common_termsOfService: TermsOfServiceScreen,
    _en.common_privacyPolicy: PrivacyPolicyScreen,
  };
  for (final MapEntry(key: label, value: page) in pages.entries) {
    testWidgets('$label opens its page', (tester) async {
      await open(tester, SupportContact.empty);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget);
    });
  }

  testWidgets('Help and contact opens the same rows as the dashboard Help', (tester) async {
    await open(tester, SupportContact.fromMap(helpDialogContact));
    await tester.tap(find.text(_en.authFooter_helpContact));
    await tester.pumpAndSettle();
    expect(helpDialogTexts(tester), helpDialogExpectedRows);
  });

  testWidgets('no social icons while none are saved', (tester) async {
    await open(tester, SupportContact.empty);
    expect(find.byKey(AuthHelpSheet.socialRowKey), findsNothing);
    expect(find.byType(FaIcon), findsNothing);
  });

  testWidgets('the saved icons only, in the fixed order; one opens its link outside the app', (tester) async {
    await open(tester, SupportContact.fromMap(const {'tiktok': 'tiktok.com/@vetbiz', 'facebook': 'www.facebook.com/vetbiz', 'x': 'javascript:alert(1)'}));
    final names = tester
        .widgetList<Tooltip>(find.ancestor(of: find.byType(FaIcon), matching: find.byType(Tooltip)))
        .map((t) => t.message)
        .toList();
    expect(names, [_en.social_facebook, _en.social_tiktok]);
    await tester.tap(find.byType(FaIcon).first);
    await tester.pump();
    expect(launched, [(Uri.parse('https://www.facebook.com/vetbiz'), LaunchMode.externalApplication)]);
  });

  testWidgets('every link and icon is a 48 px target', (tester) async {
    await open(tester, SupportContact.fromMap(const {'facebook': 'facebook.com/vetbiz'}));
    for (final element in find.byType(HoverLink).evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, greaterThanOrEqualTo(kMinInteractiveDimension));
    }
  });

  for (final brightness in Brightness.values) {
    for (final locale in const [Locale('en'), Locale('sw')]) {
      testWidgets('no overflow at 360x640, ${brightness.name}, ${locale.languageCode}', (tester) async {
        await open(tester, SupportContact.fromMap(helpDialogContact), brightness: brightness, locale: locale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
