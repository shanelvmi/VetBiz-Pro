// HUB4 (1)(2)(5): Home's chart carousel after HUB4: the two-way sync with the
// card's switch (every direction, no loops, all pages swipeable, instant
// under reduced motion), the 7d | 30d switch (one choice, each page asking
// once per range), the Sales line (guides 0 / half / clean top, markers only
// on days with a value, the least smoothing without overshoot, the legend,
// the days, the tooltip, the eye), Product movement (rows open products,
// slow movers, nothing sold, no products), Visit activity (legend counts and
// shares, a tap's detail, the eye, the empty ring), every empty page's
// action, the Semantics summaries, and the reads a carousel costs on the
// counting fake (no listener).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/home_card_mode.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/home_movement.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';

const _skip = false;

DateTime get _today => DateTime(testNow.year, testNow.month, testNow.day);

/// Sales on some days only (0 on the others), and a previous period.
HomeChartDays _days({int span = 7, bool empty = false}) => HomeChartDays(
  firstDay: _today.subtract(Duration(days: 2 * span - 1)),
  sales: [for (var i = 0; i < 2 * span; i++) empty || i % 3 == 1 ? 0 : 1000.0 * (i + 1)],
  services: List.filled(2 * span, 0),
  span: span,
);

final _vaccine = ph4Product('Vaccine');

final _movement = HomeMovement(
  top: [TopSeller('Vaccine', 9, _vaccine), const TopSeller('Gone', 2, null)],
  slow: [ph4Product('Bolus', qty: 40)],
);

const _slices = [ServiceSlice('Vaccination', 3, 30000), ServiceSlice('Surgery', 1, 80000)];

class _Host extends StatefulWidget {
  final HomeChartDays days;
  final HomeMovement movement;
  final List<ServiceSlice> slices;
  final bool hidden;
  final bool noProducts;
  final _Log log;

