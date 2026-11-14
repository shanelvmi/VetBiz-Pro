import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import 'insights_data_loader.dart';

/// HUB4: one of Home's top sellers: the stored item name, the quantity sold
/// in the period, and the product it was sold as (by the sale item's
/// productId, else by name) for its image and details page; null when the
/// product is gone or the item had no match.
class TopSeller {
  final String name;
  final double quantity;
  final Product? product;

  const TopSeller(this.name, this.quantity, this.product);
}

/// HUB4: Home's Product movement page: up to [HomeMovement.topCount] top
/// sellers by quantity and up to [HomeMovement.slowCount] slow movers
/// (products in stock that sold nothing in the period).
class HomeMovement {
  static const int topCount = 5;
  static const int slowCount = 3;

  final List<TopSeller> top;
  final List<Product> slow;

  const HomeMovement({required this.top, required this.slow});

  bool get soldNothing => top.isEmpty;
}

/// HUB4: the movement of the period starting [since] (inclusive), from the
/// sales window already read (InsightsDataLoader) and the [products]
/// already held: no read of its own. The top sellers are
/// topProductsByQuantity's (Insights' grouping by item name: largest first,
/// a tie by name). A slow mover has stock (shelf plus store) and no sale
/// item in the period, by productId or by name; the most stock first, a tie
/// by name.
HomeMovement homeMovement(List<Map<String, dynamic>> sales, List<Product> products, {required DateTime since}) {
  final top = topProductsByQuantity(sales, since: since, count: HomeMovement.topCount);
  final soldIds = <String>{};
  final idByName = <String, String>{};
  final soldNames = <String>{};
  for (final sale in sales) {
    final at = sale['timestamp'];
    final when = at is Timestamp ? at.toDate() : null;
    if (when == null || when.isBefore(since)) continue;
    for (final item in sale['items'] as List<dynamic>? ?? const []) {
      if (item is! Map) continue;
      final id = item['productId'] as String?;
      final name = (item['name'] as String?) ?? ProductMovement.unknownName;
      if (((item['quantity'] as num?) ?? 0) <= 0) continue;
      soldNames.add(name);
      if (id != null) {
        soldIds.add(id);
        idByName.putIfAbsent(name, () => id);
      }
    }
  }
  final byId = {for (final p in products) p.id: p};
  Product? productFor(String name) =>
      byId[idByName[name]] ?? products.where((p) => p.name == name).firstOrNull;
  final slow = [
    for (final p in products)
      if (p.totalStock > 0 && !soldIds.contains(p.id) && !soldNames.contains(p.name)) p,
  ]..sort((a, b) => a.totalStock != b.totalStock ? b.totalStock.compareTo(a.totalStock) : a.name.compareTo(b.name));
  return HomeMovement(
    top: [for (final m in top) TopSeller(m.name, m.quantity, productFor(m.name))],
    slow: slow.take(HomeMovement.slowCount).toList(),
  );
}
