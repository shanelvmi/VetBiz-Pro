import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_summary_service.dart';

/// The set of period-aware ("Today"/"This Week"/etc.) figures the
/// dashboard needs, all sourced from precomputed daily aggregates rather
/// than scanning raw sales/services/transactions.
class DashboardPeriodTotals {
  final double totalSales; // sales made in the period (by sale date)
  final double totalCollected; // actual cash collected in the period
  // (sales + services, via dailyCollections) plus other income
  final double totalProfit; // sales + service + transaction profit for
  // sales/services made in the period (revenue-recognition style, same
  // basis as totalSales - not scoped to when payment was actually
  // received; see totalCollected for the cash-received figure)
  final double totalRealizedProfit; // the portion of totalProfit that's
  // actually cash-backed - collected via a paid sale or a debt repayment,
  // not just billed
  final double totalUnrealizedProfit; // the portion of totalProfit still
  // tied up in unpaid credit - sales/services sold but not yet paid for
  final double netProfit; // the true bottom line: totalProfit + other
  // income - expenses. Unlike totalProfit above, this is what's actually
  // left over once operating costs are accounted for
  final double totalExpenses; // all expense-type transactions in the
  // period (this already includes service-related expenses, since adding
  // a service automatically records an expense transaction - don't add
  // service expenses again separately)
  final int completedServicesCount; // services performed in the period
  final double totalServiceRevenue; // service revenue in the period, on
  // the same revenue-recognition basis as totalSales - separate from
  // totalCollected/totalProfit above, which already fold this in

  const DashboardPeriodTotals({
    required this.totalSales,
    required this.totalCollected,
    required this.totalProfit,
    required this.totalRealizedProfit,
    required this.totalUnrealizedProfit,
    required this.netProfit,
    required this.totalExpenses,
    required this.completedServicesCount,
    required this.totalServiceRevenue,
  });

  static const empty = DashboardPeriodTotals(
    totalSales: 0,
    totalCollected: 0,
    totalProfit: 0,
    totalRealizedProfit: 0,
    totalUnrealizedProfit: 0,
    netProfit: 0,
    totalExpenses: 0,
    completedServicesCount: 0,
    totalServiceRevenue: 0,
  );
}

