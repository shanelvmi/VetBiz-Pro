import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:vetbiz_pro/screens/platform_admin/announcements_tab.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

import 'helpers/help_dialog_rows.dart';

// G4: footer v2 (four columns on a full-width band, every item a HoverLink),
// the About, How to use it and FAQs pages, and the Platform Admin's hint.
// Written before the code: run against G3's footer and the stub pages, every
// test here fails (no Platform column, no band, no page text, no hint).
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

void main() {
  Future<bool> fakeLaunch(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async => true;

  Future<void> pumpFooter(
    WidgetTester tester, {
    SupportContact contact = SupportContact.empty,
    Size size = const Size(1200, 900),
    AppColorTheme theme = AppColorTheme.pasture,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(theme, brightness),
      home: Scaffold(
        body: SingleChildScrollView(child: AuthFooter(contact: Future.value(contact), launcher: fakeLaunch)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final about = _en.authFooter_about(AppInfo.name);
  final footerLinks = [about, _en.authFooter_howToUse, _en.authFooter_helpContact, _en.authFooter_faq, _en.common_privacyPolicy, _en.common_termsOfService];

  group('Footer v2', () {
    testWidgets('wide: brand, Platform, Support, Legal side by side, each with its links', (tester) async {
      await pumpFooter(tester);
      final headings = [_en.authFooter_platform, _en.authFooter_support, _en.authFooter_legal].map((t) => tester.getTopLeft(find.text(t))).toList();
      final brand = tester.getTopLeft(find.text(_en.authFooter_tagline));
      expect(brand.dx < headings[0].dx && headings[0].dx < headings[1].dx && headings[1].dx < headings[2].dx, isTrue);
      for (final h in headings) {
        expect((h.dy - headings[0].dy).abs(), lessThan(1));
      }
      for (final link in footerLinks) {
        expect(find.text(link), findsOneWidget, reason: link);
      }
      // The bottom row: copyright left, below a hairline.
      expect(tester.getTopLeft(find.text(_en.login_copyright(AppInfo.name))).dy, greaterThan(tester.getBottomLeft(find.text(_en.common_termsOfService)).dy));
    }, skip: _skip);

    testWidgets('phones: brand on top, then a two-column list', (tester) async {
      await pumpFooter(tester, size: const Size(360, 1200));
      final brand = tester.getTopLeft(find.text(_en.authFooter_tagline));
      final platform = tester.getTopLeft(find.text(_en.authFooter_platform));
      final support = tester.getTopLeft(find.text(_en.authFooter_support));
      final legal = tester.getTopLeft(find.text(_en.authFooter_legal));
      expect(brand.dy, lessThan(platform.dy));
      expect((platform.dy - support.dy).abs(), lessThan(1));
      expect(support.dx, greaterThan(platform.dx));
      expect(legal.dy, greaterThan(platform.dy));
      expect((legal.dx - platform.dx).abs(), lessThan(1));
    }, skip: _skip);

    testWidgets('every link and social icon is a HoverLink', (tester) async {
      await pumpFooter(tester, contact: SupportContact.fromMap(const {'facebook': 'facebook.com/v', 'tiktok': 'tiktok.com/v'}));
      for (final link in footerLinks) {
        expect(find.ancestor(of: find.text(link), matching: find.byType(HoverLink)), findsOneWidget, reason: link);
      }
      for (final icon in tester.widgetList(find.byType(FaIcon))) {
        expect(find.ancestor(of: find.byWidget(icon), matching: find.byType(HoverLink)), findsOneWidget);
      }
      expect(find.byType(FaIcon), findsNWidgets(2));
    }, skip: _skip);

    testWidgets('each item opens its page or dialog', (tester) async {
      await pumpFooter(tester, contact: SupportContact.fromMap(helpDialogContact));
      Future<void> opens(String link, Type page) async {
        await tester.tap(find.text(link));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: link);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      await opens(about, AboutScreen);
      await opens(_en.authFooter_howToUse, HowToUseScreen);
      await opens(_en.authFooter_faq, FaqScreen);
      await opens(_en.common_privacyPolicy, PrivacyPolicyScreen);
      await opens(_en.common_termsOfService, TermsOfServiceScreen);
      await tester.tap(find.text(_en.authFooter_helpContact));
      await tester.pumpAndSettle();
      expect(helpDialogTexts(tester), helpDialogExpectedRows);
    }, skip: _skip);

    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        testWidgets('the band spans the page in ${theme.id} ${brightness.name}: authFooterFill, a hairline on top', (tester) async {
          await pumpFooter(tester, size: const Size(1400, 900), theme: theme, brightness: brightness);
          final colors = AppColors.fromTheme(theme, brightness: brightness);
          final band = find.byKey(AuthFooter.bandKey);
          expect(tester.getSize(band).width, 1400);
          final decoration = tester.widget<DecoratedBox>(band).decoration as BoxDecoration;
          expect(decoration.color, colors.authFooterFill);
          expect((decoration.border as Border).top, BorderSide(color: colors.divider, width: AuthFooterMetrics.hairline));
        }, skip: _skip);
      }
    }
  });

  group('The three pages, signed out', () {
    Future<void> pumpPage(WidgetTester tester, Widget page, {Size size = const Size(1200, 900), Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        darkTheme: AppTheme.build(AppColorTheme.pasture, Brightness.dark),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(),
      ));
      nav.currentState!.push(MaterialPageRoute(builder: (_) => page));
      await tester.pumpAndSettle();
    }

    final pages = <String, Widget Function()>{
      'about': () => AboutScreen(contact: Future.value(SupportContact.empty)),
      'howToUse': () => const HowToUseScreen(),
      'faq': () => const FaqScreen(),
    };

    testWidgets('About: the sentences of the content table and a Help and contact link', (tester) async {
      await pumpPage(tester, pages['about']!());
      for (final text in [
        _en.about_intro(AppInfo.name), _en.about_whoFor, _en.about_coversTitle, _en.about_coverSales, _en.about_coverStock,
        _en.about_coverServices, _en.about_coverClients, _en.about_coverPayments, _en.about_coverReports, _en.about_coverTeam,
        _en.about_whoBuilds(AppInfo.name), _en.about_yourData, _en.about_questions,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.ancestor(of: find.text(_en.authFooter_helpContact), matching: find.byType(HoverLink)), findsOneWidget);
      await tester.ensureVisible(find.text(_en.authFooter_helpContact));
      await tester.tap(find.text(_en.authFooter_helpContact));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }, skip: _skip);

    testWidgets('How to use it: the owner steps, then the assistant steps, in order', (tester) async {
      await pumpPage(tester, pages['howToUse']!());
      final texts = [
        _en.howToUse_ownerTitle, _en.howToUse_owner1, _en.howToUse_owner2, _en.howToUse_owner3, _en.howToUse_owner4, _en.howToUse_owner5,
        _en.howToUse_owner6, _en.howToUse_owner7, _en.howToUse_owner8, _en.howToUse_owner9, _en.howToUse_owner10,
        _en.howToUse_assistantTitle, _en.howToUse_assistant1, _en.howToUse_assistant2, _en.howToUse_assistant3,
        _en.howToUse_assistant4, _en.howToUse_assistant5, _en.howToUse_assistant6,
      ];
      var lastY = -1.0;
      for (final text in texts) {
        expect(find.text(text), findsOneWidget, reason: text);
        final y = tester.getTopLeft(find.text(text)).dy;
        expect(y, greaterThan(lastY), reason: text);
        lastY = y;
      }
    }, skip: _skip);

    testWidgets('FAQs: twelve questions; an answer shows when its question is tapped', (tester) async {
      await pumpPage(tester, pages['faq']!());
      expect(find.byType(ExpansionTile), findsNWidgets(12));
      expect(find.text(_en.faq_printA), findsNothing);
      await tester.ensureVisible(find.text(_en.faq_printQ));
      await tester.tap(find.text(_en.faq_printQ));
      await tester.pumpAndSettle();
      expect(find.text(_en.faq_printA), findsOneWidget);
    }, skip: _skip);

    for (final entry in pages.entries) {
      testWidgets('${entry.key}: a back arrow, a readable column, body text 14 px or more', (tester) async {
        await pumpPage(tester, entry.value());
        expect(find.byType(BackButton), findsOneWidget);
        if (entry.key == 'faq') {
          for (final tile in tester.widgetList<ExpansionTile>(find.byType(ExpansionTile)).toList()) {
            await tester.ensureVisible(find.byWidget(tile));
            await tester.tap(find.byWidget(tile.title));
            await tester.pumpAndSettle();
          }
        }
        final column = find.byKey(const ValueKey<String>('info-page-column'));
        expect(tester.getSize(column).width, lessThanOrEqualTo(InfoPageMetrics.maxWidth));
        final paragraphs = tester.renderObjectList<RenderParagraph>(find.descendant(of: column, matching: find.byType(RichText)));
        expect(paragraphs, isNotEmpty);
        for (final p in paragraphs) {
          expect(p.text.style?.fontSize ?? 0, greaterThanOrEqualTo(14), reason: p.text.toPlainText());
        }
      }, skip: _skip);

      for (final width in const [360.0, 390.0, 768.0, 1200.0]) {
        for (final brightness in Brightness.values) {
          for (final locale in const [Locale('en'), Locale('sw')]) {
            testWidgets('${entry.key}: no overflow at $width, ${brightness.name}, ${locale.languageCode}', (tester) async {
              await pumpPage(tester, entry.value(), size: Size(width, 800), brightness: brightness, locale: locale);
              expect(tester.takeException(), isNull);
              final l10n = locale.languageCode == 'sw' ? _sw : _en;
              final title = switch (entry.key) {
                'about' => l10n.authFooter_about(AppInfo.name),
                'howToUse' => l10n.authFooter_howToUse,
                _ => l10n.authFooter_faq,
              };
              expect(find.text(title), findsOneWidget);
              expect(find.byKey(const ValueKey<String>('info-page-column')), findsOneWidget);
            }, skip: _skip);
          }
        }
      }
    }
  });

  test('no marketing words, claims or prices in the pages\' English', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final texts = arb.entries
        .where((e) => !e.key.startsWith('@') && RegExp(r'^(about_|howToUse_|faq_|authFooter_(platform|about|howToUse|faq)$)').hasMatch(e.key))
        .map((e) => '${e.key}: ${e.value}')
        .toList();
    expect(texts.length, 4 + 13 + 18 + 24);
    final banned = RegExp(
        r'\b(seamless\w*|powerful|unlock\w*|empower\w*|streamlin\w*|robust|smart\w*|intelligen\w*|all-in-one|insights?|journey|effortless\w*|'
        r'cutting-edge|revolution\w*|game-chang\w*|best-in-class|world-class|leverag\w*|synerg\w*|secur\w*|safe\w*|protect\w*|guarantee\w*|'
        r'uptime|always available|reliab\w*|savings?|save (time|money)|AI|artificial)\b',
        caseSensitive: false);
    final price = RegExp(r'Tsh|TSh|TZS|\d{1,3},\d{3}');
    for (final t in texts) {
      expect(banned.hasMatch(t.replaceAll(RegExp(r'save it as a PDF|saved as their debt|saved on this device'), '')), isFalse, reason: t);
      expect(price.hasMatch(t), isFalse, reason: t);
    }
  });

  testWidgets('Platform Admin: the hint under the social link fields', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: ContactDetailsCard(firestore: FakeFirebaseFirestore()))),
    ));
    await tester.pumpAndSettle();
    const hint = 'Icons appear on the sign-in page once a link is saved.';
    expect(find.text(hint), findsOneWidget);
    expect(tester.getTopLeft(find.text(hint)).dy, greaterThan(tester.getBottomLeft(find.widgetWithText(TextField, 'TikTok')).dy));
    expect(tester.getTopLeft(find.text(hint)).dy, lessThan(tester.getTopLeft(find.text('Save Contact Details')).dy));
  }, skip: _skip);
}
