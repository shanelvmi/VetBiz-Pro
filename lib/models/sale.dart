import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double costPrice;
  final String unit;
  // The product's category at the time of sale (e.g. "Antibiotics") -
  // snapshotted here the same way name/unitPrice already are, so it
  // stays accurate on this receipt even if the product's category is
  // later changed or the product itself is deleted. Empty for sales
  // made before this field existed.
  final String category;

  final double realizedProfit; // profit received from payment
  final double unrealizedProfit; // profit tied up in credit

  // Which batch(es) this line's quantity was actually deducted from, and
  // how much from each (FIFO - soonest expiry first) - recorded at sale
  // time so deleting the sale later can restore exactly those amounts to
  // exactly those batches, not just bump a generic total. Empty for
  // sales made before batch tracking existed.
  final List<Map<String, dynamic>> batchAllocations;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    this.costPrice = 0.0,
    this.unit = '',
    this.category = '',
    this.realizedProfit = 0.0,
    double? unrealizedProfit,
    this.batchAllocations = const [],
  }) : unrealizedProfit =
            unrealizedProfit ?? ((unitPrice - costPrice) * quantity - discount);

  double get profit => (unitPrice - costPrice) * quantity - discount;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'costPrice': costPrice,
      'unit': unit,
      'category': category,
      'realizedProfit': realizedProfit,
      'unrealizedProfit': unrealizedProfit,
      'batchAllocations': batchAllocations,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final quantity = (map['quantity'] is int)
        ? map['quantity'] as int
        : int.tryParse('${map['quantity']}') ?? 1;
    final unitPrice = (map['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final costPrice = (map['costPrice'] as num?)?.toDouble() ?? 0.0;
    final discount = (map['discount'] as num?)?.toDouble() ?? 0.0;
    final rawAllocations = map['batchAllocations'] as List<dynamic>? ?? [];

    return SaleItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
      costPrice: costPrice,
      unit: map['unit'] as String? ?? '',
      category: map['category'] as String? ?? '',
      batchAllocations: rawAllocations
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      realizedProfit: (map['realizedProfit'] as num?)?.toDouble() ?? 0.0,
      unrealizedProfit: (map['unrealizedProfit'] as num?)?.toDouble() ??
          ((unitPrice - costPrice) * quantity - discount),
    );
  }

  SaleItem copyWith({
    String? productId,
    String? name,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? costPrice,
    String? unit,
    String? category,
    double? realizedProfit,
    double? unrealizedProfit,
    List<Map<String, dynamic>>? batchAllocations,
  }) {
    return SaleItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      costPrice: costPrice ?? this.costPrice,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      realizedProfit: realizedProfit ?? this.realizedProfit,
      unrealizedProfit: unrealizedProfit ?? this.unrealizedProfit,
      batchAllocations: batchAllocations ?? this.batchAllocations,
    );
  }
}

class Sale {
  final String id;
  final String? clientId;
  final String? clientName;
  final DateTime timestamp;
  final DateTime updatedAt;
  final List<SaleItem> items;
  final double totalAmount;
  final double totalPaid;
  final String facilityId;
  final String soldById;
  final String soldByName;
  final bool saleOnCredit;
  final double totalProfit;
  final double realizedProfit;
  final double unrealizedProfit;
  // Nullable - a fully-on-credit sale (totalPaid == 0) has nothing
  // paid yet, so no method to record. Set at the moment of the actual
  // payment, whether that's the full amount at sale time or a partial
  // one settled later via applyPayment.
  final String? paymentMethod;
  // Nullable - assigned by SaleProvider at creation time via the
  // shared, atomic receipt-numbering counter, not set by callers
  // directly. Sales made before this feature existed have none.
  final int? receiptNumber;
  // Optional free-text note set at sale creation time. Sales made
  // before this field existed have none.
  final String? notes;

  const Sale({
    required this.id,
    this.clientId,
    this.clientName,
    required this.timestamp,
    required this.updatedAt,
    required this.items,
    required this.totalAmount,
    required this.totalPaid,
    required this.facilityId,
    required this.soldById,
    required this.soldByName,
    this.saleOnCredit = false,
    this.totalProfit = 0.0,
    this.realizedProfit = 0.0,
    this.unrealizedProfit = 0.0,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
  });

