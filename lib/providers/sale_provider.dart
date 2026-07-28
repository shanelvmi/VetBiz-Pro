import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';

class SaleProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Sale> _sales = [];
  List<Sale> get sales => _sales;

  StreamSubscription<QuerySnapshot>? _salesSubscription;

  /// Initialize provider: listen to real-time updates
  void init(String facilityId) {
    listenToSales(facilityId);
  }

  /// Clear all sales
  void clear() {
    _sales.clear();
    _salesSubscription?.cancel();
    notifyListeners();
  }

  /// Real-time listener for sales
  void listenToSales(String facilityId) {
    _salesSubscription?.cancel();
    _salesSubscription = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('sales')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      List<Sale> loadedSales = [];
      for (var doc in snapshot.docs) {
        var sale = Sale.fromFirestore(doc.data(), doc.id);

        // Fetch client name safely
        if (sale.clientId != null && sale.clientId!.isNotEmpty) {
          final clientDoc = await _firestore
              .collection('facilities')
              .doc(facilityId)
              .collection('clients')
              .doc(sale.clientId)
              .get();

          final clientName = clientDoc.exists && clientDoc.data() != null
              ? (clientDoc.data()!['name'] as String?) ?? 'N/A'
              : 'N/A';

          sale = sale.copyWith(clientName: clientName);
        }

        // Clamp totalPaid to totalAmount
        sale = sale.copyWith(
            totalPaid: (sale.totalPaid ?? 0)
                .clamp(0, sale.totalAmount ?? 0));

        sale = _computeProfits(sale);

        loadedSales.add(sale);
      }

      _sales = loadedSales;
      notifyListeners();
    });
  }

  /// Add a sale
  Future<String?> addSale(Sale sale, String facilityId) async {
    try {
      final safeSale = sale.copyWith(
        totalPaid: (sale.totalPaid ?? 0).clamp(0, sale.totalAmount ?? 0),
      );

      final saleWithProfit = _computeProfits(safeSale);

      final docRef = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .add({
        ...saleWithProfit.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Deduct stock
      await _deductStock(saleWithProfit, facilityId);

      // Update client balance (sum of unpaid sales)
      await _updateClientBalance(saleWithProfit, facilityId);

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding sale: $e');
      return null;
    }
  }

  /// Apply payment to existing sale
  Future<void> applyPaymentToSale(
      String saleId, double amountPaid, String facilityId) async {
    final saleIndex = _sales.indexWhere((s) => s.id == saleId);
    if (saleIndex == -1) return;

    var sale = _sales[saleIndex];

    // Clamp payment to remaining debt
    final remaining = (sale.totalAmount ?? 0) - (sale.totalPaid ?? 0);
    final paymentToAdd = amountPaid.clamp(0.0, remaining);

    sale = sale.copyWith(
      totalPaid: (sale.totalPaid ?? 0) + paymentToAdd,
    );

    sale = _computeProfits(sale);

    // Save to Firestore
    await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('sales')
        .doc(sale.id)
        .update({
      ...sale.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _sales[saleIndex] = sale;
    notifyListeners();

    // Update client balance
    await _updateClientBalance(sale, facilityId);
  }

  /// Delete a sale
  Future<void> deleteSale(String saleId, String facilityId) async {
    try {
      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .doc(saleId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting sale: $e');
    }
  }

  /// Compute per-item and total realized/unrealized profit
  Sale _computeProfits(Sale sale) {
    final paymentRatio =
        (sale.totalAmount ?? 0) > 0 ? ((sale.totalPaid ?? 0) / (sale.totalAmount ?? 1)).clamp(0.0, 1.0) : 0.0;

    final updatedItems = sale.items.map((item) {
      final profitValue = item.profit ?? 0.0;
      final realized = profitValue * paymentRatio;
      final unrealized = profitValue - realized;
      return item.copyWith(
          realizedProfit: realized, unrealizedProfit: unrealized);
    }).toList();

    final totalProfit =
        updatedItems.fold(0.0, (sum, item) => sum + (item.profit ?? 0.0));
    final realizedProfit =
        updatedItems.fold(0.0, (sum, item) => sum + (item.realizedProfit ?? 0.0));
    final unrealizedProfit =
        updatedItems.fold(0.0, (sum, item) => sum + (item.unrealizedProfit ?? 0.0));

    return sale.copyWith(
        items: updatedItems,
        totalProfit: totalProfit,
        realizedProfit: realizedProfit,
        unrealizedProfit: unrealizedProfit);
  }

  /// Deduct stock quantities
  Future<void> _deductStock(Sale sale, String facilityId) async {
    for (var item in sale.items) {
      final productRef = _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(item.productId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) return;

        final currentStock = (snapshot.data()?['sellableQty'] ?? 0).toDouble();
        final newStock = currentStock - (item.quantity ?? 0);
        if (newStock < 0) {
          throw Exception('Not enough stock for product ${item.name}');
        }
        transaction.update(productRef, {'sellableQty': newStock});
      });
    }
  }

  /// Update client balance (sum of all unpaid sales)
  Future<void> _updateClientBalance(Sale sale, String facilityId) async {
    if (sale.clientId == null || sale.clientId!.isEmpty) return;

    final clientRef = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .doc(sale.clientId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(clientRef);
      if (!snapshot.exists) return;

      // Sum of all unpaid sales for this client
      final unpaidSalesSnapshot = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .where('clientId', isEqualTo: sale.clientId)
          .get();

      double totalDebt = 0;
      for (var doc in unpaidSalesSnapshot.docs) {
        final data = doc.data();
        final tAmount = (data['totalAmount'] ?? 0).toDouble();
        final tPaid = (data['totalPaid'] ?? 0).toDouble();
        totalDebt += (tAmount - tPaid);
      }

      transaction.update(clientRef, {'balance': totalDebt});
    });
  }

  /// Totals & summaries
  double get totalSales =>
      _sales.fold(0.0, (sum, sale) => sum + (sale.totalAmount ?? 0));

  double get totalEarnings =>
      _sales.fold(0.0, (sum, sale) => sum + (sale.totalPaid ?? 0));

  double get totalProfit =>
      _sales.fold(0.0, (sum, sale) => sum + (sale.totalProfit ?? 0));

  double get realizedProfit =>
      _sales.fold(0.0, (sum, sale) => sum + (sale.realizedProfit ?? 0));

  double get unrealizedProfit =>
      _sales.fold(0.0, (sum, sale) => sum + (sale.unrealizedProfit ?? 0));

  List<Sale> get debtSales =>
      _sales.where((sale) => (sale.totalPaid ?? 0) < (sale.totalAmount ?? 0)).toList();

  Map<String, double> get debtByClient {
    final Map<String, double> result = {};
    for (var sale in debtSales) {
      final clientId = sale.clientId ?? 'Unknown Client';
      final debt = (sale.totalAmount ?? 0) - (sale.totalPaid ?? 0);
      result[clientId] = (result[clientId] ?? 0) + debt;
    }
    return result;
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }
}
