// UI2 (3): phone Home. Go to ends with Transactions (for every role), in a
// cell wide enough for its label on one line (76 to 96, measured); the other
// cells keep their one width, and no one-word label wraps or is cut. The four
// Quick access tiles keep two label lines each, so their icons share a top.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home_rows.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/real_font.dart';

const _skip = true;

Future<void> _pump(WidgetTester tester, Widget child, {required double width, required String locale}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = AppTheme.build(AppColorTheme.pasture, Brightness.light);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
    builder: (context, child) => DefaultTextStyle.merge(style: const TextStyle(fontFamily: realFontFamily), child: child!),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding), child: Column(children: [child])),
    ),
  ));
  await tester.pumpAndSettle();
}

final _goTo = find.byKey(const ValueKey('phone-home-go-to'));

void main() {
  setUpAll(loadRealFont);

  for (final isAdmin in [true, false]) {
    test('${isAdmin ? 'an admin' : 'an assistant'}: Transactions last, the others in their order', () {
      expect(goToItemsFor(isAdmin: isAdmin), [
        GoToItem.products,
        GoToItem.clients,
        GoToItem.debtors,
        GoToItem.reports,
        GoToItem.stockStore,
        GoToItem.services,
        GoToItem.payments,
        GoToItem.transactions,
      ]);
    }, skip: _skip);
  }

  for (final width in [360.0, 390.0]) {
    for (final locale in ['en', 'sw']) {
      testWidgets('Go to at $width in $locale: one-word labels on one line, uncut; Transactions fits', (tester) async {
        await _pump(tester, GoToRow(items: goToItemsFor(isAdmin: true), onGoTo: (_) {}), width: width, locale: locale);
        final items = goToItemsFor(isAdmin: true);
        final scrollable = find.descendant(of: _goTo, matching: find.byType(Scrollable));
        for (var i = 0; i < items.length; i++) {
          final label = find.descendant(of: _goTo, matching: find.text(goToLabel(tester.element(_goTo), items[i])));
          await tester.scrollUntilVisible(label, 40, scrollable: scrollable);
          await tester.pumpAndSettle();
          final cell = find.ancestor(of: label, matching: find.byType(InkWell));
          final text = tester.widget<Text>(label);
          final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: cell, matching: find.byType(RichText)));
          final last = i == items.length - 1;
          final width = tester.getSize(find.ancestor(of: cell, matching: find.byType(SizedBox)).first).width;
          if (last) {
            expect(width, inInclusiveRange(76, 96), reason: 'Transactions\' cell');
          } else {
            expect(width, PhoneHomeMetrics.goToItemWidth, reason: '${text.data}: the uniform width');
          }
          if (!text.data!.contains(' ')) {
            final lines = {for (final b in paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.data!.length))) b.top};
            expect(lines, hasLength(1), reason: '"${text.data}" wraps');
            expect(paragraph.didExceedMaxLines, isFalse, reason: '"${text.data}" is cut');
            expect(paragraph.size.width, lessThanOrEqualTo(width), reason: '"${text.data}" is wider than its cell');
          }
        }
      }, skip: _skip);

      testWidgets('Quick access at $width in $locale: the four icons share one top', (tester) async {
        await _pump(tester, QuickAccessTiles(onAction: (_) async {}), width: width, locale: locale);
        final icons = find.descendant(of: find.byType(QuickAccessTiles), matching: find.byType(Icon));
        expect(icons, findsNWidgets(4));
        final tops = {for (final e in icons.evaluate()) tester.getRect(find.byWidget(e.widget)).top};
        expect(tops, hasLength(1), reason: 'icon tops: $tops');
        for (final e in find.descendant(of: find.byType(QuickAccessTiles), matching: find.byType(RichText)).evaluate()) {
          expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
        }
      }, skip: _skip);
    }
  }
}