  const _Host({
    required this.log,
    required this.days,
    required this.movement,
    required this.slices,
    this.hidden = false,
    this.noProducts = false,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _Log {
  final modes = <HomeCardMode>[];
  final asked = <String>[];
  final opened = <String>[];
  int actions = 0;
  late void Function(HomeCardMode) setCard;
  late void Function(HomeChartRange) setRange;
}

class _HostState extends State<_Host> {
  HomeCardMode _mode = HomeCardMode.sales;
  HomeChartRange _range = HomeChartRange.week;

  @override
  Widget build(BuildContext context) {
    widget.log.setCard = (m) => setState(() => _mode = m);
    widget.log.setRange = (r) => setState(() => _range = r);
    return HomeChartCarousel(
      days: (r) {
        widget.log.asked.add('days ${r.key}');
        return Future.value(r == HomeChartRange.week ? widget.days : _days(span: 30));
      },
      movement: (r) {
        widget.log.asked.add('movement ${r.key}');
        return Future.value(widget.movement);
      },
      visits: (r) {
        widget.log.asked.add('visits ${r.key}');
        return Future.value(widget.slices);
      },
      range: _range,
      onRangeChanged: (r) => setState(() => _range = r),
      mode: _mode,
      onModeChanged: (m) {
        widget.log.modes.add(m);
        setState(() => _mode = m);
      },
      amountsHidden: widget.hidden,
      noProducts: widget.noProducts,
      onRecordSale: () => widget.log.actions++,
      onRecordVisit: () => widget.log.actions++,
      onAddProduct: () => widget.log.actions++,
      onOpenProduct: (p) => widget.log.opened.add(p.id),
    );
  }
}

Future<_Log> _pump(
  WidgetTester tester, {
  HomeChartDays? days,
  HomeMovement? movement,
  List<ServiceSlice> slices = _slices,
  bool hidden = false,
  bool noProducts = false,
  bool still = false,
  MatrixLook look = MatrixLook.light,
}) async {
  final log = _Log();
  await pumpAtSize(
    tester,
    size: const Size(390, 844),
    look: look,
    wrap: still ? (app) => MediaQuery(data: const MediaQueryData(disableAnimations: true), child: app) : null,
    screen: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 300,
          child: _Host(
            log: log,
            days: days ?? _days(),
            movement: movement ?? _movement,
            slices: slices,
            hidden: hidden,
            noProducts: noProducts,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return log;
}

Future<void> _swipe(WidgetTester tester, {bool back = false}) async {
  await tester.fling(find.byKey(const ValueKey('home-chart-pages')), Offset(back ? 300 : -300, 0), 1000);
  await tester.pumpAndSettle();
}

int _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byKey(const ValueKey('home-chart-pages'))).controller!.page!.round();

LineChartData _line(WidgetTester tester) => tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  group('two-way sync', () {
    testWidgets('the card scrolls the carousel: Visits to page 3, Sales to page 1', (tester) async {
      final log = await _pump(tester);
      expect(_page(tester), 0);
      log.setCard(HomeCardMode.services);
      await tester.pumpAndSettle();
      expect(_page(tester), 2);
      log.setCard(HomeCardMode.sales);
      await tester.pumpAndSettle();
      expect(_page(tester), 0);
      expect(log.modes, isEmpty, reason: 'a followed scroll reports nothing back (no loop)');
    }, skip: _skip);

    testWidgets('a swipe sets the card: page 3 Visits, pages 1 and 2 Sales; once each', (tester) async {
      final log = await _pump(tester);
      await _swipe(tester);
      expect(log.modes, isEmpty, reason: 'Product movement belongs to Sales');
      await _swipe(tester);
      expect(log.modes, [HomeCardMode.services]);
      await _swipe(tester, back: true);
      expect(log.modes, [HomeCardMode.services, HomeCardMode.sales]);
      expect(_page(tester), 1, reason: 'the swipe stays where the person left it');
      await _swipe(tester, back: true);
      expect(log.modes.length, 2);
      expect(_page(tester), 0);
    }, skip: _skip);

    testWidgets('Sales while on Product movement stays there; every page reachable', (tester) async {
      final log = await _pump(tester);
      await _swipe(tester);
      log.setCard(HomeCardMode.sales);
      await tester.pumpAndSettle();
      expect(_page(tester), 1);
      log.setCard(HomeCardMode.services);
      await tester.pumpAndSettle();
      await _swipe(tester, back: true);
      await _swipe(tester, back: true);
      expect(_page(tester), 0);
    }, skip: _skip);

    testWidgets('reduced motion: the page changes at once', (tester) async {
      final log = await _pump(tester, still: true);
      log.setCard(HomeCardMode.services);
      await tester.pump();
      await tester.pump();
      expect(_page(tester), 2);
      expect(log.modes, isEmpty);
    }, skip: _skip);
  });

  group('the range', () {
    testWidgets('7d by default; 30d asks each page once for 30 days, 7d again asks nothing', (tester) async {
      final log = await _pump(tester);
      expect(log.asked, ['days 7d']);
      await tester.tap(find.byKey(const ValueKey('home-chart-range-30d')));
      await tester.pumpAndSettle();
      expect(log.asked, ['days 7d', 'days 30d']);
      expect(find.text('Last 30 days'), findsWidgets);
      expect(find.text('Previous 30 days'), findsOneWidget);
      await _swipe(tester);
      await _swipe(tester);
      await tester.tap(find.byKey(const ValueKey('home-chart-range-7d')));
      await tester.pumpAndSettle();
      await _swipe(tester, back: true);
      await _swipe(tester, back: true);
      expect(log.asked, ['days 7d', 'days 30d', 'movement 30d', 'visits 30d', 'visits 7d', 'movement 7d']);
    }, skip: _skip);

    testWidgets('the switch: 32 drawn, 48 to touch, the chosen one selected', (tester) async {
      await _pump(tester);
      expect(tester.getSize(find.byKey(const ValueKey("home-chart-range-7d"))).height, 48);
      final pill = find.descendant(
        of: find.byKey(const ValueKey('home-chart-range-7d')),
        matching: find.byType(Container),
      );
      expect(tester.getSize(pill.first).height, 32);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('home-chart-range-7d'))),
        matchesSemantics(isButton: true, hasSelectedState: true, isSelected: true, label: '7d'),
      );
    }, skip: _skip);
  });

