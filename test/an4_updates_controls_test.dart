import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/updates_card.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';
import 'package:vetbiz_pro/widgets/updates_parts.dart';

import 'helpers/login_harness.dart';
import 'helpers/updates_harness.dart';

// AN4, written before the change: a larger Updates label (16 px on phones,
// 18 px on wide windows, semibold) with its chips scaled to match; slide
// controls that read at 3:1 or more on the card in every theme, Light and
// Dark, with larger dots (the selected one larger and another colour); the
// footer's brand column without the description sentence.
// Unskipped with their commits.
const _skipWideLabel = false;
// The second AN5 correction: unskipped with its footer commit.
const _skipFooter = false;

final _en = lookupAppLocalizations(const Locale('en'));

// The sentence the footer's brand column used to show (now the welcome note's).
const _oldTagline = 'Sales, stock, clients and debts for agrovets and vet clinics.';

void main() {
  TextStyle labelStyle(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!;

  for (final (width, size) in [(390.0, AppFontSize.f16), (1200.0, AppFontSize.f18)]) {
    testWidgets('$width: the Updates label is $size px (AN5: bold); the chips scaled to match and kept in its row', (tester) async {
      final db = await dbWithUpdates(0);
      await addUpdate(db, 'p', posterData(urgent: true, fresh: true));
      await pumpLogin(tester, db, width: width, height: 2400);
      final style = labelStyle(tester, _en.updates_label);
      expect(style.fontSize, size);
      expect(style.fontWeight, AppFontWeight.bold);
      final row = tester.getRect(find.byKey(UpdatesLabel.rowKey));
      for (final chip in [_en.updates_important, _en.updates_new]) {
        expect(labelStyle(tester, chip).fontSize, greaterThanOrEqualTo(size - 4), reason: chip);
        final r = tester.getRect(find.ancestor(of: find.text(chip), matching: find.byType(UpdateChip)));
        expect(r.top >= row.top - 0.5 && r.bottom <= row.bottom + 0.5, isTrue, reason: '$chip inside the row');
      }
    }, skip: width > 1000 ? _skipWideLabel : false);
  }

  Future<void> pumpCard(WidgetTester tester, List<Announcement> slides, AppColorTheme theme, Brightness brightness) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(theme, brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 520,
            child: UpdatesCard(wide: false, child: UpdatesSlides(slides: slides, now: () => testNow, imageFor: goodImage)),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name}: the arrows and both dots read at 3:1 or more on the card', (tester) async {
        await pumpCard(tester, [textUpdate('1'), textUpdate('2'), textUpdate('3')], theme, brightness);
        final card = AppColors.fromTheme(theme, brightness: brightness).surface;
        for (final icon in [Icons.arrow_back, Icons.arrow_forward]) {
          final color = tester.widget<Icon>(find.byIcon(icon)).color!;
          expect(ColorMath.contrast(color, card), greaterThanOrEqualTo(3), reason: '$icon');
        }
        final dots = tester
            .widgetList<AnimatedContainer>(find.descendant(of: find.byType(UpdatesDots), matching: find.byType(AnimatedContainer)))
            .toList();
        expect(dots, hasLength(3));
        for (final dot in dots) {
          final color = (dot.decoration! as BoxDecoration).color!;
          expect(ColorMath.contrast(ColorMath.composite(color, card), card), greaterThanOrEqualTo(3));
        }
      }, skip: false);
    }
  }

  testWidgets('the dots: about 8 px, the selected one larger and another colour; 48 px targets; Semantics labels', (tester) async {
    await pumpCard(tester, [textUpdate('1'), textUpdate('2'), textUpdate('3')], AppColorTheme.pasture, Brightness.light);
    final sizes = [
      for (final e in find.descendant(of: find.byType(UpdatesDots), matching: find.byType(AnimatedContainer)).evaluate())
        tester.getSize(find.byWidget(e.widget)),
    ];
    final colors = [
      for (final d in tester.widgetList<AnimatedContainer>(find.descendant(of: find.byType(UpdatesDots), matching: find.byType(AnimatedContainer))))
        (d.decoration! as BoxDecoration).color,
    ];
    expect(sizes[1].width, closeTo(8, 0.5));
    expect(sizes[2].width, closeTo(8, 0.5));
    expect(sizes[0].width, greaterThanOrEqualTo(sizes[1].width + 3), reason: 'the selected one is larger');
    expect(colors[0], isNot(colors[1]), reason: 'and another colour');
    for (final icon in [Icons.arrow_back, Icons.arrow_forward]) {
      expect(tester.getSize(find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton))).width, greaterThanOrEqualTo(48));
    }
    for (final s in find.descendant(of: find.byType(UpdatesDots), matching: find.byType(InkResponse)).evaluate()) {
      expect(tester.getSize(find.byWidget(s.widget)).width, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel(_en.updates_slideOf(2, 3)), findsOneWidget);
    expect(find.byTooltip(_en.updates_previous), findsOneWidget);
    expect(find.byTooltip(_en.updates_next), findsOneWidget);
  }, skip: false);

  testWidgets('one update: no dots and no arrows', (tester) async {
    await pumpCard(tester, [textUpdate('1')], AppColorTheme.pasture, Brightness.light);
    expect(find.byType(UpdatesDots), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  }, skip: false);

  Future<double> pumpFooter(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: AuthFooter(store: SupportContactStore.seeded(SupportContact.empty)))),
    ));
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(AuthFooter.bandKey)).height;
  }

  // The footer's heights before AN4 (G6): 170 at 1200 (the link columns are
  // taller than the brand column there), 432 at 768, 499 at 390 and 360.
  for (final (width, before) in [(1200.0, 170.0), (768.0, 432.0), (390.0, 499.0), (360.0, 499.0)]) {
    testWidgets('$width: the footer\'s brand column is the mark, the name and (AN5) the description line; the rest of the footer no taller (shorter on phones)', (tester) async {
      final height = await pumpFooter(tester, width);
      final brand = find.byKey(AuthFooter.brandKey);
      expect(find.descendant(of: brand, matching: find.text(AppInfo.name)), findsOneWidget);
      expect(find.descendant(of: brand, matching: find.text(AppInfo.logoMark)), findsOneWidget);
      expect(find.descendant(of: brand, matching: find.byType(Text)), findsNWidgets(3));
      expect(find.text(_oldTagline), findsNothing);
      expect(find.descendant(of: brand, matching: find.text(_en.authFooter_description)), findsOneWidget);
      // AN5: all but what the description line adds to the brand column (its
      // mark row was the whole column in AN4).
      final rest = height - (tester.getSize(brand).height - AuthFooterMetrics.markSize);
      if (width >= 1200) {
        expect(rest, lessThanOrEqualTo(before));
      } else {
        expect(rest, lessThan(before));
      }
    }, skip: _skipFooter);
  }
}
