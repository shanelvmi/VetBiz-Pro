import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// The three day-counts a single restock frequency choice maps to.
class _RestockDayCounts {
  final int shelfMinDays;
  final int lowStockDays;
  final int reorderDays;

  const _RestockDayCounts({
    required this.shelfMinDays,
    required this.lowStockDays,
    required this.reorderDays,
  });
}

/// Computes usage-based suggested stock thresholds from real sales and
/// service-consumption history, per the agreed design:
/// - No lead-time factor - most agrovets in TZ don't use formal supplier
///   ordering, so thresholds are purely "how many days of typical usage
///   should stay in reserve", not "usage x delivery wait".
/// - A product's own manual override (set on the product itself) always
///   wins over this; these are only ever a fallback, read through
///   Product.effectiveShelfMinLevel/effectiveLowStockThreshold/
///   effectiveReorderPoint - never applied directly.
/// - Computed once (on demand, from this class) and stored on the
///   product document, rather than recalculated live on every screen
///   load - scanning every sale and service for every product on every
///   build would not scale once there's real transaction volume.
///
/// NOTE: this is a client-side, on-demand calculation. Automating it to
/// run on a schedule (e.g. nightly) would mean moving this logic into a
/// Cloud Function instead, matching the pattern already used for daily
/// sales/collections summaries - a reasonable next step, not something
/// this class attempts.
class UsageCalculatorService {
  UsageCalculatorService._();

  /// How many days of past sales/service history to average usage over.
  /// 30 days is a reasonable starting point: short enough to react to a
  /// real change in how a product moves, long enough that one unusually
  /// busy or quiet week doesn't skew the number on its own.
  static const int lookbackDays = 30;

  /// A product needs to have moved at least this many total units over
  /// the lookback window before its calculated usage is trusted. Below
  /// this, there's too little real history to build a meaningful number
  /// from, so the product is left alone entirely - its effective*
  /// getters keep falling back to the flat shared default instead of
  /// being given a suggestion built on almost nothing.
  static const int minUnitsForConfidence = 3;

  static const String defaultRestockFrequency = 'Every 2 Weeks';

  static const List<String> restockFrequencyOptions = [
    'Weekly',
    'Every 2 Weeks',
    'Monthly',
    'Rarely',
  ];

  /// Days of typical usage each threshold represents, per restock
  /// frequency a facility's admin can choose in Facility settings.
  /// Deliberately expressed as a simple, real-world choice ("how often
  /// do you typically restock") rather than asking an admin to type raw
  /// day-counts directly - most people don't think in exact numbers of
  /// days, but do know their own restocking rhythm. "Every 2 Weeks" is
  /// the default (matches this feature's original starting numbers)
  /// for any facility that hasn't set a preference.
  static const Map<String, _RestockDayCounts> _dayCountsByFrequency = {
    'Weekly': _RestockDayCounts(shelfMinDays: 2, lowStockDays: 5, reorderDays: 7),
    'Every 2 Weeks': _RestockDayCounts(shelfMinDays: 3, lowStockDays: 7, reorderDays: 14),
    'Monthly': _RestockDayCounts(shelfMinDays: 5, lowStockDays: 10, reorderDays: 21),
    'Rarely': _RestockDayCounts(shelfMinDays: 7, lowStockDays: 14, reorderDays: 30),
  };

  /// Queries sales and service-consumption history for [facilityId] over
  /// [lookbackDays], and returns average daily usage per product ID.
  /// Products that haven't moved at least [minUnitsForConfidence] total
  /// units in that window are omitted from the result entirely, so
  /// callers know to leave those products' computed thresholds alone.
  static Future<Map<String, double>> calculateAverageDailyUsage(
    String facilityId,
  ) async {
    final cutoff = DateTime.now().subtract(const Duration(days: lookbackDays));
    final cutoffTimestamp = Timestamp.fromDate(cutoff);
    final totalUnitsByProduct = <String, int>{};

    // Sales - each line item carries its own quantity.
    final salesSnap = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('sales')
        .where('timestamp', isGreaterThanOrEqualTo: cutoffTimestamp)
        .get();

    for (final doc in salesSnap.docs) {
      final items = (doc.data()['items'] as List?) ?? const [];
      for (final rawItem in items) {
        final item = rawItem as Map<String, dynamic>;
        final productId = item['productId'] as String?;
        if (productId == null) continue;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        totalUnitsByProduct[productId] = (totalUnitsByProduct[productId] ?? 0) + quantity;
      }
    }

    // Service-consumed stock - e.g. a vaccine used during a visit rather
    // than sold directly. Each itemsUsed entry with a productId is
    // exactly one unit (ServiceProvider always deducts quantity: 1 per
    // entry; there's no separate quantity field on these items), so this
    // counts entries rather than summing a quantity field.
    final servicesSnap = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('services')
        .where('serviceDate', isGreaterThanOrEqualTo: cutoffTimestamp)
        .get();

    for (final doc in servicesSnap.docs) {
      final items = (doc.data()['itemsUsed'] as List?) ?? const [];
      for (final rawItem in items) {
        final item = rawItem as Map<String, dynamic>;
        final productId = item['productId'] as String?;
        if (productId == null) continue;
        totalUnitsByProduct[productId] = (totalUnitsByProduct[productId] ?? 0) + 1;
      }
    }

    final result = <String, double>{};
    totalUnitsByProduct.forEach((productId, totalUnits) {
      if (totalUnits >= minUnitsForConfidence) {
        result[productId] = totalUnits / lookbackDays;
      }
    });
    return result;
  }

  /// Computes and saves suggested thresholds for every product in
  /// [products] that has enough real usage history (see
  /// [minUnitsForConfidence]). Products without enough history are left
  /// completely untouched - not reset, not zeroed - so their
  /// effective*Level getters continue falling back to whatever they
  /// already resolve to (a manual override if set, otherwise the flat
  /// shared default). Returns how many products were actually updated.
  /// [restockFrequency] should be one of [restockFrequencyOptions] - an
  /// unrecognized value falls back to [defaultRestockFrequency], same as
  /// a facility that hasn't set a preference at all.
  static Future<int> recalculateForFacility(
    String facilityId,
    List<Product> products, {
    String restockFrequency = defaultRestockFrequency,
  }) async {
    final usageByProduct = await calculateAverageDailyUsage(facilityId);
    if (usageByProduct.isEmpty) return 0;

    final dayCounts = _dayCountsByFrequency[restockFrequency] ??
        _dayCountsByFrequency[defaultRestockFrequency]!;

    final batch = FirebaseFirestore.instance.batch();
    var updatedCount = 0;

    for (final product in products) {
      final avgDailyUsage = usageByProduct[product.id];
      if (avgDailyUsage == null) continue; // not enough history - leave alone

      final docRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(product.id);

      batch.update(docRef, {
        'computedShelfMinLevel': (avgDailyUsage * dayCounts.shelfMinDays).ceil(),
        'computedLowStockThreshold': (avgDailyUsage * dayCounts.lowStockDays).ceil(),
        'computedReorderPoint': (avgDailyUsage * dayCounts.reorderDays).ceil(),
        'thresholdsComputedAt': FieldValue.serverTimestamp(),
      });
      updatedCount++;
    }

    if (updatedCount > 0) await batch.commit();
    return updatedCount;
  }
}
