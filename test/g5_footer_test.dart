import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

// G5: a shorter footer on wide windows (about a third less), 32 px link
// rows there (mouse), 48 px tap targets on phones and narrow windows
// (touch), and no empty gap between the columns and the bottom row. The
// band, the columns, the hover and the icons stay. Heights before G5, with
// the test font: wide 228, 390 px 479 (527 with an icon). Written before the
// change, skipped until it exists.
const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));

const _beforeWide = 228.0;
const _beforePhone = 479.0;
const _beforePhoneWithIcon = _beforePhone + 48;

void main() {
  Future<void> pump(WidgetTester tester, double width, {SupportContact contact = SupportContact.empty}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: AuthFooter(store: SupportContactStore.seeded(contact)))),
      ),
    );
    await tester.pumpAndSettle();
  }

  final textLinks = [_en.authFooter_howToUse, _en.authFooter_helpContact, _en.authFooter_faq, _en.common_privacyPolicy, _en.common_termsOfService];
  Rect linkRect(WidgetTester tester, String text) => tester.getRect(find.ancestor(of: find.text(text), matching: find.byType(HoverLink)).first);
  double bandHeight(WidgetTester tester) => tester.getSize(find.byKey(AuthFooter.bandKey)).height;
  double lastLinkBottom(WidgetTester tester) => textLinks.map((t) => linkRect(tester, t).bottom).reduce((a, b) => a > b ? a : b);
  // AN5: how far the brand column (now with its audience line, three lines
  // in the square test font, two with real fonts at 1200) reaches below the
  // last link; 0 when the links are the tallest column.
  double brandOverhang(WidgetTester tester) {
    final over = tester.getRect(find.byKey(AuthFooter.brandKey)).bottom - lastLinkBottom(tester);
    return over > 0 ? over : 0;
  }

  testWidgets('wide: every text link row is 32 px (or its label, if taller)', (tester) async {
    await pump(tester, 1200);
    for (final text in textLinks) {
      // The wide test font wraps "Terms of Service" in its column.
      final label = tester.getSize(find.text(text)).height;
      expect(linkRect(tester, text).height, label > 32 ? label : 32, reason: text);
    }
  }, skip: _skip);

  for (final width in [390.0, 768.0]) {
    testWidgets('$width (touch): every text link and icon keeps its 48 px target', (tester) async {
      await pump(tester, width, contact: SupportContact.fromMap(const {'facebook': 'facebook.com/v'}));
      for (final text in textLinks) {
        expect(linkRect(tester, text).height, greaterThanOrEqualTo(48), reason: text);
      }
      final icon = tester.getSize(find.ancestor(of: find.byType(FaIcon), matching: find.byType(HoverLink)));
      expect(icon.height, greaterThanOrEqualTo(48));
      expect(icon.width, greaterThanOrEqualTo(48));
    }, skip: _skip);
  }

  testWidgets('wide: about a third shorter than before G5, with or without icons', (tester) async {
    await pump(tester, 1200);
    final plain = bandHeight(tester) - brandOverhang(tester);
    await pump(tester, 1200, contact: SupportContact.fromMap(const {'facebook': 'facebook.com/v'}));
    final withIcon = bandHeight(tester) - brandOverhang(tester);
    // G6: the bottom row keeps the icons' 48 px line with or without them,
    // so both are 170 with the test font (plain was 154 when that line
    // shrank to 32 px without icons, and the footer jumped when they came).
    expect(plain, withIcon);
    expect(plain, lessThanOrEqualTo(_beforeWide * 0.75));
    expect(withIcon, lessThanOrEqualTo(_beforeWide * 0.75));
  }, skip: _skip);

  testWidgets('390: shorter than before G5 (with its icon line, now always kept)', (tester) async {
    await pump(tester, 390);
    // G6: the icons' own 48 px line is kept even with none, so the
    // comparison is with the old footer that had one (527); 499 now.
    expect(bandHeight(tester), lessThan(_beforePhoneWithIcon));
  }, skip: _skip);

  for (final width in [390.0, 1200.0]) {
    testWidgets('$width: no empty gap between the last link and the line above the bottom row', (tester) async {
      await pump(tester, width);
      // AN5: below the tallest column, the links or the brand column.
      final tallest = lastLinkBottom(tester) + brandOverhang(tester);
      final line = tester.getRect(find.descendant(of: find.byType(AuthFooter), matching: find.byType(Divider)));
      // Only the link box's own space (and on wide windows a small gap).
      expect(line.top - tallest, lessThanOrEqualTo(width == 1200 ? AppSpacing.s8 : 0));
    }, skip: _skip);
  }
}