  group('Sales line', () {
    testWidgets('guides 0, half and a clean top; markers only on days with sales; no overshoot', (tester) async {
      await _pump(tester);
      final data = _line(tester);
      expect(data.maxY, 20000, reason: 'the largest of both periods, 14000, to 2 x 10^4');
      expect([for (final l in data.extraLinesData.horizontalLines) l.y], [0, 10000, 20000]);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('10k'), findsOneWidget);
      expect(find.text('20k'), findsOneWidget);
      final current = data.lineBarsData.last;
      expect(current.curveSmoothness, 0.15);
      expect(current.preventCurveOverShooting, isTrue);
      final dots = [for (final s in current.spots) current.dotData.checkToShowDot(s, current)];
      expect(dots, [for (final s in current.spots) s.y > 0]);
      expect(dots.where((d) => !d), isNotEmpty, reason: 'some days have no sales');
      expect(data.lineBarsData.first.dashArray, isNotNull, reason: 'the previous period dashed');
    }, skip: _skip);

    testWidgets('the legend and the day initials (7d); every 5th date (30d)', (tester) async {
      final log = await _pump(tester);
      expect(find.byKey(const ValueKey('home-chart-legend')), findsOneWidget);
      expect(find.text('Last 7 days'), findsNWidgets(2), reason: 'the period line and the legend');
      expect(find.text('Previous 7 days'), findsOneWidget);
      expect(find.text('W'), findsWidgets, reason: 'Wed 11 Nov, today');
      log.setRange(HomeChartRange.month);
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget, reason: 'today');
      expect(find.text('6'), findsOneWidget);
      expect(find.text('10'), findsNothing, reason: 'not a 5th day back');
    }, skip: _skip);

    testWidgets('a tap shows the day\'s tooltip, a second tap hides it; none while hidden', (tester) async {
      await _pump(tester);
      await tester.tapAt(tester.getBottomRight(find.byType(LineChart)) - const Offset(2, 30));
      await tester.pump();
      expect(_line(tester).showingTooltipIndicators.single.showingSpots.single.x, 6, reason: 'today');
      await tester.tapAt(tester.getBottomRight(find.byType(LineChart)) - const Offset(2, 30));
      await tester.pump();
      expect(_line(tester).showingTooltipIndicators, isEmpty);
      await _pump(tester, hidden: true);
      await tester.tapAt(tester.getBottomRight(find.byType(LineChart)) - const Offset(2, 30));
      await tester.pump();
      expect(_line(tester).showingTooltipIndicators, isEmpty);
      expect(find.text('20k'), findsNothing, reason: 'the shape and the guides, no labels');
      expect(_line(tester).extraLinesData.horizontalLines.length, 3);
    }, skip: _skip);

    testWidgets('empty: the guides and days, one line and Record a sale', (tester) async {
      final log = await _pump(tester, days: _days(empty: true));
      expect(find.text('No sales in the last 7 days'), findsOneWidget);
      expect(_line(tester).extraLinesData.horizontalLines.length, 3);
      expect(find.text('W'), findsWidgets);
      await tester.tap(find.text('Record a sale'));
      expect(log.actions, 1);
    }, skip: _skip);

