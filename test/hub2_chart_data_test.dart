// HUB2 (3): the data behind Home's chart pages, against fixtures: the 14
// days of sales and services (one range get of each daily summary, once per
// session), today replaced by the live totals, the top 5 products by
// quantity in the last 7 days (ties, fewer than 5, older sales left out),
// and the Insights window shared with Insights (read once).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';

import 'helpers/counting_firestore.dart';

const _skip = true;

final _now = DateTime(2026, 11, 10, 15, 30);
final _today = DateTime(2026, 11, 10);

String _day(int back) {
  final d = _today.subtract(Duration(days: back));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<CountingFirestore> _seedDays() async {
  final db = CountingFirestore();
  final f = db.inner.collection(Collections.facilities).doc('f1');
  // Sales: 1000 x (back + 1) for each of the 14 days, and one day too old.
  for (var back = 0; back < 15; back++) {
    await f.collection(Collections.dailySummaries).doc(_day(back)).set({'totalAmount': 1000.0 * (back + 1)});
  }
  // Services on three days only.
  await f.collection(Collections.dailyServiceSummaries).doc(_day(0)).set({'totalAmount': 500.0});
  await f.collection(Collections.dailyServiceSummaries).doc(_day(3)).set({'totalAmount': 700.0});
  await f.collection(Collections.dailyServiceSummaries).doc(_day(10)).set({'totalAmount': 900.0});
  db.resetCounts();
  return db;
}

Map<String, dynamic> _sale(int back, List<(String?, num)> items) => {
      'timestamp': Timestamp.fromDate(_today.subtract(Duration(days: back)).add(const Duration(hours: 9))),
      'items': [
        for (final (name, qty) in items) {if (name != null) 'name': name, 'quantity': qty, 'unitPrice': 100, 'discount': 0},
      ],
    };

void main() {
  group('HomeChartLoader', () {
    test('the 14 days, oldest first, today last; sales and services per day', () async {
      final db = await _seedDays();
      final days = await HomeChartLoader(firestore: db).days('f1', now: _now);
      expect(days.firstDay, _today.subtract(const Duration(days: 13)));
      expect(days.sales, [for (var back = 13; back >= 0; back--) 1000.0 * (back + 1)]);
      expect(days.salesThisWeek, [7000.0, 6000.0, 5000.0, 4000.0, 3000.0, 2000.0, 1000.0]);
      expect(days.salesLastWeek, [14000.0, 13000.0, 12000.0, 11000.0, 10000.0, 9000.0, 8000.0]);
      expect(days.servicesThisWeek, [0.0, 0.0, 0.0, 700.0, 0.0, 0.0, 500.0]);
      expect(days.services[3], 900.0, reason: '10 days back is in last week');
      expect(days.thisWeekDays.last, _today);
    }, skip: _skip);

    test('today comes from the live totals when given; the read\'s otherwise', () async {
      final db = await _seedDays();
      final days = await HomeChartLoader(firestore: db).days('f1', now: _now);
      final live = days.withToday(sales: 4321, services: 99);
      expect(live.salesThisWeek.last, 4321.0);
      expect(live.servicesThisWeek.last, 99.0);
      expect(live.salesThisWeek.first, days.salesThisWeek.first);
      expect(days.withToday().sales, days.sales);
    }, skip: _skip);

    test('one range get of each summary, once: a second call and the other page read nothing', () async {
      final db = await _seedDays();
      final loader = HomeChartLoader(firestore: db);
      await loader.days('f1', now: _now);
      expect(db.gets, 2, reason: 'dailySummaries and dailyServiceSummaries, one range get each');
      expect(db.reads, 14 + 3, reason: 'the 14 days of sales (not the 15th), the 3 service days');
      expect(db.listeners, 0);
      final (gets, reads) = (db.gets, db.reads);
      await loader.days('f1', now: _now.add(const Duration(hours: 1)));
      await Future.wait([loader.days('f1', now: _now), loader.days('f1', now: _now)]);
      expect((db.gets, db.reads), (gets, reads), reason: 'cached for the session');
      // A new day reads the new 14 days.
      await loader.days('f1', now: _now.add(const Duration(days: 1)));
      expect(db.gets, gets + 2);
    }, skip: _skip);

    test('no documents: zeros; a failed read is not kept', () async {
      final db = CountingFirestore();
      final loader = HomeChartLoader(firestore: db);
      db.failGets = true;
      await expectLater(loader.days('f1', now: _now), throwsA(isA<FirebaseException>()));
      db.failGets = false;
      final days = await loader.days('f1', now: _now);
      expect(days.sales, List.filled(14, 0.0));
      expect(days.services, List.filled(14, 0.0));
    }, skip: _skip);
  });

  group('topProductsByQuantity', () {
    final since = _today.subtract(const Duration(days: 6));

    test('the top 5 by quantity in the last 7 days, largest first, ties by name', () {
      final sales = [
        _sale(0, [('Dewormer', 5), ('Vitamins', 2)]),
        _sale(2, [('Dewormer', 3), ('Feed 50kg', 8), ('Acaricide', 4)]),
        _sale(6, [('Syringe', 4), ('Gloves', 1), ('Vitamins', 1)]),
        _sale(7, [('Old product', 100)]), // 7 days back: last week
        _sale(1, [(null, 2)]),
      ];
      expect(topProductsByQuantity(sales, since: since), const [
        ProductMovement('Dewormer', 8),
        ProductMovement('Feed 50kg', 8),
        ProductMovement('Acaricide', 4),
        ProductMovement('Syringe', 4),
        ProductMovement('Vitamins', 3),
      ]);
    }, skip: _skip);

    test('fewer than 5 sold: only those; none: empty', () {
      expect(topProductsByQuantity([_sale(1, [('Dewormer', 2)]), _sale(1, [(null, 1)])], since: since),
          const [ProductMovement('Dewormer', 2), ProductMovement('Unknown', 1)]);
      expect(topProductsByQuantity([_sale(9, [('Dewormer', 2)])], since: since), isEmpty);
      expect(topProductsByQuantity(const [], since: since), isEmpty);
    }, skip: _skip);
  });

  group('InsightsDataLoader', () {
    test('Insights\' window, each collection read once and shared', () async {
      final db = CountingFirestore();
      final f = db.inner.collection(Collections.facilities).doc('f1');
      await f.collection(Collections.sales).add(_sale(1, [('Dewormer', 2)]));
      await f.collection(Collections.sales).add(_sale(20, [('Too old', 2)]));
      await f.collection(Collections.services).add({'serviceDate': Timestamp.fromDate(_today), 'totalAmount': 5000});
      db.resetCounts();
      final loader = InsightsDataLoader(firestore: db);

      // Home's Product movement page asks for the sales only.
      final sales = await loader.sales('f1', now: _now);
      expect(sales, hasLength(1));
      expect(db.gets, 1);
      // Insights then: its sales cost nothing, its services one get.
      await Future.wait([loader.sales('f1', now: _now), loader.services('f1', now: _now)]);
      expect(db.gets, 2);
      await loader.services('f1', now: _now);
      expect(db.gets, 2);
      expect(db.listeners, 0);
    }, skip: _skip);

    test('the window starts 13 days before today, as Insights\' trend', () {
      expect(InsightsDataLoader.windowStart(now: _now), DateTime(2026, 10, 28));
    }, skip: _skip);
  });
}
