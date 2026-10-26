import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
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
        home: Scaffold(body: SingleChildScrollView(child: AuthFooter(contact: Future.value(contact)))),
      ),
    );
    await tester.pumpAndSettle();
  }

  final textLinks = [_en.authFooter_howToUse, _en.authFooter_helpContact, _en.authFooter_faq, _en.common_privacyPolicy, _en.common_termsOfService];
  Rect linkRect(WidgetTester tester, String text) => tester.getRect(find.ancestor(of: find.text(text), matching: find.byType(HoverLink)).first);
  double bandHeight(WidgetTester tester) => tester.getSize(find.byKey(AuthFooter.bandKey)).height;

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
    final plain = bandHeight(tester);
    await pump(tester, 1200, contact: SupportContact.fromMap(const {'facebook': 'facebook.com/v'}));
    final withIcon = bandHeight(tester);
    // 154 with the test font (a label on two lines); 148 when every
    // label fits on one line.
    expect(plain, lessThanOrEqualTo(_beforeWide * 0.7));
    expect(withIcon, lessThanOrEqualTo(_beforeWide * 0.75));
  }, skip: _skip);

  testWidgets('390: shorter than before G5', (tester) async {
    await pump(tester, 390);
    expect(bandHeight(tester), lessThan(_beforePhone));
  }, skip: _skip);

  for (final width in [390.0, 1200.0]) {
    testWidgets('$width: no empty gap between the last link and the line above the bottom row', (tester) async {
      await pump(tester, width);
      final lastLinkBottom = textLinks.map((t) => linkRect(tester, t).bottom).reduce((a, b) => a > b ? a : b);
      final line = tester.getRect(find.descendant(of: find.byType(AuthFooter), matching: find.byType(Divider)));
      // Only the link box's own space (and on wide windows a small gap).
      expect(line.top - lastLinkBottom, lessThanOrEqualTo(width == 1200 ? AppSpacing.s8 : 0));
    }, skip: _skip);
  }
}
