// ignore_for_file: unused_import, unused_field
// HUB2: the API only, so its tests compile (committed skipped); the engine follows.
import 'package:cloud_firestore/cloud_firestore.dart';


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

  /// The first day of the window for [now] (Insights' trend start).
  static DateTime windowStart({DateTime? now}) => throw UnimplementedError();

  /// The window's sales (the documents' data), by `timestamp`.
  Future<List<Map<String, dynamic>>> sales(String facilityId, {DateTime? now}) => throw UnimplementedError();

  /// The window's services (the documents' data), by `serviceDate`.
  Future<List<Map<String, dynamic>>> services(String facilityId, {DateTime? now}) => throw UnimplementedError();

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
    {required DateTime since, int count = 5}) =>
    throw UnimplementedError();
