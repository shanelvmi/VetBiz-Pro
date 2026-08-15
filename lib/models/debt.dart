import 'package:cloud_firestore/cloud_firestore.dart';

class Debt {
  final String id;
  final String clientId;
  final String? clientName;
  final String? clientPhone;
  final String? saleId;       // sale reference
  final String? serviceId;    // service reference
  final String source;        // 'Sale' or 'Service'
  final double amountOwed;
  final DateTime timestamp;
  final DateTime updatedAt;
  final List<dynamic> items;

  Debt({
    required this.id,
    required this.clientId,
    this.clientName,
    this.clientPhone,
    this.saleId,
    this.serviceId,
    required this.source,
    required this.amountOwed,
    required this.timestamp,
    required this.updatedAt,
    required this.items,
  });

  /// ✅ Save cleanly to Firestore (timestamps as Timestamp, not string)
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'saleId': saleId,
      'serviceId': serviceId,
      'source': source,
      'amountOwed': amountOwed,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'items': items.map((e) => e is Map ? e : e.toString()).toList(),
    };
  }

  /// ✅ Read from Firestore safely
  factory Debt.fromMap(String id, Map<String, dynamic> map) {
    double parseAmount(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return Debt(
      id: id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] as String?,
      clientPhone: map['clientPhone'] as String?,
      saleId: map['saleId'],
      serviceId: map['serviceId'],
      source: map['source'] ?? 'Sale',
      amountOwed: parseAmount(map['amountOwed']),
      timestamp: parseDate(map['timestamp']),
      updatedAt: parseDate(map['updatedAt']),
      items: List<dynamic>.from(map['items'] ?? []),
    );
  }

  Debt copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? saleId,
    String? serviceId,
    String? source,
    double? amountOwed,
    DateTime? timestamp,
    DateTime? updatedAt,
    List<dynamic>? items,
  }) {
    return Debt(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      saleId: saleId ?? this.saleId,
      serviceId: serviceId ?? this.serviceId,
      source: source ?? this.source,
      amountOwed: amountOwed ?? this.amountOwed,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}
