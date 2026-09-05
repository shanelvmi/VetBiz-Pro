import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final DateTime date;          // When the transaction occurred
  final String description;
  final double amount;
  final String type;            // 'profit', 'expense', 'outstanding', etc.
  final String category;
  final String recordedBy;      // User ID or name who recorded the transaction
  // Nullable - only meaningful for income (money actually received via
  // some method); an expense has nothing to attach one to.
  final String? paymentMethod;
  final int? receiptNumber;

  TransactionModel({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.recordedBy,
    this.paymentMethod,
    this.receiptNumber,
  });

  /// Converts the TransactionModel instance to a Firestore compatible map
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),  // Store as Firestore Timestamp
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'recordedBy': recordedBy,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (receiptNumber != null) 'receiptNumber': receiptNumber,
    };
  }

  /// Creates a TransactionModel instance from Firestore data
  factory TransactionModel.fromFirestore(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? '',
      category: map['category'] ?? '',
      recordedBy: map['recordedBy'] ?? 'Unknown',
      paymentMethod: map['paymentMethod'] as String?,
      receiptNumber: (map['receiptNumber'] as num?)?.toInt(),
    );
  }

  /// Allows copying the instance with some fields changed
  TransactionModel copyWith({
    String? id,
    DateTime? date,
    String? description,
    double? amount,
    String? type,
    String? category,
    String? recordedBy,
    String? paymentMethod,
    int? receiptNumber,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      recordedBy: recordedBy ?? this.recordedBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
    );
  }
}
