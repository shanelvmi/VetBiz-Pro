import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String clientId;
  final String? debtId;
  final String? saleId;
  final String? serviceId;
  final List<Map<String, dynamic>> items;
  final double amount;
  final DateTime timestamp;
  final String? paidById;
  final String? clientName;
  final String? clientPhone;

  Payment({
    required this.id,
    required this.clientId,
    this.debtId,
    this.saleId,
    this.serviceId,
    this.items = const [],
    required this.amount,
    required this.timestamp,
    this.paidById,
    this.clientName,
    this.clientPhone,
  });

  factory Payment.fromFirestore(Map<String, dynamic> data, String id,
      {String? clientName, String? clientPhone}) {
    return Payment(
      id: id,
      clientId: data['clientId'] ?? '',
      debtId: data['debtId'] as String?,
      saleId: data['saleId'] as String?,
      serviceId: data['serviceId'] as String?,
      items: (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidById: data['paidById'] as String?,
      clientName: clientName,
      clientPhone: clientPhone,
    );
  }
}
