// UI7 (1)(2): every chart page on the phone Home has ONE header row: the
// title at the left (14 px semibold) and at the right the Sales legend
// ("Last n days" solid, "Previous n days" dashed) or, on Product movement
// and Visit activity, the period in the muted role. The separate period
// line is gone, so the period is named once per page. When the Sales legend
// does not fit beside the title (measured: long Kiswahili, 30 days, text
// scale 1.3) it moves to a second row; the title never truncates. The
// freed height goes to the plot (at least 30 px at 390x844), the three pages
// keep one outer height and top, and each page's reveal skeleton has the
// rect its content then takes.
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_days_page.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_products_page.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_visits_page.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/home_movement.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/reveal/late_slot.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

const _header = ValueKey('home-chart-header');
const _title = ValueKey('home-chart-title');
const _period = ValueKey('home-chart-period');
const _legend = ValueKey('home-chart-legend');
const _pages = [HomeChartSalesPage, HomeChartProductsPage, HomeChartVisitsPage];
const _titles = ['Sales', 'Product movement', 'Visit activity'];

/// The Sales plot at 390x844 before UI7 (three header rows: 374 to 440).
const _plotBefore = 142.0;

Widget _roboto(Widget child) => Builder(builder: (context) {
      final theme = Theme.of(context);
      return Theme(data: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)), child: child);
    });

Future<void> _pump(WidgetTester tester, {double width = 390, MatrixLook look = MatrixLook.light,
    HomeChartRange range = HomeChartRange.week, double textScale = 1, Widget? charts}) async {
  await pumpAtSize(tester, size: Size(width, 844), look: look, textScale: textScale,
      screen: _roboto(phoneHomeHarness(charts: charts ?? HarnessCharts().build(range: range))));
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester) async {
  await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
}

Finder _in(Type page, Finder f) => find.descendant(of: find.byType(page), matching: f);
Rect _rect(WidgetTester tester, Type page, Finder f) => tester.getRect(_in(page, f));

RenderParagraph _paragraph(WidgetTester tester, Finder f) =>
    tester.renderObject<RenderParagraph>(find.descendant(of: f, matching: find.byType(RichText)).first);

/// The width a paragraph needs on one line (TextPainter, its own style and scale).
double _needs(RenderParagraph p) =>
    (TextPainter(text: p.text, textScaler: p.textScaler, textDirection: TextDirection.ltr, maxLines: 1)..layout())
        .width;

void _expectWhole(RenderParagraph p, String where) {
  expect(p.didExceedMaxLines, isFalse, reason: '$where ${p.text.toPlainText()}');
  expect(p.size.width, greaterThanOrEqualTo(_needs(p) - 0.5), reason: '$where ${p.text.toPlainText()} not cut');
}

/// A carousel whose answers wait for [days], [movement] and [visits].
Widget _waiting(Completer<HomeChartDays> days, Completer<HomeMovement> movement,
        Completer<List<ServiceSlice>> visits) =>
    HomeChartCarousel(
      days: (_) => days.future,
      movement: (_) => movement.future,
      visits: (_) => visits.future,
      range: HomeChartRange.week,
      onRangeChanged: (_) {},
      amountsHidden: false,
      onOpenProduct: (_) {},
      onRecordSale: () {},
    );

HomeChartDays _sales({bool empty = false}) {
  final today = DateTime(ph4Now.year, ph4Now.month, ph4Now.day);
  return HomeChartDays(
    firstDay: today.subtract(const Duration(days: 13)),
    sales: [for (var i = 0; i < 14; i++) empty ? 0 : 1000.0 * (i + 1)],
    services: List.filled(14, 0),
    span: 7,
  );
}

