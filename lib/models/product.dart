import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines where the product belongs (UI / grouping purpose)
enum ProductTarget {
  stockStore,
  sellable,
}

/// The primary, mutually-exclusive stock status for a product - in strict
/// severity order. [neverStocked] is a special case: a brand-new product
/// that's never had any stock at all reads very differently from one that
/// genuinely ran out, so it's kept separate and expected to be hidden from
/// status displays entirely rather than shown as "Depleted".
enum ProductStockStatus {
  neverStocked,
  depleted,
  lowStock,
  reorderSoon,
  inStock,
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

  // Three separate thresholds, each answering a different business
  // question - null means "use the shared default" for that specific
  // threshold, not "no threshold at all". They're deliberately
  // independent rather than one shared number, since "when do I move
  // stock to the shelf", "when am I genuinely low", and "when do I plan
  // a purchase" are different decisions with different answers.
  final int? shelfMinLevel;    // "When should I refill the shelf?"
  final int? lowStockThreshold; // "When is total stock critically low?"
  final int? reorderPoint;     // "When should I start planning a purchase?"

  // Usage-based suggested thresholds, computed from real sales + service
  // consumption history (see UsageCalculatorService) and stored here
  // rather than computed live, since the effective*/primaryStatus
  // getters below are synchronous and called throughout the UI, while
  // the underlying Firestore queries are not. Only used as a fallback
  // when the product hasn't set its own explicit override above.
  final int? computedShelfMinLevel;
  final int? computedLowStockThreshold;
  final int? computedReorderPoint;
  final DateTime? thresholdsComputedAt;