  /// Apply a payment and recalc realized/unrealized profit
  Sale applyPayment(double amount) {
    final newTotalPaid = totalPaid + amount;

    // Payment ratio progress (increment only)
    final oldRatio = (totalPaid / (totalAmount > 0 ? totalAmount : 1.0))
        .clamp(0.0, 1.0);
    final newRatio = (newTotalPaid / (totalAmount > 0 ? totalAmount : 1.0))
        .clamp(0.0, 1.0);
    final paymentRatioIncrement = newRatio - oldRatio;

    final updatedItems = items.map((item) {
      double realizedIncrease = item.profit * paymentRatioIncrement;
      double newRealized = item.realizedProfit + realizedIncrease;
      double newUnrealized = item.unrealizedProfit - realizedIncrease;

      // If fully paid, fix rounding issues: all realized, none unrealized
      if (newTotalPaid >= totalAmount) {
        newRealized = item.profit;
        newUnrealized = 0.0;
      }

      return item.copyWith(
        realizedProfit: newRealized,
        unrealizedProfit: newUnrealized,
      );
    }).toList();

    final totalRealized =
        updatedItems.fold(0.0, (sum, i) => sum + (i.realizedProfit));
    final totalUnrealized =
        updatedItems.fold(0.0, (sum, i) => sum + (i.unrealizedProfit));

    return copyWith(
      totalPaid: newTotalPaid,
      items: updatedItems,
      realizedProfit: totalRealized,
      unrealizedProfit: totalUnrealized,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (clientId != null) 'clientId': clientId,
      if (clientName != null) 'clientName': clientName,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'totalPaid': totalPaid,
      'facilityId': facilityId,
      'soldById': soldById,
      'soldByName': soldByName,
      'saleOnCredit': saleOnCredit,
      'totalProfit': totalProfit,
      'realizedProfit': realizedProfit,
      'unrealizedProfit': unrealizedProfit,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (receiptNumber != null) 'receiptNumber': receiptNumber,
      if (notes != null) 'notes': notes,
    };
  }

  factory Sale.fromFirestore(Map<String, dynamic>? map, String id) {
    if (map == null) throw ArgumentError('Map cannot be null for Sale');

    final itemsList = (map['items'] as List?)
            ?.map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    double totalProfit = itemsList.fold(0.0, (sum, item) => sum + item.profit);
    double realized =
        itemsList.fold(0.0, (sum, item) => sum + item.realizedProfit);
    double unrealized =
        itemsList.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

    DateTime timestamp = DateTime.now();
    final rawTs = map['timestamp'];
    if (rawTs != null) {
      if (rawTs is Timestamp) {
        timestamp = rawTs.toDate();
      } else if (rawTs is String) {
        timestamp = DateTime.tryParse(rawTs) ?? DateTime.now();
      }
    }

    DateTime updatedAt = timestamp;
    final rawUpdated = map['updatedAt'];
    if (rawUpdated != null) {
      if (rawUpdated is Timestamp) {
        updatedAt = rawUpdated.toDate();
      } else if (rawUpdated is String) {
        updatedAt = DateTime.tryParse(rawUpdated) ?? timestamp;
      }
    }

    return Sale(
      id: id,
      clientId: map['clientId'] as String?,
      clientName: map['clientName'] as String?,
      timestamp: timestamp,
      updatedAt: updatedAt,
      items: itemsList,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      facilityId: map['facilityId'] as String? ?? '',
      soldById: map['soldById'] as String? ?? '',
      soldByName: map['soldByName'] as String? ?? '',
      saleOnCredit: map['saleOnCredit'] as bool? ?? false,
      totalProfit: (map['totalProfit'] as num?)?.toDouble() ?? totalProfit,
      realizedProfit:
          (map['realizedProfit'] as num?)?.toDouble() ?? realized,
      unrealizedProfit:
          (map['unrealizedProfit'] as num?)?.toDouble() ?? unrealized,
      paymentMethod: map['paymentMethod'] as String?,
      receiptNumber: (map['receiptNumber'] as num?)?.toInt(),
      notes: map['notes'] as String?,
    );
  }

  Sale copyWith({
    String? id,
    String? clientId,
    String? clientName,
    DateTime? timestamp,
    DateTime? updatedAt,
    List<SaleItem>? items,
    double? totalAmount,
    double? totalPaid,
    String? facilityId,
    String? soldById,
    String? soldByName,
    bool? saleOnCredit,
    double? totalProfit,
    double? realizedProfit,
    double? unrealizedProfit,
    String? paymentMethod,
    int? receiptNumber,
    String? notes,
  }) {
    return Sale(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      facilityId: facilityId ?? this.facilityId,
      soldById: soldById ?? this.soldById,
      soldByName: soldByName ?? this.soldByName,
      saleOnCredit: saleOnCredit ?? this.saleOnCredit,
      totalProfit: totalProfit ?? this.totalProfit,
      realizedProfit: realizedProfit ?? this.realizedProfit,
      unrealizedProfit: unrealizedProfit ?? this.unrealizedProfit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
    );
  }
}
