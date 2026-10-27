import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';

import 'helpers/login_harness.dart';
import 'helpers/real_font.dart';

// AN5 third correction, written before the change: the welcome note's line
// is "Track our latest news and notices."; the left card's icon is a vaccine,
// not a paw (the right card keeps its lock); the footer's brand line may take
// three lines on wide windows (four on phones) so the Kiswahili is never cut,
// measured in a real font (Roboto), while the English stays at two there.
const _skip = true;

const _welcome = 'Track our latest news and notices.';
const _welcomeSw = 'Fuatilia habari na taarifa zetu za hivi punde.';

void main() {
  setUpAll(loadRealFont);

  for (final (locale, text) in const [(Locale('en'), _welcome), (Locale('sw'), _welcomeSw)]) {
    testWidgets('${locale.languageCode}: the welcome note\'s line is the new one, not the footer sentence', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), locale: locale);
      expect(find.descendant(of: find.byKey(UpdatesCard.surfaceKey), matching: find.text(text)), findsOneWidget);
      expect(text, isNot(lookupAppLocalizations(locale).authFooter_description));
    }, skip: _skip);
  }

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: a vaccine in the welcome circle, no paw; the lock stays', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), brightness: brightness);
      expect(find.descendant(of: find.byKey(UpdatesCard.welcomeHeadingKey), matching: find.byIcon(Icons.vaccines_outlined)), findsOneWidget);
      expect(find.byIcon(Icons.pets_outlined), findsNothing);
      expect(find.descendant(of: find.byKey(LoginScreen.welcomeBackRowKey), matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
    }, skip: _skip);
  }

  test('the brand line may take three lines on a wide window, four on phones', () {
    expect(AuthFooterMetrics.descriptionMaxLinesWide, 3);
    expect(AuthFooterMetrics.descriptionMaxLines, 4);
  }, skip: _skip);

  for (final locale in const [Locale('en'), Locale('sw')]) {
    for (final width in [1024.0, 1200.0, 768.0, 390.0, 360.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('Roboto ${locale.languageCode} $width ${brightness.name}: the brand line is never cut, no overflow', (tester) async {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final theme = AppTheme.build(AppColorTheme.pasture, brightness);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SingleChildScrollView(child: AuthFooter(store: SupportContactStore.seeded(SupportContact.empty)))),
            ),
          );
          await tester.pumpAndSettle();
          final line = find.descendant(of: find.byKey(AuthFooter.brandKey), matching: find.text(lookupAppLocalizations(locale).authFooter_description));
          final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: line, matching: find.byType(RichText)));
          final wide = width > AppBreakpoints.medium;
          expect(tester.widget<Text>(line).maxLines, wide ? AuthFooterMetrics.descriptionMaxLinesWide : AuthFooterMetrics.descriptionMaxLines);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'no ellipsis');
          final lines = (paragraph.size.height / paragraph.getFullHeightForCaret(const TextPosition(offset: 0))).round();
          if (wide && locale.languageCode == 'en') expect(lines, 2, reason: 'the English stays at two lines');
          expect(tester.getSize(find.byKey(AuthFooter.bottomRowKey)).height, greaterThanOrEqualTo(AuthFooterMetrics.bottomRowHeight));
          expect(tester.takeException(), isNull);
          // ignore: avoid_print
          print('AN5 footer ${locale.languageCode} $width ${brightness.name}: ${tester.getSize(find.byKey(AuthFooter.bandKey)).height} px, $lines lines');
        }, skip: _skip);
      }
    }
  }
}
