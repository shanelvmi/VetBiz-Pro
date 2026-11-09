import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_ranges.dart';
import '../data/collections.dart';

/// HUB2: the sales and services of Insights' window (today and the 13 days
/// before it), each read once per facility and day and kept in memory for
/// the session. Insights and Home's Product movement page share it, so a
/// second visit (or the other screen) costs nothing. A failed read is not
/// kept.
class InsightsDataLoader {
  final FirebaseFirestore? _injected;
  final Map<String, Future<List<Map<String, dynamic>>>> _cache = {};

  // [firestore] is for tests (the counting fake).
  InsightsDataLoader({FirebaseFirestore? firestore}) : _injected = firestore;

  /// The app's one loader.
  static final InsightsDataLoader shared = InsightsDataLoader();

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  /// The first day of the window for [now] (Insights' trend start).
  static DateTime windowStart({DateTime? now}) {
    final at = now ?? DateTime.now();
    return DateTime(at.year, at.month, at.day).subtract(AppRanges.insightsTrendBack);
  }

  /// The window's sales (the documents' data), by `timestamp`.
  Future<List<Map<String, dynamic>>> sales(String facilityId, {DateTime? now}) =>
      _load(facilityId, Collections.sales, 'timestamp', windowStart(now: now));

  /// The window's services (the documents' data), by `serviceDate`.
  Future<List<Map<String, dynamic>>> services(String facilityId, {DateTime? now}) =>
      _load(facilityId, Collections.services, 'serviceDate', windowStart(now: now));

  Future<List<Map<String, dynamic>>> _load(String facilityId, String collection, String field, DateTime start) {
    final key = '$facilityId|$collection|${start.toIso8601String()}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final future = _db
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(collection)
        .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get()
        .then((snap) => [for (final doc in snap.docs) doc.data()]);
    _cache[key] = future;
    future.catchError((Object _) {
      _cache.remove(key);
      return <Map<String, dynamic>>[];
    });
    return future;
  }

  /// Signing out forgets what was read.
  void clear() => _cache.clear();
}

/// HUB2: one product's quantity sold, for Home's Product movement page.
/// [name] is the stored item name ('Unknown' when a sale item had none, as
/// Insights groups it).
class ProductMovement {
  final String name;
  final double quantity;

  const ProductMovement(this.name, this.quantity);

  @override
  bool operator ==(Object other) => other is ProductMovement && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);

  @override
  String toString() => 'ProductMovement($name, $quantity)';
}

/// The [count] products sold in the largest quantity in [sales] since
/// [since] (inclusive), largest first; a tie goes by name, so the order is
/// stable. Fewer when fewer were sold.
List<ProductMovement> topProductsByQuantity(List<Map<String, dynamic>> sales,
    {required DateTime since, int count = 5}) {
  final quantities = <String, double>{};
  for (final sale in sales) {
    final at = sale['timestamp'];
    final when = at is Timestamp ? at.toDate() : null;
    if (when == null || when.isBefore(since)) continue;
    for (final item in sale['items'] as List<dynamic>? ?? const []) {
      if (item is! Map) continue;
      final name = (item['name'] as String?) ?? 'Unknown';
      quantities[name] = (quantities[name] ?? 0) + ((item['quantity'] as num?)?.toDouble() ?? 0);
    }
  }
  final sorted = [
    for (final e in quantities.entries)
      if (e.value > 0) ProductMovement(e.key, e.value),
  ]..sort((a, b) => a.quantity != b.quantity ? b.quantity.compareTo(a.quantity) : a.name.compareTo(b.name));
  return sorted.take(count).toList();
}
