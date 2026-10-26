import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/screens/info/about_screen.dart';
import 'package:vetbiz_pro/screens/info/faq_screen.dart';
import 'package:vetbiz_pro/screens/info/how_to_use_screen.dart';
import 'package:vetbiz_pro/screens/info/info_page.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// G5: the About, How to use it and FAQs pages centre their top bar title,
// once in the shared InfoPage, so the three agree; the back arrow stays at
// the left and a long title never runs over it. Written before the change,
// skipped until it exists.
const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  // The page opened over another, as the footer opens it, so it has its
  // back arrow.
  Future<void> open(WidgetTester tester, Widget page, {required double width, required Brightness brightness}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        darkTheme: AppTheme.build(AppColorTheme.pasture, Brightness.dark),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: Text('sign in')),
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  final pages = <String, (Widget, String)>{
    'About': (AboutScreen(store: SupportContactStore.seeded(SupportContact.empty)), _en.authFooter_about(AppInfo.name)),
    'How to use it': (const HowToUseScreen(), _en.authFooter_howToUse),
    'FAQs': (const FaqScreen(), _en.authFooter_faq),
  };

  for (final MapEntry(key: name, value: (page, title)) in pages.entries) {
    for (final width in [360.0, 1200.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('$name, $width, ${brightness.name}: the title is centred, the back arrow at the left', (tester) async {
          await open(tester, page, width: width, brightness: brightness);
          final bar = tester.getRect(find.byType(AppBar));
          final text = tester.getRect(find.descendant(of: find.byType(AppBar), matching: find.text(title)));
          final back = tester.getRect(find.byType(BackButton));
          expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
          // Centred whenever half the title fits between the arrow (and
          // the toolbar's 16 px spacing) and the middle; a longer one (the
          // test font is wide) is shortened, still clear of the arrow.
          final fits = text.width / 2 <= bar.center.dx - back.right - 16;
          if (fits || width == 1200) expect(text.center.dx, closeTo(bar.center.dx, 1));
          expect(back.left, lessThan(bar.left + 16));
          expect(text.left, greaterThanOrEqualTo(back.right));
          expect(text.right, lessThanOrEqualTo(bar.right));
          expect(tester.takeException(), isNull);
        }, skip: _skip);
      }
    }
  }

  testWidgets('360: a long title stays clear of the back arrow and inside the bar', (tester) async {
    final long = List.filled(6, 'A long page title').join(' ');
    await open(tester, InfoPage(title: long, children: const []), width: 360, brightness: Brightness.light);
    final bar = tester.getRect(find.byType(AppBar));
    final text = tester.getRect(find.descendant(of: find.byType(AppBar), matching: find.text(long)));
    final back = tester.getRect(find.byType(BackButton));
    expect(text.left, greaterThanOrEqualTo(back.right));
    expect(text.right, lessThanOrEqualTo(bar.right));
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
    expect(tester.takeException(), isNull);
  }, skip: _skip);
}