    testWidgets('Semantics: the summary with the total and best day; without amounts when hidden', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final values = _days().currentSales;
      final total = Money.format(values.fold<double>(0, (a, b) => a + b));
      expect(
        find.bySemanticsLabel(RegExp('^Sales over the last 7 days, total ${RegExp.escape(total)}, highest day ')),
        findsOneWidget,
      );
      await _pump(tester, hidden: true);
      expect(find.bySemanticsLabel('Sales over the last 7 days'), findsOneWidget);
      handle.dispose();
    }, skip: _skip);
  });

  group('Product movement', () {
    testWidgets('top sellers and slow movers; a row opens its product; a gone one does nothing', (tester) async {
      final log = await _pump(tester);
      await _swipe(tester);
      expect(find.text('Top sellers'), findsOneWidget);
      expect(find.text('Slow movers'), findsOneWidget);
      expect(find.text('40 in stock'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('home-top-0'))).height, 48);
      await tester.tap(find.text('Vaccine'));
      await tester.tap(find.text('Gone'));
      await tester.tap(find.text('Bolus'));
      expect(log.opened, ['Vaccine', 'Bolus']);
    }, skip: _skip);

    testWidgets('nothing sold: the line in place of the top sellers, the slow movers still', (tester) async {
      await _pump(tester, movement: HomeMovement(top: const [], slow: [ph4Product('Bolus', qty: 40)]));
      await _swipe(tester);
      expect(find.byKey(const ValueKey('home-chart-nothing-sold')), findsOneWidget);
      expect(find.text('40 in stock'), findsOneWidget);
    }, skip: _skip);

    testWidgets('no products: one line and Add a product; nothing asked', (tester) async {
      final log = await _pump(tester, noProducts: true);
      await _swipe(tester);
      expect(find.text('No products added yet'), findsOneWidget);
      await tester.tap(find.text('Add a product'));
      expect(log.actions, 1);
      expect(log.asked.where((a) => a.startsWith('movement')), isEmpty);
    }, skip: _skip);
  });

  group('Visit activity', () {
    testWidgets('the donut: total visits in the centre, legend counts and shares; a tap shows visits and revenue', (
      tester,
    ) async {
      await _pump(tester);
      await _swipe(tester);
      await _swipe(tester);
      expect(find.text('Visit activity'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('home-chart-donut-count'))).data, '4');
      expect(find.text('3 (75%)'), findsOneWidget);
      expect(find.text('1 (25%)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-chart-slice-1')));
      await tester.pump();
      expect(find.text('Surgery: 1 visit, ${Money.format(80000)}'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('home-chart-donut-count'))).data, '1');
      final pie = tester.widget<PieChart>(find.byType(PieChart)).data;
      expect([for (final s in pie.sections) s.value], [3, 1], reason: 'sized by visits');
    }, skip: _skip);

    testWidgets('hidden amounts: the visits without revenue', (tester) async {
      await _pump(tester, hidden: true);
      await _swipe(tester);
      await _swipe(tester);
      await tester.tap(find.byKey(const ValueKey('home-chart-slice-0')));
      await tester.pump();
      expect(find.text('Vaccination: 3 visits'), findsOneWidget);
    }, skip: _skip);

    testWidgets('empty: a faint ring, one line and Record a visit; the summary says so', (tester) async {
      final handle = tester.ensureSemantics();
      final log = await _pump(tester, slices: const []);
      await _swipe(tester);
      await _swipe(tester);
      expect(find.text('No visits in the last 7 days'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-chart-donut')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^No visits in the last 7 days')), findsWidgets);
      await tester.tap(find.text('Record a visit'));
      expect(log.actions, 1);
      handle.dispose();
    }, skip: _skip);
  });

  test('reads: the 7d pages 2 + 1 + 1 gets, 30d 2 + 1 + 1 more; no listener; again nothing', () async {
    final db = CountingFirestore();
    final f = db.inner.collection(Collections.facilities).doc('f1');
    await f.collection(Collections.sales).add({'timestamp': Timestamp.fromDate(testNow), 'items': const []});
    db.resetCounts();
    final days = HomeChartLoader(firestore: db);
    final windows = InsightsDataLoader(firestore: db);
    Future<void> open(HomeChartRange r) async {
      await days.days('f1', now: testNow, range: r);
      await windows.sales('f1', now: testNow, days: r.days);
      await windows.services('f1', now: testNow, days: r.days);
    }

    await open(HomeChartRange.week);
    expect((db.gets, db.listeners), (4, 0));
    await open(HomeChartRange.week);
    expect(db.gets, 4, reason: 'a return to Home reads nothing');
    await open(HomeChartRange.month);
    expect((db.gets, db.listeners), (8, 0));
    await open(HomeChartRange.month);
    expect(db.gets, 8);
  }, skip: _skip);

  testWidgets('Kiswahili and Dark at the smallest region: no overflow on any page', (tester) async {
    for (final look in [MatrixLook.kiswahili, MatrixLook.dark]) {
      await _pump(
        tester,
        look: look,
        movement: HomeMovement(
          top: [TopSeller(matrixLongProductName, matrixBigAmount, ph4Product('long'))],
          slow: [ph4Product('long')],
        ),
      );
      await _swipe(tester);
      await _swipe(tester);
      expect(tester.takeException(), isNull, reason: look.name);
    }
    expect(Product, isNotNull);
  }, skip: _skip);
}
