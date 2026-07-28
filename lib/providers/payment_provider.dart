import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment.dart';
import 'sale_provider.dart';
import 'service_provider.dart';

class PaymentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Payment> _payments = [];
  List<Payment> get payments => [..._payments];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Listen to all payments for a facility
  void listenToPayments(String facilityId) {
    _subscription?.cancel();
    if (facilityId.isEmpty) return;

    _subscription = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _payments = snapshot.docs
          .map((doc) => Payment.fromFirestore(doc.data(), doc.id))
          .toList();

      debugPrint('PaymentProvider: loaded ${_payments.length} payments');
      notifyListeners();
    }, onError: (error) {
      debugPrint('PaymentProvider error: $error');
    });
  }

  /// Add a new payment and update related sale or service
  Future<String?> addPayment({
    required Payment payment,
    SaleProvider? saleProvider,
    ServiceProvider? serviceProvider,
    required String facilityId,
  }) async {
    if (facilityId.isEmpty) return null;

    try {
      // Add payment to Firestore
      final docRef = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .add(payment.toMap());

      debugPrint(
          'PaymentProvider: added payment ${docRef.id} for sale ${payment.saleId} or service ${payment.serviceId}');

      /// -----------------------
      /// Update related Sale
      /// -----------------------
      if (payment.saleId != null &&
          payment.saleId!.isNotEmpty &&
          saleProvider != null) {
        final saleIndex =
            saleProvider.sales.indexWhere((s) => s.id == payment.saleId);
        if (saleIndex != -1) {
          final sale = saleProvider.sales[saleIndex];
          final updatedTotalPaid = sale.totalPaid + payment.amount;

          // Recompute realized/unrealized profit
          final updatedItems = sale.items.map((item) {
            double paymentRatio = 0.0;
            if (sale.totalAmount > 0) {
              paymentRatio =
                  (updatedTotalPaid / sale.totalAmount).clamp(0.0, 1.0);
            }
            final realized = item.profit * paymentRatio;
            final unrealized = item.profit - realized;

            return item.copyWith(
              realizedProfit: realized,
              unrealizedProfit: unrealized,
            );
          }).toList();

          final totalProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.profit);
          final realizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
          final unrealizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

          final updatedSale = sale.copyWith(
            totalPaid: updatedTotalPaid,
            items: updatedItems,
            totalProfit: totalProfit,
            realizedProfit: realizedProfit,
            unrealizedProfit: unrealizedProfit,
            updatedAt: DateTime.now(),
          );

          await saleProvider.updateSale(updatedSale, facilityId);
        }
      }

      /// -----------------------
      /// Update related Service
      /// -----------------------
      if (payment.serviceId != null &&
          payment.serviceId!.isNotEmpty &&
          serviceProvider != null) {
        final serviceIndex =
            serviceProvider.services.indexWhere((s) => s.id == payment.serviceId);
        if (serviceIndex != -1) {
          final service = serviceProvider.services[serviceIndex];
          final updatedTotalPaid = service.totalPaid + payment.amount;

          final updatedService = service.copyWith(
            totalPaid: updatedTotalPaid,
            updatedAt: DateTime.now(),
          );

          await serviceProvider.updateService(updatedService);
        }
      }

      return docRef.id;
    } catch (e) {
      debugPrint('PaymentProvider addPayment error: $e');
      return null;
    }
  }

  /// Total payments made for a specific client
  double totalPaidByClient(String clientId) {
    return _payments
        .where((p) => p.clientId == clientId)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Delete a payment and update related sale or service
  Future<void> deletePayment({
    required String paymentId,
    SaleProvider? saleProvider,
    ServiceProvider? serviceProvider,
    required String facilityId,
  }) async {
    if (facilityId.isEmpty || paymentId.isEmpty) return;

    try {
      final payment = _payments.firstWhere((p) => p.id == paymentId);
      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .doc(paymentId)
          .delete();

      debugPrint(
          'PaymentProvider: deleted payment $paymentId for sale ${payment.saleId} or service ${payment.serviceId}');

      /// -----------------------
      /// Update related Sale
      /// -----------------------
      if (payment.saleId != null &&
          payment.saleId!.isNotEmpty &&
          saleProvider != null) {
        final saleIndex =
            saleProvider.sales.indexWhere((s) => s.id == payment.saleId);
        if (saleIndex != -1) {
          final sale = saleProvider.sales[saleIndex];
          final updatedTotalPaid = sale.totalPaid - payment.amount;

          final updatedItems = sale.items.map((item) {
            double paymentRatio = 0.0;
            if (sale.totalAmount > 0) {
              paymentRatio =
                  (updatedTotalPaid / sale.totalAmount).clamp(0.0, 1.0);
            }
            final realized = item.profit * paymentRatio;
            final unrealized = item.profit - realized;

            return item.copyWith(
              realizedProfit: realized,
              unrealizedProfit: unrealized,
            );
          }).toList();

          final totalProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.profit);
          final realizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
          final unrealizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

          final updatedSale = sale.copyWith(
            totalPaid: updatedTotalPaid,
            items: updatedItems,
            totalProfit: totalProfit,
            realizedProfit: realizedProfit,
            unrealizedProfit: unrealizedProfit,
            updatedAt: DateTime.now(),
          );

          await saleProvider.updateSale(updatedSale, facilityId);
        }
      }

      /// -----------------------
      /// Update related Service
      /// -----------------------
      if (payment.serviceId != null &&
          payment.serviceId!.isNotEmpty &&
          serviceProvider != null) {
        final serviceIndex =
            serviceProvider.services.indexWhere((s) => s.id == payment.serviceId);
        if (serviceIndex != -1) {
          final service = serviceProvider.services[serviceIndex];
          final updatedTotalPaid = service.totalPaid - payment.amount;

          final updatedService = service.copyWith(
            totalPaid: updatedTotalPaid,
            updatedAt: DateTime.now(),
          );

          await serviceProvider.updateService(updatedService);
        }
      }
    } catch (e) {
      debugPrint('PaymentProvider deletePayment error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
