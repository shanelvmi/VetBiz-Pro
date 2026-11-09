// ignore_for_file: unused_import, unused_field
// HUB2: the API only, so its tests compile (committed skipped); the engine follows.
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

  factory HomeChartDays.empty(DateTime today) => throw UnimplementedError();

  /// Today's values replaced by the live ones the card already holds (the
  /// period totals while the period is Today); null keeps the read's.
  HomeChartDays withToday({double? sales, double? services}) => throw UnimplementedError();

  /// The last 7 days (today last) and the 7 before them.
  List<double> get salesThisWeek => throw UnimplementedError();
  List<double> get salesLastWeek => throw UnimplementedError();
  List<double> get servicesThisWeek => throw UnimplementedError();

  /// The days of [salesThisWeek], for the guide labels and tooltips.
  List<DateTime> get thisWeekDays => throw UnimplementedError();
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

  Future<HomeChartDays> days(String facilityId, {DateTime? now}) => throw UnimplementedError();

  /// Signing out forgets what was read.
  void clear() => _cache.clear();
}
