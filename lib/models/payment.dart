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
  final String? paymentMethod;
  // Where this payment actually came from - 'sale' (the upfront amount
  // collected on a cash or partial-credit sale), 'service' (same, for
  // services), or 'debt_repayment' (a later payment against an
  // existing debt via AddPaymentScreen). Written by all three real
  // write sites already; now actually read back into this object too,
  // rather than only ever existing in the raw Firestore document.
  final String? source;

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
    this.paymentMethod,
    this.source,
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
      // clientName/clientPhone: prefer what's actually on the document
      // itself (written directly at payment-creation time by all three
      // sites) over the constructor's own optional override, which
      // only exists for callers that don't have the document's own
      // copy of these fields to hand.
      clientName: (data['clientName'] as String?) ?? clientName,
      clientPhone: (data['clientPhone'] as String?) ?? clientPhone,
      paymentMethod: data['paymentMethod'] as String?,
      source: data['source'] as String?,
    );
  }

  /// Matches exactly what the three real write sites (SaleProvider,
  /// ServiceProvider, AddPaymentScreen) already write inline - kept
  /// here now as the one, shared definition instead of three separately
  /// hand-written maps that could drift from each other and from this
  /// model's own fields.
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      if (debtId != null) 'debtId': debtId,
      if (saleId != null) 'saleId': saleId,
      if (serviceId != null) 'serviceId': serviceId,
      'items': items,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      if (paidById != null) 'paidById': paidById,
      if (clientName != null) 'clientName': clientName,
      if (clientPhone != null) 'clientPhone': clientPhone,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (source != null) 'source': source,
    };
  }

  /// Lowercased copy of clientName - the field a real, prefix-based
  /// Firestore search runs against, same reasoning as every other
  /// module this session. Never read back into this Dart object, only
  /// written alongside toMap().
  Map<String, dynamic> searchFields() {
    return {'clientNameLower': (clientName ?? '').toLowerCase()};
  }
}
