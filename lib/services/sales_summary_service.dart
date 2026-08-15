import 'package:cloud_firestore/cloud_firestore.dart';

/// One precomputed daily aggregate for a facility, written incrementally by
/// the `updateDailySalesSummary` Cloud Function on every sale write.
class DailySalesSummary {
  final String date; // YYYY-MM-DD
  final double totalAmount;
  final double totalPaid;
  final double totalProfit;
  final int saleCount;

  const DailySalesSummary({
    required this.date,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalProfit,
    required this.saleCount,
  });

  factory DailySalesSummary.fromFirestore(Map<String, dynamic> map, String id) {
    return DailySalesSummary(
      date: map['date'] as String? ?? id,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (map['totalProfit'] as num?)?.toDouble() ?? 0.0,
      saleCount: (map['saleCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One precomputed daily cash-collection aggregate, written incrementally
/// by the `updateDailyCollections` Cloud Function whenever a payment is
/// recorded - whether that's the upfront amount on a new sale, or a later
/// debt repayment. Unlike [DailySalesSummary] (which is keyed to when a
/// sale was made), this is keyed to when money actually changed hands.
class DailyCollection {
  final String date; // YYYY-MM-DD
  final double totalCollected;
  final int paymentCount;

  const DailyCollection({
    required this.date,
    required this.totalCollected,
    required this.paymentCount,
  });

  factory DailyCollection.fromFirestore(Map<String, dynamic> map, String id) {
    return DailyCollection(
      date: map['date'] as String? ?? id,
      totalCollected: (map['totalCollected'] as num?)?.toDouble() ?? 0.0,
      paymentCount: (map['paymentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reads precomputed daily sales aggregates instead of scanning raw sale
/// documents. A dashboard covering, say, a full year only needs up to ~365
/// document reads here (one per day that had activity) no matter how many
/// individual sales happened - versus reading every sale ever made.
class SalesSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Fetch daily summaries for [facilityId] between [start] and [end]
  /// (inclusive), sorted by date ascending.
  Future<List<DailySalesSummary>> getDailySummaries({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailySummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _fmt(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _fmt(end))
        .get();

    final summaries = snapshot.docs
        .map((doc) => DailySalesSummary.fromFirestore(doc.data(), doc.id))
        .toList();
    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  /// Convenience: totals across a date range from the precomputed summaries.
  Future<Map<String, double>> getRangeTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final summaries =
        await getDailySummaries(facilityId: facilityId, start: start, end: end);

    return {
      'totalAmount': summaries.fold(0.0, (sum, s) => sum + s.totalAmount),
      'totalPaid': summaries.fold(0.0, (sum, s) => sum + s.totalPaid),
      'totalProfit': summaries.fold(0.0, (sum, s) => sum + s.totalProfit),
      'saleCount': summaries.fold(0.0, (sum, s) => sum + s.saleCount),
    };
  }

  /// Fetch daily cash-collection aggregates for [facilityId] between
  /// [start] and [end] (inclusive), sorted by date ascending.
  Future<List<DailyCollection>> getDailyCollections({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyCollections')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _fmt(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _fmt(end))
        .get();

    final collections = snapshot.docs
        .map((doc) => DailyCollection.fromFirestore(doc.data(), doc.id))
        .toList();
    collections.sort((a, b) => a.date.compareTo(b.date));
    return collections;
  }

  /// Convenience: total cash actually collected across a date range -
  /// answers "how much money came in during this period", regardless of
  /// which sale (or how old) it was paid against.
  Future<double> getTotalCollected({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final collections =
        await getDailyCollections(facilityId: facilityId, start: start, end: end);
    return collections.fold<double>(0.0, (sum, c) => sum + c.totalCollected);
  }
}
