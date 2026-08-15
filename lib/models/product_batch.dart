import 'package:cloud_firestore/cloud_firestore.dart';

/// One physical batch of stock for a product - its own batch number,
/// expiry, buy price, and remaining quantity. A product can have many of
/// these over time (each new delivery is its own batch), so adding new
/// stock with a different expiry never overwrites an existing batch's
/// real expiry date - it just creates another one alongside it.
class ProductBatch {
  final String id;
  final String productId;
  final String? batchNo;
  final DateTime? expiry;
  final double buyPrice;
  int stockQty;    // remaining in the warehouse for this specific batch
  int sellableQty; // remaining on the shelf for this specific batch
  final DateTime? receivedAt;

  ProductBatch({
    required this.id,
    required this.productId,
    this.batchNo,
    this.expiry,
    required this.buyPrice,
    required this.stockQty,
    this.sellableQty = 0,
    this.receivedAt,
  });

  factory ProductBatch.fromFirestore(Map<String, dynamic> data, String id, String productId) {
    return ProductBatch(
      id: id,
      productId: productId,
      batchNo: data['batchNo'],
      expiry: data['expiry'] != null ? (data['expiry'] as Timestamp).toDate() : null,
      buyPrice: (data['buyPrice'] ?? 0).toDouble(),
      stockQty: (data['stockQty'] ?? 0).toInt(),
      sellableQty: (data['sellableQty'] ?? 0).toInt(),
      receivedAt: data['receivedAt'] != null ? (data['receivedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batchNo': batchNo,
      'expiry': expiry != null ? Timestamp.fromDate(expiry!) : null,
      'buyPrice': buyPrice,
      'stockQty': stockQty,
      'sellableQty': sellableQty,
      'receivedAt': receivedAt != null ? Timestamp.fromDate(receivedAt!) : FieldValue.serverTimestamp(),
    };
  }

  ProductBatch copyWith({
    String? batchNo,
    DateTime? expiry,
    double? buyPrice,
    int? stockQty,
    int? sellableQty,
  }) {
    return ProductBatch(
      id: id,
      productId: productId,
      batchNo: batchNo ?? this.batchNo,
      expiry: expiry ?? this.expiry,
      buyPrice: buyPrice ?? this.buyPrice,
      stockQty: stockQty ?? this.stockQty,
      sellableQty: sellableQty ?? this.sellableQty,
      receivedAt: receivedAt,
    );
  }
}
