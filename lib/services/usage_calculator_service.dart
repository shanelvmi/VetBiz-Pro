import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../config/restock_rules.dart';
import '../data/collections.dart';

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

  /// The restock numbers live in RestockRules (lib/config/restock_rules.dart);
  /// these names are kept for the screens and the code below that use them.
  static const int lookbackDays = RestockRules.usageLookbackDays;
  static const int minUnitsForConfidence = RestockRules.minUnitsForConfidence;
  static const String defaultRestockFrequency = RestockRules.defaultFrequency;
  static const List<String> restockFrequencyOptions = RestockRules.frequencies;

  /// Queries sales and service-consumption history for [facilityId] over
  /// [lookbackDays], and returns average daily usage per product ID.
  /// Products that haven't moved at least [minUnitsForConfidence] total
  /// units in that window are omitted from the result entirely, so
  /// callers know to leave those products' computed thresholds alone.
  static Future<Map<String, double>> calculateAverageDailyUsage(
    String facilityId,
  ) async {
    final cutoff = DateTime.now().subtract(RestockRules.usageLookback);
    final cutoffTimestamp = Timestamp.fromDate(cutoff);
    final totalUnitsByProduct = <String, int>{};

    // Sales - each line item carries its own quantity.
    final salesSnap = await FirebaseFirestore.instance
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.sales)
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
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.services)
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

    final dayCounts = RestockRules.dayCountsByFrequency[restockFrequency] ??
        RestockRules.dayCountsByFrequency[defaultRestockFrequency]!;

    final batch = FirebaseFirestore.instance.batch();
    var updatedCount = 0;

    for (final product in products) {
      final avgDailyUsage = usageByProduct[product.id];
      if (avgDailyUsage == null) continue; // not enough history - leave alone

      final docRef = FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.products)
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
