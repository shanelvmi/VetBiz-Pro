import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String category;
  final String name;
  final String description;

  final double totalAmount;
  final double totalPaid;

  final String? clientId;
  final String? clientName;
  final DateTime? serviceDate;
  final String? providedByName;
  final DateTime? updatedAt;

  final List<Map<String, dynamic>> itemsUsed;

  // Stored in Firestore for reporting
  final double totalServiceProfit;

  // Nullable - a service not yet paid at all has nothing to record a
  // method for. Set at the moment of the actual payment, whether
  // that's the full amount up front or a partial one settled later.
  final String? paymentMethod;

  // Nullable - assigned by ServiceProvider at creation time via the
  // shared, atomic receipt-numbering counter (same sequence as sales),
  // not set by callers directly. Services made before this feature
  // existed have none.
  final int? receiptNumber;

  // The M-Pesa payment confirmation code (e.g. "RBH7F3K92M"), entered
  // when the payment method is M-Pesa. Nullable - any other payment
  // method, or a service not yet paid, has nothing to record here.
  final String? transactionId;

  Service({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.totalAmount,
    required this.totalPaid,
    this.clientId,
    this.clientName,
    this.serviceDate,
    this.providedByName,
    this.updatedAt,
    this.itemsUsed = const [],
    this.totalServiceProfit = 0.0,
    this.paymentMethod,
    this.receiptNumber,
    this.transactionId,
  });

  /// ---------- FROM FIRESTORE ----------
  factory Service.fromFirestore(Map<String, dynamic> data, String id) {
    final List<Map<String, dynamic>> parsedItems =
        (data['itemsUsed'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];

    return Service(
      id: id,
      category: data['category'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      totalPaid: (data['totalPaid'] ?? 0).toDouble(),
      clientId: data['clientId'],
      clientName: data['clientName'],
      serviceDate: data['serviceDate'] != null
          ? (data['serviceDate'] as Timestamp).toDate()
          : null,
      providedByName: data['providedByName'],
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      itemsUsed: parsedItems,
      totalServiceProfit:
          (data['totalServiceProfit'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] as String?,
      receiptNumber: (data['receiptNumber'] as num?)?.toInt(),
      transactionId: data['transactionId'] as String?,
    );
  }

  /// ---------- TO FIRESTORE ----------
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'name': name,
      'description': description,
      'totalAmount': totalAmount,
      'totalPaid': totalPaid,
      'clientId': clientId,
      'clientName': clientName,
      'serviceDate':
          serviceDate != null ? Timestamp.fromDate(serviceDate!) : null,
      'providedByName': providedByName,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'itemsUsed': itemsUsed,
      'totalServiceProfit': totalServiceProfit,
      'paymentMethod': paymentMethod,
      'receiptNumber': receiptNumber,
      'transactionId': transactionId,
    };
  }

  /// ---------- EXPENSES ----------
  double get totalExpenses {
    return itemsUsed.fold(0.0, (sum, item) {
      final p = item['price'] ?? 0.0;
      return sum + (p is int ? p.toDouble() : p);
    });
  }

  /// Of totalExpenses, only the portion that should actually become a new
  /// cash expense transaction - items matched to a real product (via
  /// `productId`) came out of stock you already paid for when it was
  /// purchased, so recording them again here would double-count the cost.
  /// Only externally-bought items / plain costs (fare, etc. - no
  /// productId) count as a new expense.
  double get externalExpenseTotal {
    return itemsUsed.fold(0.0, (sum, item) {
      if (item['productId'] != null) return sum;
      final p = item['price'] ?? 0.0;
      return sum + (p is int ? p.toDouble() : p);
    });
  }

  /// ---------- LIVE PROFIT (UI) ----------
  double get computedServiceProfit => totalPaid - totalExpenses;

  /// ---------- COPY ----------
  Service copyWith({
    String? id,
    String? category,
    String? name,
    String? description,
    double? totalAmount,
    double? totalPaid,
    String? clientId,
    String? clientName,
    DateTime? serviceDate,
    String? providedByName,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? itemsUsed,
    String? paymentMethod,
    int? receiptNumber,
    String? transactionId,
  }) {
    final newPaid = totalPaid ?? this.totalPaid;
    final newItems = itemsUsed ?? this.itemsUsed;

    final newExpenses = newItems.fold(0.0, (sum, item) {
      final p = item['price'] ?? 0.0;
      return sum + (p is int ? p.toDouble() : p);
    });

    return Service(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      totalPaid: newPaid,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      serviceDate: serviceDate ?? this.serviceDate,
      providedByName: providedByName ?? this.providedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      itemsUsed: newItems,
      totalServiceProfit: newPaid - newExpenses, // ALWAYS recomputed
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}
