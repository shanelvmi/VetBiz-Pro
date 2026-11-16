// HUB4 (1)(5): the data behind Home's three chart pages: the 7d | 30d range
// and its persistence, the 30-day read (60 days, one range get of each daily
// summary, kept for the session, asked only for 30d), the clean scale (1, 2
// or 5 times a power of ten), the product ranking (ties, fewer than five)
// and the slow movers (stock and nothing sold), and the services breakdown
// that Home's donut and Insights' donut share, against Insights' old inline
// logic for the same fixtures.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/home_movement.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';

import 'helpers/counting_firestore.dart';

final _now = DateTime(2026, 11, 10, 15, 30);
final _today = DateTime(2026, 11, 10);

String _day(int back) {
  final d = _today.subtract(Duration(days: back));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Timestamp _at(int back) => Timestamp.fromDate(_today.subtract(Duration(days: back)).add(const Duration(hours: 9)));

Map<String, dynamic> _sale(int back, List<(String, num, String?)> items) => {
      'timestamp': _at(back),
      'items': [
        for (final (name, qty, id) in items) {'name': name, 'quantity': qty, if (id != null) 'productId': id},
      ],
    };

Product _product(String id, {int shelf = 0, int store = 0, String? name}) => Product(
      id: id,
      name: name ?? id,
      buyPrice: 1000,
      sellPrice: 1500,
      stockQty: store,
      sellableQty: shelf,
      unit: 'pcs',
      type: 'Drug',
      category: 'Drugs',
      facilityId: 'f1',
    );

Map<String, dynamic> _service(int back, String? name, num amount) =>
    {'serviceDate': _at(back), if (name != null) 'name': name, 'totalAmount': amount};

/// Insights' donut data as it was computed inline before HUB4 (a copy, for
/// the same-numbers check).
List<MapEntry<String, double>> _insightsBefore(List<Map<String, dynamic>> services) {
  final serviceRevenue = <String, double>{};
  for (final data in services) {
    final name = (data['name'] as String?);
    final key = (name == null || name.isEmpty) ? 'Other' : name;
    serviceRevenue[key] = (serviceRevenue[key] ?? 0) + ((data['totalAmount'] as num?)?.toDouble() ?? 0.0);
  }
  final sorted = serviceRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final rest = sorted.skip(5).fold<double>(0.0, (t, e) => t + e.value);
  return [...sorted.take(5), if (rest > 0) MapEntry('Other', rest)];
}

void main() {
  group('the range', () {
    test('the stored values, in order, never change', () {
      expect(HomeChartRange.values.map((r) => r.key), ['7d', '30d']);
      expect(HomeChartRange.values.map((r) => r.days), [7, 30]);
      expect(HomeChartRange.fromKey(null), HomeChartRange.week);
      expect(HomeChartRange.fromKey('90d'), HomeChartRange.week);
    });

    testWidgets('7d by default; a choice is saved and read back', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final first = UiSettingsProvider();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      expect(first.homeChartRange, HomeChartRange.week);
      await tester.runAsync(() => first.setHomeChartRange(HomeChartRange.month));
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString('ui_home_chart_range'), '30d');
      final again = UiSettingsProvider();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      expect(again.homeChartRange, HomeChartRange.month);
    });
  });

  group('the 30-day read', () {
    Future<CountingFirestore> seed() async {
      final db = CountingFirestore();
      final f = db.inner.collection(Collections.facilities).doc('f1');
      for (var back = 0; back < 61; back++) {
        await f.collection(Collections.dailySummaries).doc(_day(back)).set({'totalAmount': 100.0 * (back + 1)});
      }
      await f.collection(Collections.dailyServiceSummaries).doc(_day(45)).set({'totalAmount': 900.0});
      db.resetCounts();
      return db;
    }

    test('60 days in one range get of each summary; the 30 shown and the 30 before', () async {
      final db = await seed();
      final days = await HomeChartLoader(firestore: db).days('f1', now: _now, range: HomeChartRange.month);
      expect(db.gets, 2);
      expect(db.reads, 61, reason: '60 sales days and one service day; the 61st day back is not read');
      expect(days.span, 30);
      expect(days.firstDay, _today.subtract(const Duration(days: 59)));
      expect(days.currentSales.length, 30);
      expect(days.currentSales.last, 100.0);
      expect(days.previousSales.first, 6000.0);
      expect(days.currentDays.first, _today.subtract(const Duration(days: 29)));
      expect(days.currentDays.last, _today);
      expect(days.services[14], 900.0, reason: '45 days back is in the previous 30');
    });

    test('kept for the session per range; 7d stays its own 14-day read', () async {
      final db = await seed();
      final loader = HomeChartLoader(firestore: db);
      await loader.days('f1', now: _now, range: HomeChartRange.month);
      await loader.days('f1', now: _now, range: HomeChartRange.month);
      expect(db.gets, 2);
      final week = await loader.days('f1', now: _now);
      expect(db.gets, 4);
      expect(week.span, 7);
      expect(week.currentSales, week.salesThisWeek);
      expect(week.previousSales, week.salesLastWeek);
    });

    test('today from the live totals keeps the span', () {
      final d = HomeChartDays.empty(_today, span: 30).withToday(sales: 500);
      expect(d.sales.length, 60);
      expect(d.currentSales.last, 500);
      expect(d.span, 30);
    });

    test('the shared sales window: 7d reads Insights\' own, 30d its own window', () async {
      final db = CountingFirestore();
      final loader = InsightsDataLoader(firestore: db);
      await loader.sales('f1', now: _now, days: 7);
      await loader.sales('f1', now: _now);
      expect(db.gets, 1, reason: '7 days are inside Insights\' 14');
      await loader.sales('f1', now: _now, days: 30);
      expect(db.gets, 2);
      expect(InsightsDataLoader.windowStart(now: _now, days: 30), _today.subtract(const Duration(days: 29)));
    });
  });

  group('the scale', () {
    test('a clean maximum: 1, 2 or 5 times a power of ten', () {
      expect(homeChartNiceMax(0), 1);
      expect(homeChartNiceMax(8), 10);
      expect(homeChartNiceMax(18000), 20000);
      expect(homeChartNiceMax(22000), 50000);
      expect(homeChartNiceMax(50000), 50000);
      expect(homeChartNiceMax(51000), 100000);
      expect(homeChartNiceMax(12345678), 20000000);
    });
  });

  group('product movement', () {
    final since = _today.subtract(const Duration(days: 6));

    test('ranked by quantity, a tie by name, at most five; matched products', () {
      final sales = [
        _sale(0, [('Dewormer', 4, 'p2'), ('Vaccine', 9, 'p1')]),
        _sale(1, [('Bandage', 4, null), ('Acaricide', 4, 'p4'), ('Syringe', 1, 'p5'), ('Gloves', 2, 'p6')]),
        _sale(9, [('Syringe', 100, 'p5')]),
      ];
      final products = [_product('p1', name: 'Vaccine'), _product('p2', name: 'Dewormer'), _product('p9', name: 'Bandage')];
      final m = homeMovement(sales, products, since: since);
      expect([for (final t in m.top) t.name], ['Vaccine', 'Acaricide', 'Bandage', 'Dewormer', 'Gloves']);
      expect(m.top.first.quantity, 9);
      expect(m.top.first.product?.id, 'p1');
      expect(m.top[2].product?.id, 'p9', reason: 'no productId: matched by name');
      expect(m.top[1].product, isNull, reason: 'gone from the products held');
    });

    test('fewer than five sold: only those', () {
      final m = homeMovement([_sale(0, [('Vaccine', 2, 'p1')])], const [], since: since);
      expect(m.top.length, 1);
      expect(m.soldNothing, isFalse);
    });

    test('slow movers: stock greater than zero and nothing sold; most stock first, at most three', () {
      final sales = [_sale(0, [('Vaccine', 2, 'p1')]), _sale(1, [('Renamed', 1, 'p2')])];
      final products = [
        _product('p1', shelf: 50, name: 'Vaccine'),
        _product('p2', shelf: 40, name: 'Dewormer'),
        _product('p3', name: 'Empty'),
        _product('p4', shelf: 5, store: 5, name: 'Bolus'),
        _product('p5', store: 30, name: 'Acaricide'),
        _product('p6', shelf: 10, name: 'Antibiotic'),
        _product('p7', shelf: 1, name: 'Zinc'),
      ];
      final m = homeMovement(sales, products, since: since);
      expect([for (final p in m.slow) p.id], ['p5', 'p6', 'p4'],
          reason: 'p1 and p2 sold (p2 by id), p3 has none, a tie by name, Zinc is the fourth');
    });

    test('nothing sold: no top sellers, the slow movers still', () {
      final m = homeMovement([_sale(10, [('Vaccine', 2, 'p1')])], [_product('p1', shelf: 3, name: 'Vaccine')], since: since);
      expect(m.soldNothing, isTrue);
      expect([for (final p in m.slow) p.id], ['p1']);
    });
  });

  group('the services breakdown', () {
    final fixtures = [
      for (var i = 0; i < 3; i++) _service(i, 'Vaccination', 10000),
      _service(1, 'Deworming', 25000),
      _service(2, 'Surgery', 80000),
      _service(3, 'Consultation', 5000),
      _service(3, 'Consultation', 5000),
      _service(4, 'Dipping', 2000),
      _service(5, 'Castration', 1500),
      _service(5, null, 1000),
      _service(6, '', 500),
      _service(12, 'Surgery', 60000),
    ];

    test('the same numbers as Insights\' donut for the same fixtures', () {
      final shared = [
        for (final s in serviceBreakdownOf(fixtures))
          if (!s.tail || s.revenue > 0) MapEntry(s.key, s.revenue),
      ];
      final before = _insightsBefore(fixtures);
      expect([for (final e in shared) '${e.key}=${e.value}'], [for (final e in before) '${e.key}=${e.value}']);
    });

    test('counts and revenue per type; top five, then the rest as one tail', () {
      final slices = serviceBreakdownOf(fixtures, since: _today.subtract(const Duration(days: 6)));
      expect(slices, const [
        ServiceSlice('Surgery', 1, 80000),
        ServiceSlice('Vaccination', 3, 30000),
        ServiceSlice('Deworming', 1, 25000),
        ServiceSlice('Consultation', 2, 10000),
        ServiceSlice('Dipping', 1, 2000),
        ServiceSlice('Other', 3, 3000, tail: true),
      ]);
      expect(slices.fold<int>(0, (n, s) => n + s.count), 11, reason: 'every visit of the 7 days counted');
    });

    test('nothing in the period: no slices', () {
      expect(serviceBreakdownOf(fixtures, since: _today.add(const Duration(days: 1))), isEmpty);
    });
  });
}