/// Reads precomputed daily aggregates across sales, services, and
/// transactions and combines them into the dashboard's period-based
/// figures - mirrors the same "read a handful of daily docs, not every
/// raw record" approach used by SalesSummaryService.
class DashboardSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SalesSummaryService _salesSummaryService = SalesSummaryService();

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, double>> _getServiceRangeTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyServiceSummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _fmt(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _fmt(end))
        .get();

    double totalAmount = 0.0;
    double totalServiceProfit = 0.0;
    double totalUnrealizedServiceProfit = 0.0;
    double serviceCount = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalAmount += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      totalServiceProfit += (data['totalServiceProfit'] as num?)?.toDouble() ?? 0.0;
      totalUnrealizedServiceProfit += (data['totalUnrealizedServiceProfit'] as num?)?.toDouble() ?? 0.0;
      serviceCount += (data['serviceCount'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'totalAmount': totalAmount,
      'totalServiceProfit': totalServiceProfit,
      'totalUnrealizedServiceProfit': totalUnrealizedServiceProfit,
      'serviceCount': serviceCount,
    };
  }

  /// Public so other screens (e.g. the Transactions list) can reuse this
  /// instead of summing whatever happens to be paginated/loaded locally.
  Future<Map<String, double>> getTransactionRangeTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    return _getTransactionRangeTotals(facilityId: facilityId, start: start, end: end);
  }

  Future<Map<String, double>> _getTransactionRangeTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyTransactionSummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _fmt(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _fmt(end))
        .get();

    double totalExpense = 0.0;
    double totalProfit = 0.0;
    double totalOtherIncome = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalExpense += (data['totalExpense'] as num?)?.toDouble() ?? 0.0;
      totalProfit += (data['totalProfit'] as num?)?.toDouble() ?? 0.0;
      totalOtherIncome += (data['totalOtherIncome'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'totalExpense': totalExpense,
      'totalProfit': totalProfit,
      'totalOtherIncome': totalOtherIncome,
    };
  }

  /// Live version of getDashboardTotals - re-emits the combined totals
  /// whenever any of the four underlying daily summary collections
  /// change. This is what actually makes the dashboard notice a new
  /// sale/service/transaction as soon as its Cloud Function finishes
  /// writing the relevant daily aggregate - previously this only ever
  /// ran as a one-time fetch, triggered solely by the facility or the
  /// filter chip changing, so recording a sale never refreshed the
  /// numbers on screen until something else happened to trigger a
  /// reload.
  Stream<DashboardPeriodTotals> watchDashboardTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) {
    final startStr = _fmt(start);
    final endStr = _fmt(end);
    final controller = StreamController<DashboardPeriodTotals>();

    Map<String, double> salesTotals = {};
    double collected = 0.0;
    Map<String, double> serviceTotals = {};
    Map<String, double> txTotals = {};
    bool hasSales = false, hasCollected = false, hasService = false, hasTx = false;

    void emit() {
      // Wait for at least one value from each stream before emitting -
      // otherwise the first emission would show a partial (and
      // misleadingly low) total, with whichever streams hadn't
      // responded yet counted as zero.
      if (!(hasSales && hasCollected && hasService && hasTx)) return;
      if (controller.isClosed) return;

      final totalSales = salesTotals['totalAmount'] ?? 0.0;
      final totalOtherIncome = txTotals['totalOtherIncome'] ?? 0.0;
      final totalCollected = collected + totalOtherIncome;
      final totalProfit = (salesTotals['totalProfit'] ?? 0.0) +
          (serviceTotals['totalServiceProfit'] ?? 0.0) +
          (txTotals['totalProfit'] ?? 0.0);
      final totalRealizedProfit = (salesTotals['totalRealizedProfit'] ?? 0.0) +
          (serviceTotals['totalServiceProfit'] ?? 0.0) +
          totalOtherIncome;
      final totalUnrealizedProfit = (salesTotals['totalUnrealizedProfit'] ?? 0.0) +
          (serviceTotals['totalUnrealizedServiceProfit'] ?? 0.0);
      final totalExpenses = txTotals['totalExpense'] ?? 0.0;
      final netProfit = totalProfit + totalOtherIncome - totalExpenses;
      final completedServicesCount = (serviceTotals['serviceCount'] ?? 0.0).toInt();
      final totalServiceRevenue = serviceTotals['totalAmount'] ?? 0.0;

      controller.add(DashboardPeriodTotals(
        totalSales: totalSales,
        totalCollected: totalCollected,
        totalProfit: totalProfit,
        totalRealizedProfit: totalRealizedProfit,
        totalUnrealizedProfit: totalUnrealizedProfit,
        netProfit: netProfit,
        totalExpenses: totalExpenses,
        completedServicesCount: completedServicesCount,
        totalServiceRevenue: totalServiceRevenue,
      ));
    }

    final subs = <StreamSubscription>[];

    subs.add(_firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailySummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .snapshots()
        .listen((snap) {
      double totalAmount = 0.0, totalProfit = 0.0, totalRealizedProfit = 0.0, totalUnrealizedProfit = 0.0;
      for (final doc in snap.docs) {
        final d = doc.data();
        totalAmount += (d['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalProfit += (d['totalProfit'] as num?)?.toDouble() ?? 0.0;
        totalRealizedProfit += (d['totalRealizedProfit'] as num?)?.toDouble() ?? 0.0;
        totalUnrealizedProfit += (d['totalUnrealizedProfit'] as num?)?.toDouble() ?? 0.0;
      }
      salesTotals = {
        'totalAmount': totalAmount,
        'totalProfit': totalProfit,
        'totalRealizedProfit': totalRealizedProfit,
        'totalUnrealizedProfit': totalUnrealizedProfit,
      };
      hasSales = true;
      emit();
    }, onError: controller.addError));

    subs.add(_firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyCollections')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .snapshots()
        .listen((snap) {
      collected = snap.docs.fold(
          0.0, (sum, doc) => sum + ((doc.data()['totalCollected'] as num?)?.toDouble() ?? 0.0));
      hasCollected = true;
      emit();
    }, onError: controller.addError));

    subs.add(_firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyServiceSummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .snapshots()
        .listen((snap) {
      double totalAmount = 0.0, totalServiceProfit = 0.0, serviceCount = 0.0;
      for (final doc in snap.docs) {
        final d = doc.data();
        totalAmount += (d['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalServiceProfit += (d['totalServiceProfit'] as num?)?.toDouble() ?? 0.0;
        serviceCount += (d['serviceCount'] as num?)?.toDouble() ?? 0.0;
      }
      serviceTotals = {
        'totalAmount': totalAmount,
        'totalServiceProfit': totalServiceProfit,
        'serviceCount': serviceCount,
      };
      hasService = true;
      emit();
    }, onError: controller.addError));

    subs.add(_firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('dailyTransactionSummaries')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .snapshots()
        .listen((snap) {
      double totalExpense = 0.0, totalProfit = 0.0, totalOtherIncome = 0.0;
      for (final doc in snap.docs) {
        final d = doc.data();
        totalExpense += (d['totalExpense'] as num?)?.toDouble() ?? 0.0;
        totalProfit += (d['totalProfit'] as num?)?.toDouble() ?? 0.0;
        totalOtherIncome += (d['totalOtherIncome'] as num?)?.toDouble() ?? 0.0;
      }
      txTotals = {'totalExpense': totalExpense, 'totalProfit': totalProfit, 'totalOtherIncome': totalOtherIncome};
      hasTx = true;
      emit();
    }, onError: controller.addError));

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }

  /// Fetch all dashboard flow-metric totals for [facilityId] between
  /// [start] and [end] (inclusive) in one go.
  Future<DashboardPeriodTotals> getDashboardTotals({
    required String facilityId,
    required DateTime start,
    required DateTime end,
  }) async {
    final results = await Future.wait([
      _salesSummaryService.getRangeTotals(facilityId: facilityId, start: start, end: end),
      _salesSummaryService.getTotalCollected(facilityId: facilityId, start: start, end: end),
      _getServiceRangeTotals(facilityId: facilityId, start: start, end: end),
      _getTransactionRangeTotals(facilityId: facilityId, start: start, end: end),
    ]);

    final salesTotals = results[0] as Map<String, double>;
    final collected = results[1] as double;
    final serviceTotals = results[2] as Map<String, double>;
    final txTotals = results[3] as Map<String, double>;

    final totalSales = salesTotals['totalAmount'] ?? 0.0;
    final totalOtherIncome = txTotals['totalOtherIncome'] ?? 0.0;
    final totalCollected = collected + totalOtherIncome;
    final totalProfit = (salesTotals['totalProfit'] ?? 0.0) +
        (serviceTotals['totalServiceProfit'] ?? 0.0) +
        (txTotals['totalProfit'] ?? 0.0);
    final totalRealizedProfit = (salesTotals['totalRealizedProfit'] ?? 0.0) +
        (serviceTotals['totalServiceProfit'] ?? 0.0) +
        totalOtherIncome;
    final totalUnrealizedProfit = (salesTotals['totalUnrealizedProfit'] ?? 0.0) +
        (serviceTotals['totalUnrealizedServiceProfit'] ?? 0.0);
    final totalExpenses = txTotals['totalExpense'] ?? 0.0;
    final netProfit = totalProfit + totalOtherIncome - totalExpenses;
    final completedServicesCount = (serviceTotals['serviceCount'] ?? 0.0).toInt();
    final totalServiceRevenue = serviceTotals['totalAmount'] ?? 0.0;

    return DashboardPeriodTotals(
      totalSales: totalSales,
      totalCollected: totalCollected,
      totalProfit: totalProfit,
      totalRealizedProfit: totalRealizedProfit,
      totalUnrealizedProfit: totalUnrealizedProfit,
      netProfit: netProfit,
      totalExpenses: totalExpenses,
      completedServicesCount: completedServicesCount,
      totalServiceRevenue: totalServiceRevenue,
    );
  }
}
