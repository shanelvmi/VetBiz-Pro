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
  final String? imageUrl; // optional, user-uploaded product photo/icon

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

  // Per-product low-stock threshold - null means "use the facility-wide
  // default" (defaultLowStockThreshold below), not "never low stock".
  final int? minStockLevel;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // The single source of truth for what counts as "low stock" when a
  // product hasn't set its own minStockLevel - every screen that shows
  // a Low Stock badge or count reads this same value (via
  // effectiveMinStockLevel/isLowStock below) instead of each defining
  // its own number, so "Low Stock" never quietly means something
  // different from one screen to the next.
  static const int defaultLowStockThreshold = 5;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.supplier,
    this.batchNo,
    this.expiry,
    this.imageUrl,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQty,
    this.sellableQty = 0, // ⭐ PRO DEFAULT
    required this.unit,
    required this.type,
    required this.category,
    required this.facilityId,
    this.target = ProductTarget.sellable, // backward compatible
    this.minStockLevel,
    this.createdAt,
    this.updatedAt,
  });

  /// ---------- Convenience getters ----------

  String get stockDisplay => '$stockQty $unit';
  String get sellableDisplay => '$sellableQty $unit';

  bool get hasStock => stockQty > 0;
  bool get hasSellable => sellableQty > 0;

  int get effectiveMinStockLevel => minStockLevel ?? defaultLowStockThreshold;

  bool get isLowStock =>
      stockQty <= effectiveMinStockLevel || sellableQty <= effectiveMinStockLevel;

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
      imageUrl: data['imageUrl'],
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
      minStockLevel: (data['minStockLevel'] as num?)?.toInt(),
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
      'imageUrl': imageUrl,
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
      'minStockLevel': minStockLevel,
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
    String? imageUrl,
    double? buyPrice,
    double? sellPrice,
    int? stockQty,
    int? sellableQty,
    String? unit,
    String? type,
    String? category,
    String? facilityId,
    ProductTarget? target,
    int? minStockLevel,
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
      imageUrl: imageUrl ?? this.imageUrl,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQty: stockQty ?? this.stockQty,
      sellableQty: sellableQty ?? this.sellableQty, // ⭐ PRO
      unit: unit ?? this.unit,
      type: type ?? this.type,
      category: category ?? this.category,
      facilityId: facilityId ?? this.facilityId,
      target: target ?? this.target,
      minStockLevel: minStockLevel ?? this.minStockLevel,
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