void main() {
  setUpAll(loadRealFont);

  for (final range in HomeChartRange.values) {
    final period = 'Last ${range.days} days';
    testWidgets('${range.key}: one header row per page, the title left, its content right, no subtitle row',
        (tester) async {
      await _pump(tester, range: range);
      final tops = <double>[];
      for (var i = 0; i < _pages.length; i++) {
        final page = _pages[i];
        expect(_in(page, find.byKey(_header)), findsOneWidget, reason: '$page');
        final header = _rect(tester, page, find.byKey(_header));
        final title = _rect(tester, page, find.byKey(_title));
        tops.add(header.top);
        expect(header.height, lessThanOrEqualTo(24), reason: '$page: one row, 24 px at most');
        expect(title.left, header.left, reason: '$page: the title at the left');
        expect(tester.widget<Text>(_in(page, find.byKey(_title))).data, _titles[i]);
        final style = tester.widget<Text>(_in(page, find.byKey(_title))).style!;
        expect((style.fontSize, style.fontWeight), (14.0, AppFontWeight.semibold), reason: '$page');
        final end = i == 0 ? _rect(tester, page, find.byKey(_legend)) : _rect(tester, page, find.byKey(_period));
        expect(end.right, closeTo(header.right, 0.5), reason: '$page: its content at the right');
        expect(end.top, lessThan(title.bottom), reason: '$page: on the title\'s row');
        expect(end.bottom, greaterThan(title.top), reason: '$page: on the title\'s row');
        // The period once, on the header's row: no subtitle line under it.
        final named = _in(page, find.text(period));
        expect(named, findsOneWidget, reason: '$page: the period named once');
        expect(tester.getRect(named).bottom, lessThanOrEqualTo(header.bottom + 0.5), reason: '$page: in the header');
        if (i < _pages.length - 1) await _swipe(tester);
      }
      expect(tops.toSet(), hasLength(1), reason: 'the same top on every page');
    });
  }

  testWidgets('the right-hand content: the Sales legend (both swatches); the muted period on the others',
      (tester) async {
    await _pump(tester);
    final c = tester.element(find.byType(HomeChartSalesPage)).colors;
    for (final key in ['home-chart-legend-solid', 'home-chart-legend-dashed']) {
      expect(find.descendant(of: _in(HomeChartSalesPage, find.byKey(_header)), matching: find.byKey(ValueKey(key))),
          findsOneWidget, reason: key);
    }
    expect(_in(HomeChartSalesPage, find.byKey(_period)), findsNothing, reason: 'the legend names the period');
    for (final page in _pages.skip(1)) {
      await _swipe(tester);
      expect(_in(page, find.byKey(_legend)), findsNothing, reason: '$page');
      final text = tester.widget<Text>(_in(page, find.byKey(_period)));
      expect(text.style!.color, c.textMuted, reason: '$page: the muted role');
      expect(find.descendant(of: _in(page, find.byKey(_header)), matching: find.byKey(_period)), findsOneWidget);
    }
  });

  testWidgets('empty Sales: the muted period in the legend\'s place, the empty line and button under the header',
      (tester) async {
    await _pump(tester);
    final header = _rect(tester, HomeChartSalesPage, find.byKey(_header));
    await tester.pumpWidget(const SizedBox()); // a fresh carousel, not the one above kept
    await _pump(tester, charts: _waiting(Completer()..complete(_sales(empty: true)), Completer(), Completer()));
    expect(_rect(tester, HomeChartSalesPage, find.byKey(_header)), header, reason: 'the header does not move');
    expect(_in(HomeChartSalesPage, find.byKey(_legend)), findsNothing, reason: 'no lines to explain');
    expect(_in(HomeChartSalesPage, find.text('Last 7 days')), findsOneWidget);
    for (final key in ['home-chart-empty', 'home-chart-empty-action']) {
      expect(_rect(tester, HomeChartSalesPage, find.byKey(ValueKey(key))).top, greaterThan(header.bottom), reason: key);
    }
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
      for (final scale in [1.0, 1.3]) {
        for (final range in HomeChartRange.values) {
          testWidgets('$width ${look.name} x$scale ${range.key}: the legend beside the title when it fits, '
              'else on a second row; nothing cut or overlapping', (tester) async {
            await _pump(tester, width: width, look: look, range: range, textScale: scale);
            final where = '$width ${look.name} x$scale ${range.key}';
            final header = _rect(tester, HomeChartSalesPage, find.byKey(_header));
            final title = _rect(tester, HomeChartSalesPage, find.byKey(_title));
            final legend = _rect(tester, HomeChartSalesPage, find.byKey(_legend));
            final titleText = _paragraph(tester, _in(HomeChartSalesPage, find.byKey(_title)));
            _expectWhole(titleText, '$where title');
            final labels = find.descendant(of: _in(HomeChartSalesPage, find.byKey(_legend)), matching: find.byType(RichText));
            expect(labels, findsNWidgets(2));
            final needs = [for (final e in labels.evaluate()) _needs(e.renderObject! as RenderParagraph)];
            for (final e in labels.evaluate()) {
              _expectWhole(e.renderObject! as RenderParagraph, where);
            }
            // The title, 8, then swatch 14 + 4 + text, 12, swatch 14 + 4 + text.
            final fits = _needs(titleText) + 8 + 2 * (14 + 4) + 12 + needs[0] + needs[1] <= header.width;
            final oneRow = legend.top < title.bottom;
            expect(oneRow, fits, reason: '$where: measured ${fits ? 'fits' : 'does not fit'}');
            expect(title.overlaps(legend), isFalse, reason: where);
            expect(legend.left, greaterThanOrEqualTo(header.left), reason: where);
            expect(legend.right, lessThanOrEqualTo(header.right + 0.5), reason: where);
            if (oneRow) {
              expect(legend.left, greaterThan(title.right), reason: where);
              if (scale == 1) expect(header.height, lessThanOrEqualTo(24), reason: where);
            } else {
              expect(legend.top, greaterThanOrEqualTo(title.bottom - 0.5), reason: '$where: the second row');
            }
            if (width == 390 && look == MatrixLook.light && scale == 1 && range == HomeChartRange.week) {
              expect(oneRow, isTrue, reason: 'English 7d at 390 fits on one row');
            }
            if (width == 360 && look == MatrixLook.kiswahili && scale > 1 && range == HomeChartRange.month) {
              expect(oneRow, isFalse, reason: 'Kiswahili 30d at 360, x1.3 takes the second row');
              // Too wide for a row of its own as well: the entries one under the other.
              final solid = tester.getRect(find.byKey(const ValueKey('home-chart-legend-solid')));
              final dashed = tester.getRect(find.byKey(const ValueKey('home-chart-legend-dashed')));
              expect(dashed.top, greaterThan(solid.bottom), reason: 'stacked, nothing cut');
            }
            expect(tester.takeException(), isNull, reason: where);
          });
        }
      }
    }
  }

  testWidgets('390x844: the Sales plot gains the removed rows (30 px or more); every page one height and top; '
      'the ranked rows keep 48', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(LineChart)).height, greaterThanOrEqualTo(_plotBefore + 30));
    Rect card(Type page) => tester.getRect(_in(page, find.byType(Material)).first);
    final sales = card(HomeChartSalesPage);
    await _swipe(tester);
    expect(card(HomeChartProductsPage), sales, reason: 'Product movement');
    expect(tester.getSize(find.byKey(const ValueKey('home-top-0'))).height, 48);
    await _swipe(tester);
    expect(card(HomeChartVisitsPage), sales, reason: 'Visit activity');
  });

  testWidgets('the skeleton on each page has the rect its content then takes, under the one header row',
      (tester) async {
    final days = Completer<HomeChartDays>();
    final movement = Completer<HomeMovement>();
    final visits = Completer<List<ServiceSlice>>();
    await pumpAtSize(tester, size: const Size(390, 844),
        screen: _roboto(phoneHomeHarness(charts: _waiting(days, movement, visits))));
    // The skeleton pulses until its page answers: no pumpAndSettle before.
    Future<void> check(Type page, void Function() answer) async {
      final header = _rect(tester, page, find.byKey(_header));
      final slot = _rect(tester, page, find.byType(LateSlot));
      expect(slot.top, greaterThanOrEqualTo(header.bottom), reason: '$page: under the header');
      answer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_rect(tester, page, find.byKey(_header)), header, reason: '$page header');
      expect(_rect(tester, page, find.byType(LateSlot)), slot, reason: '$page content');
    }

    Future<void> next() async {
      await tester.fling(find.byKey(const ValueKey('home-chart-pages')), const Offset(-300, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await check(HomeChartSalesPage, () => days.complete(_sales()));
    await next();
    await check(HomeChartProductsPage,
        () => movement.complete(HomeMovement(top: [TopSeller('Dewormer', 8, ph4Product('d'))], slow: const [])));
    await next();
    await check(HomeChartVisitsPage, () => visits.complete(const [ServiceSlice('Vaccination', 3, 30000)]));
  });
}
