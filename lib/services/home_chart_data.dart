import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_ranges.dart';
import '../data/collections.dart';

/// HUB2: the 14 days Home's Sales and Vet services charts draw, oldest
/// first: the last entry is today. Sales by sale date (dailySummaries),
/// service revenue by service date (dailyServiceSummaries), the same basis
/// as the period totals.
class HomeChartDays {
  static const int length = 14;
  static const int week = 7;

  /// The first of the 14 days (today minus 13).
  final DateTime firstDay;
  final List<double> sales;
  final List<double> services;

  const HomeChartDays({required this.firstDay, required this.sales, required this.services});

  factory HomeChartDays.empty(DateTime today) => HomeChartDays(
        firstDay: today.subtract(AppRanges.day * (length - 1)),
        sales: List.filled(length, 0),
        services: List.filled(length, 0),
      );

  /// Today's values replaced by the live ones the card already holds (the
  /// period totals while the period is Today); null keeps the read's.
  HomeChartDays withToday({double? sales, double? services}) => HomeChartDays(
        firstDay: firstDay,
        sales: [...this.sales.take(length - 1), sales ?? this.sales.last],
        services: [...this.services.take(length - 1), services ?? this.services.last],
      );

  /// The last 7 days (today last) and the 7 before them.
  List<double> get salesThisWeek => sales.sublist(week);
  List<double> get salesLastWeek => sales.sublist(0, week);
  List<double> get servicesThisWeek => services.sublist(week);

  /// The days of [salesThisWeek], for the guide labels and tooltips.
  List<DateTime> get thisWeekDays => [for (var i = week; i < length; i++) firstDay.add(AppRanges.day * i)];
}

/// HUB2: reads the 14 days once per facility and day, ONE range get of each
/// daily summary collection (at most 14 documents each, no listener), and
/// keeps the answer in memory for the session: both chart pages share it, a
/// return to Home costs nothing. A failed read is not kept, so the next
/// visit asks again.
class HomeChartLoader {
  final FirebaseFirestore? _injected;
  final Map<String, Future<HomeChartDays>> _cache = {};

  // [firestore] is for tests (the counting fake).
  HomeChartLoader({FirebaseFirestore? firestore}) : _injected = firestore;

  /// The app's one loader.
  static final HomeChartLoader shared = HomeChartLoader();

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<HomeChartDays> days(String facilityId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final today = DateTime(at.year, at.month, at.day);
    final cacheKey = '$facilityId|${_key(today)}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final future = _read(facilityId, today);
    _cache[cacheKey] = future;
    future.catchError((Object _) {
      _cache.remove(cacheKey);
      return HomeChartDays.empty(today);
    });
    return future;
  }

  Future<HomeChartDays> _read(String facilityId, DateTime today) async {
    final first = today.subtract(AppRanges.day * (HomeChartDays.length - 1));
    Future<List<double>> perDay(String collection) async {
      final snap = await _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(collection)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: _key(first))
          .where(FieldPath.documentId, isLessThanOrEqualTo: _key(today))
          .get();
      final out = List<double>.filled(HomeChartDays.length, 0);
      for (final doc in snap.docs) {
        final day = DateTime.tryParse(doc.id);
        if (day == null) continue;
        final i = DateTime(day.year, day.month, day.day).difference(first).inDays;
        if (i < 0 || i >= HomeChartDays.length) continue;
        out[i] += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      }
      return out;
    }

    final results = await Future.wait([perDay(Collections.dailySummaries), perDay(Collections.dailyServiceSummaries)]);
    return HomeChartDays(firstDay: first, sales: results[0], services: results[1]);
  }

  /// Signing out forgets what was read.
  void clear() => _cache.clear();
}
