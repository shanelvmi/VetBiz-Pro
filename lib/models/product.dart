import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines where the product belongs (UI / grouping purpose)
enum ProductTarget {
  stockStore,
  sellable,
}

class Product {
  final String id;
  final String name;
  final String? description;
  final String? supplier;
  final String? batchNo;
  final DateTime? expiry;

  final double buyPrice;
  final double sellPrice;

  /// Quantities
  int stockQty;        // 🏬 Warehouse / Store room
  int sellableQty;     // 🛒 Front shop / POS  ⭐ PRO

  final String unit;      // kg, pcs, litres, etc.
  final String type;      // Injectable, Feed, etc.
  final String category;  // Antibiotics, Supplements, etc.
  final String facilityId;

  /// Used for UI grouping (kept for backward compatibility)
  final ProductTarget target;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.supplier,
    this.batchNo,
    this.expiry,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQty,
    this.sellableQty = 0, // ⭐ PRO DEFAULT
    required this.unit,
    required this.type,
    required this.category,
    required this.facilityId,
    this.target = ProductTarget.sellable, // backward compatible
    this.createdAt,
    this.updatedAt,
  });

  /// ---------- Convenience getters ----------

  String get stockDisplay => '$stockQty $unit';
  String get sellableDisplay => '$sellableQty $unit';

  bool get hasStock => stockQty > 0;
  bool get hasSellable => sellableQty > 0;

  /// ---------- Firestore → Model ----------

  factory Product.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'],
      supplier: data['supplier'],
      batchNo: data['batchNo'],
      expiry: data['expiry'] != null
          ? (data['expiry'] as Timestamp).toDate()
          : null,
      buyPrice: (data['buyPrice'] ?? 0).toDouble(),
      sellPrice: (data['sellPrice'] ?? 0).toDouble(),
      stockQty: (data['stockQty'] ?? 0).toInt(),
      sellableQty: (data['sellableQty'] ?? 0).toInt(), // ⭐ PRO
      unit: data['unit'] ?? '',
      type: data['type'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      facilityId: data['facilityId'] ?? '',
      target: _targetFromString(data['target']),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// ---------- Model → Firestore ----------

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'supplier': supplier,
      'batchNo': batchNo,
      'expiry': expiry != null ? Timestamp.fromDate(expiry!) : null,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'stockQty': stockQty,
      'sellableQty': sellableQty, // ⭐ PRO
      'unit': unit,
      'type': type,
      'category': category,
      'facilityId': facilityId,
      'target': target.name,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// ---------- Copy helper ----------

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? supplier,
    String? batchNo,
    DateTime? expiry,
    double? buyPrice,
    double? sellPrice,
    int? stockQty,
    int? sellableQty,
    String? unit,
    String? type,
    String? category,
    String? facilityId,
    ProductTarget? target,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      supplier: supplier ?? this.supplier,
      batchNo: batchNo ?? this.batchNo,
      expiry: expiry ?? this.expiry,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQty: stockQty ?? this.stockQty,
      sellableQty: sellableQty ?? this.sellableQty, // ⭐ PRO
      unit: unit ?? this.unit,
      type: type ?? this.type,
      category: category ?? this.category,
      facilityId: facilityId ?? this.facilityId,
      target: target ?? this.target,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// ---------- Helpers ----------

  static ProductTarget _targetFromString(dynamic value) {
    if (value == null) return ProductTarget.sellable;

    return ProductTarget.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProductTarget.sellable,
    );
  }
}