  // True the moment this product has ever carried non-zero stock (set at
  // creation if the initial quantity was > 0, or the first time stock is
  // later added). Lets a brand-new, never-stocked product at 0 be told
  // apart from one that genuinely ran out - see ProductStockStatus.
  final bool hasEverHadStock;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Shared fallback defaults, used only when a product hasn't set its
  // own threshold. Every screen that shows a stock status reads through
  // the same effective*/primaryStatus getters below instead of each
  // defining its own comparison, so "Low Stock" (or any other status)
  // never quietly means something different from one screen to the next.
  // Flat starting numbers for now - Phase 3 replaces these with numbers
  // computed from each product's own real usage history.
  static const int defaultShelfMinLevel = 3;
  static const int defaultLowStockThreshold = 5;
  static const int defaultReorderPoint = 10;

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
    this.shelfMinLevel,
    this.lowStockThreshold,
    this.reorderPoint,
    this.computedShelfMinLevel,
    this.computedLowStockThreshold,
    this.computedReorderPoint,
    this.thresholdsComputedAt,
    this.hasEverHadStock = false,
    this.createdAt,
    this.updatedAt,
  });

  /// ---------- Convenience getters ----------

  String get stockDisplay => '$stockQty $unit';
  String get sellableDisplay => '$sellableQty $unit';

  bool get hasStock => stockQty > 0;
  bool get hasSellable => sellableQty > 0;

  int get totalStock => stockQty + sellableQty;

  int get effectiveShelfMinLevel =>
      shelfMinLevel ?? computedShelfMinLevel ?? defaultShelfMinLevel;
  int get effectiveLowStockThreshold =>
      lowStockThreshold ?? computedLowStockThreshold ?? defaultLowStockThreshold;
  int get effectiveReorderPoint =>
      reorderPoint ?? computedReorderPoint ?? defaultReorderPoint;

  /// The single primary status, following the agreed severity hierarchy:
  /// neverStocked (hidden case) > depleted > low stock > reorder soon >
  /// in stock. Callers that want to hide neverStocked products from a
  /// status display should check for that case explicitly - it's kept
  /// as part of the enum rather than returning null, so "what status is
  /// this product in" always has one clear, single answer.
  ProductStockStatus get primaryStatus {
    if (totalStock == 0) {
      return hasEverHadStock ? ProductStockStatus.depleted : ProductStockStatus.neverStocked;
    }
    if (totalStock <= effectiveLowStockThreshold) return ProductStockStatus.lowStock;
    if (totalStock <= effectiveReorderPoint) return ProductStockStatus.reorderSoon;
    return ProductStockStatus.inStock;
  }

  /// A separate, non-exclusive operational signal from primaryStatus -
  /// "move stock to the shelf", not "buy more". Only true when the
  /// warehouse genuinely has enough to bring the shelf back up to its
  /// own minimum; a warehouse with only 1 unit left shouldn't count as
  /// "sufficient backup" just because it's non-zero.
  bool get hasRestockShelfAlert {
    final deficit = effectiveShelfMinLevel - sellableQty;
    if (deficit <= 0) return false; // shelf is already at/above its minimum
    return stockQty >= deficit;
  }

  // Retained for any code not yet migrated to primaryStatus/
  // hasRestockShelfAlert - true whenever either quantity is low, same
  // meaning it always had. New code should prefer primaryStatus instead,
  // since this collapses several genuinely different situations into one
  // flag.
  bool get isLowStock =>
      primaryStatus == ProductStockStatus.lowStock ||
      primaryStatus == ProductStockStatus.depleted;

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
      shelfMinLevel: (data['shelfMinLevel'] as num?)?.toInt(),
      lowStockThreshold: (data['lowStockThreshold'] as num?)?.toInt() ??
          (data['minStockLevel'] as num?)?.toInt(), // migrate the old single field's meaning
      reorderPoint: (data['reorderPoint'] as num?)?.toInt(),
      computedShelfMinLevel: (data['computedShelfMinLevel'] as num?)?.toInt(),
      computedLowStockThreshold: (data['computedLowStockThreshold'] as num?)?.toInt(),
      computedReorderPoint: (data['computedReorderPoint'] as num?)?.toInt(),
      thresholdsComputedAt: data['thresholdsComputedAt'] != null
          ? (data['thresholdsComputedAt'] as Timestamp).toDate()
          : null,
      hasEverHadStock: (data['hasEverHadStock'] as bool?) ??
          (((data['stockQty'] ?? 0) as num).toInt() > 0 || ((data['sellableQty'] ?? 0) as num).toInt() > 0),
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
      'shelfMinLevel': shelfMinLevel,
      'lowStockThreshold': lowStockThreshold,
      'reorderPoint': reorderPoint,
      'computedShelfMinLevel': computedShelfMinLevel,
      'computedLowStockThreshold': computedLowStockThreshold,
      'computedReorderPoint': computedReorderPoint,
      'thresholdsComputedAt':
          thresholdsComputedAt != null ? Timestamp.fromDate(thresholdsComputedAt!) : null,
      'hasEverHadStock': hasEverHadStock,
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
    int? shelfMinLevel,
    int? lowStockThreshold,
    int? reorderPoint,
    int? computedShelfMinLevel,
    int? computedLowStockThreshold,
    int? computedReorderPoint,
    DateTime? thresholdsComputedAt,
    bool? hasEverHadStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final resolvedStockQty = stockQty ?? this.stockQty;
    final resolvedSellableQty = sellableQty ?? this.sellableQty;
    // A one-way flag deliberately: once stock has ever been non-zero, it
    // stays true even if the caller doesn't pass it explicitly - never
    // silently reset back to false by an unrelated edit.
    final resolvedHasEverHadStock = hasEverHadStock ??
        (this.hasEverHadStock || resolvedStockQty > 0 || resolvedSellableQty > 0);

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
      stockQty: resolvedStockQty,
      sellableQty: resolvedSellableQty, // ⭐ PRO
      unit: unit ?? this.unit,
      type: type ?? this.type,
      category: category ?? this.category,
      facilityId: facilityId ?? this.facilityId,
      target: target ?? this.target,
      shelfMinLevel: shelfMinLevel ?? this.shelfMinLevel,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      computedShelfMinLevel: computedShelfMinLevel ?? this.computedShelfMinLevel,
      computedLowStockThreshold: computedLowStockThreshold ?? this.computedLowStockThreshold,
      computedReorderPoint: computedReorderPoint ?? this.computedReorderPoint,
      thresholdsComputedAt: thresholdsComputedAt ?? this.thresholdsComputedAt,
      hasEverHadStock: resolvedHasEverHadStock,
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
