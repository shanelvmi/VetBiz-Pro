import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';

import 'helpers/login_harness.dart';

// AN5, written before the change: the Updates label in textPrimary, bold
// (7:1 or more on the card in every theme, Light and Dark; 16 px on phones,
// 18 px on wide windows); the footer's brand column gains one audience line
// under the mark and the name (authFooterMutedText, 13 or 14 px, at most
// three lines, not the welcome sentence); no overflow on the login page.
const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));

const _audience = 'For agrovets, vet clinics, vet hospitals and ambulatory services in Tanzania.';
const _audienceSw = 'Kwa agrovet, kliniki za mifugo, hospitali za mifugo na huduma za kutembelea nchini Tanzania.';

void main() {
  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name}: the Updates label reads at 7:1 or more, bold', (tester) async {
        await pumpLogin(tester, await dbWithUpdates(1), theme: theme, brightness: brightness);
        final style = tester.widget<Text>(find.text(_en.updates_label)).style!;
        final c = AppColors.fromTheme(theme, brightness: brightness);
        expect(style.color, c.textPrimary);
        expect(ColorMath.contrast(style.color!, c.surface), greaterThanOrEqualTo(7));
        expect(style.fontWeight, AppFontWeight.bold);
      }, skip: _skip);
    }
  }

  for (final (width, size) in [(390.0, AppFontSize.f16), (1200.0, AppFontSize.f18)]) {
    testWidgets('$width: the Updates label is $size px', (tester) async {
      await pumpLogin(tester, await dbWithUpdates(1), width: width, height: 2400);
      expect(tester.widget<Text>(find.text(_en.updates_label)).style!.fontSize, size);
    }, skip: _skip);
  }

  Future<double> pumpFooter(WidgetTester tester, double width, {Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppColorTheme.pasture, brightness),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: AuthFooter(store: SupportContactStore.seeded(SupportContact.empty)))),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(AuthFooter.bandKey)).height;
  }

  for (final width in [1200.0, 768.0, 390.0, 360.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('$width ${brightness.name}: the brand column\'s audience line under the mark and the name', (tester) async {
        final height = await pumpFooter(tester, width, brightness: brightness);
        final line = find.descendant(of: find.byKey(AuthFooter.brandKey), matching: find.text(_audience));
        expect(line, findsOneWidget);
        final text = tester.widget<Text>(line);
        final c = AppColors.fromTheme(AppColorTheme.pasture, brightness: brightness);
        expect(text.style!.color, c.authFooterMutedText);
        expect(ColorMath.contrast(c.authFooterMutedText, c.authFooterFill), greaterThanOrEqualTo(4.5));
        expect([AppFontSize.f13, AppFontSize.f14], contains(text.style!.fontSize));
        expect(text.maxLines, lessThanOrEqualTo(3));
        expect(tester.getRect(line).height, lessThanOrEqualTo(3 * text.style!.fontSize! * 1.6), reason: 'three lines at most');
        expect(tester.getRect(line).top, greaterThan(tester.getRect(find.text(AppInfo.name).first).bottom));
        // Wide: the rest of the footer unchanged (AN4: 170); only what the brand
        // column reaches below the last link (the square test font wraps the line
        // to three lines; real fonts, two, above the links' bottom) adds to it.
        if (width >= 1200) {
          final lastLink = tester.getRect(find.text(_en.common_termsOfService)).bottom;
          final over = tester.getRect(find.byKey(AuthFooter.brandKey)).bottom - lastLink;
          expect(height - (over > 0 ? over : 0), lessThanOrEqualTo(170));
        }
        expect(tester.getSize(find.byKey(AuthFooter.bottomRowKey)).height, greaterThanOrEqualTo(AuthFooterMetrics.bottomRowHeight));
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }
  }

  testWidgets('the audience line is not the welcome note\'s sentence', (tester) async {
    expect(_audience, isNot(_en.updates_welcomeLine));
    expect(_audienceSw, isNot(lookupAppLocalizations(const Locale('sw')).updates_welcomeLine));
  }, skip: _skip);

  testWidgets('360 Kiswahili: the long audience line wraps in the column, three lines at most', (tester) async {
    await pumpFooter(tester, 360, locale: const Locale('sw'));
    final line = find.text(_audienceSw);
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).maxLines, lessThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  for (final width in [360.0, 390.0, 768.0, 1024.0, 1200.0]) {
    for (final (brightness, locale) in [
      (Brightness.light, const Locale('en')),
      (Brightness.dark, const Locale('en')),
      (Brightness.light, const Locale('sw')),
    ]) {
      testWidgets('$width ${brightness.name} ${locale.languageCode}: the login page has no overflow', (tester) async {
        await pumpLogin(tester, await dbWithUpdates(3), width: width, height: 2400, brightness: brightness, locale: locale);
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }
  }
}
