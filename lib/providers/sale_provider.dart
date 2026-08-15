import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sale.dart';
import 'product_provider.dart';
import '../utils/activity_logger.dart';

class SaleProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// How many sales to fetch per page. The live listener always holds the
  /// most recent [pageSize] sales in real time; older pages are fetched
  /// on demand via [loadMoreSales] and are NOT kept live (they don't need
  /// to be — historical sales don't change).
  static const int pageSize = 25;

  // Most recent page, kept in sync in real time.
  List<Sale> _liveSales = [];

  // Older pages, loaded on demand and appended here.
  final List<Sale> _olderSales = [];

  List<Sale> get sales => [..._liveSales, ..._olderSales];

  String? _facilityId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _salesSubscription;

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// Initialize provider: listen to real-time updates for [facilityId].
  /// Safe to call repeatedly (e.g. on screen re-entry) - it's a no-op if
  /// already listening to the same facility.
  void init(String facilityId) {
    if (_facilityId == facilityId && _salesSubscription != null) return;
    _facilityId = facilityId;
    _liveSales = [];
    _olderSales.clear();
    _lastDocument = null;
    _hasMore = true;
    listenToSales(facilityId);
  }

  /// Clear all sales and stop listening.
  void clear() {
    _liveSales = [];
    _olderSales.clear();
    _lastDocument = null;
    _hasMore = true;
    _facilityId = null;
    _salesSubscription?.cancel();
    notifyListeners();
  }

  Query<Map<String, dynamic>> _baseQuery(String facilityId) => _firestore
      .collection('facilities')
      .doc(facilityId)
      .collection('sales')
      .orderBy('timestamp', descending: true);

  /// Real-time listener for the most recent page of sales only. This is the
  /// key cost/perf fix: we used to load *every* sale a facility ever made on
  /// every app open. Now we only ever stream the newest [pageSize] docs live;
  /// everything older is paged in explicitly via [loadMoreSales].
  void listenToSales(String facilityId) {
    _salesSubscription?.cancel();
    _salesSubscription = _baseQuery(facilityId)
        .limit(pageSize)
        .snapshots()
        .listen((snapshot) {
      _liveSales = snapshot.docs.map(_hydrateSale).toList();

      // Only (re)anchor the pagination cursor while no older pages have been
      // loaded yet. Once the user has paged further back, the live window
      // updating shouldn't reset how far they've already paged.
      if (_olderSales.isEmpty) {
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= pageSize;
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to sales: $e');
    });
  }

  /// Fetch the next page of older sales (one-time read, not live).
  Future<void> loadMoreSales() async {
    final facilityId = _facilityId;
    if (_isLoadingMore || !_hasMore || facilityId == null || _lastDocument == null) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _baseQuery(facilityId)
          .startAfterDocument(_lastDocument!)
          .limit(pageSize)
          .get();

      final moreSales = snapshot.docs.map(_hydrateSale).toList();
      _olderSales.addAll(moreSales);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= pageSize;
    } catch (e) {
      debugPrint('Error loading more sales: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Build a Sale from a doc, clamp totalPaid defensively, and compute
  /// realized/unrealized profit. Note: clientName is read straight off the
  /// stored document - it's denormalized onto the sale at write time
  /// (see addSale), so there's no per-sale extra read for the client's name
  /// the way the old version did on every single snapshot update.
  Sale _hydrateSale(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    var sale = Sale.fromFirestore(doc.data(), doc.id);
    sale = sale.copyWith(totalPaid: sale.totalPaid.clamp(0, sale.totalAmount));
    return _computeProfits(sale);
  }

  /// Add a sale
  Future<String?> addSale(Sale sale, String facilityId) async {
    try {
      var saleToSave = sale.copyWith(
        totalPaid: sale.totalPaid.clamp(0, sale.totalAmount),
      );

      // Denormalize the client's name onto the sale so future reads never
      // need a separate lookup. If the caller already supplied clientName
      // (the normal case - see AddSaleScreen), this is a no-op read-free path.
      if ((saleToSave.clientName == null || saleToSave.clientName!.isEmpty) &&
          saleToSave.clientId != null &&
          saleToSave.clientId!.isNotEmpty) {
        final clientDoc = await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('clients')
            .doc(saleToSave.clientId)
            .get();
        final name = clientDoc.data()?['name'] as String?;
        if (name != null) {
          saleToSave = saleToSave.copyWith(clientName: name);
        }
      }

      // Deduct stock FIRST (FIFO - soonest-expiry batch consumed first),
      // updating each item's cost price to reflect what was actually
      // consumed, before the sale is ever written - this is what makes
      // the saved sale's costing and its batchAllocations record
      // accurate, instead of just a guess made before any stock was
      // actually touched.
      final deductedSoFar = <String, List<Map<String, dynamic>>>{};
      final updatedItems = <SaleItem>[];
      // These FIFO helpers are pure Firestore operations - they don't
      // depend on any cached state from a specific ProductProvider
      // instance, so a plain local instance works fine here without
      // needing BuildContext/Provider.of (which SaleProvider doesn't
      // have access to).
      final productHelper = ProductProvider();

      try {
        for (final item in saleToSave.items) {
          final allocations = await productHelper.deductSellableFIFO(
            facilityId: facilityId,
            productId: item.productId,
            quantity: item.quantity,
          );
          deductedSoFar[item.productId] = allocations;

          final totalCost = allocations.fold<double>(
              0, (sum, a) => sum + (a['quantity'] as int) * (a['buyPrice'] as double));
          final weightedCostPrice = item.quantity > 0 ? totalCost / item.quantity : item.costPrice;

          updatedItems.add(item.copyWith(
            costPrice: weightedCostPrice,
            batchAllocations: allocations,
          ));
        }
      } catch (e) {
        // Roll back whatever was already deducted before this item
        // failed - never leave stock partially deducted for a sale that
        // never actually gets recorded.
        for (final entry in deductedSoFar.entries) {
          await productHelper.restoreSellableFIFO(
            facilityId: facilityId,
            productId: entry.key,
            allocations: entry.value,
          );
        }
        debugPrint('Error deducting stock for sale, rolled back: $e');
        return null;
      }

      saleToSave = saleToSave.copyWith(items: updatedItems);
      saleToSave = _computeProfits(saleToSave);

      final docRef = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .add({
        ...saleToSave.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update client balance by the outstanding amount only - no re-scan
      // of the client's sale history required.
      final outstanding = saleToSave.totalAmount - saleToSave.totalPaid;
      if (outstanding != 0) {
        await _adjustClientBalance(saleToSave.clientId, outstanding, facilityId);
      }

      // Record the upfront amount actually collected (cash sale, or the
      // down payment on a credit sale) as a payment. Without this, the
      // `payments` collection only ever saw later debt repayments
      // (see AddPaymentScreen) and missed every cash sale entirely - which
      // meant nothing could reliably answer "how much cash did we actually
      // collect on a given day". This is what feeds `dailyCollections` via
      // the updateDailyCollections Cloud Function.
      if (saleToSave.totalPaid > 0) {
        await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('payments')
            .add({
          'clientId': saleToSave.clientId,
          'clientName': saleToSave.clientName,
          'saleId': docRef.id,
          'amount': saleToSave.totalPaid,
          'timestamp': FieldValue.serverTimestamp(),
          'paidById': saleToSave.soldById,
          'source': 'sale',
        });
      }

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Sales',
        description: 'Recorded sale to ${saleToSave.clientName ?? 'Walk-in'} - Tsh ${saleToSave.totalAmount.toStringAsFixed(0)}',
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding sale: $e');
      return null;
    }
  }

  /// Apply payment to existing sale
  Future<void> applyPaymentToSale(
      String saleId, double amountPaid, String facilityId) async {
    final index = _liveSales.indexWhere((s) => s.id == saleId);
    final olderIndex = index == -1 ? _olderSales.indexWhere((s) => s.id == saleId) : -1;
    if (index == -1 && olderIndex == -1) return;

    var sale = index != -1 ? _liveSales[index] : _olderSales[olderIndex];

    // Clamp payment to remaining debt
    final remaining = sale.totalAmount - sale.totalPaid;
    final paymentToAdd = amountPaid.clamp(0.0, remaining);
    if (paymentToAdd <= 0) return;

    sale = sale.copyWith(totalPaid: sale.totalPaid + paymentToAdd);
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

    if (index != -1) {
      _liveSales[index] = sale;
    } else {
      _olderSales[olderIndex] = sale;
    }
    notifyListeners();

    // Reduce client balance by exactly the payment applied.
    await _adjustClientBalance(sale.clientId, -paymentToAdd, facilityId);
  }

  /// Delete a sale. Also restores stock and reverses any outstanding balance
  /// it contributed to the client - the previous version silently left both
  /// of those out of sync when a sale was deleted.
  Future<void> deleteSale(String saleId, String facilityId) async {
    try {
      final index = _liveSales.indexWhere((s) => s.id == saleId);
      final olderIndex = index == -1 ? _olderSales.indexWhere((s) => s.id == saleId) : -1;

      Sale? sale;
      if (index != -1) {
        sale = _liveSales[index];
      } else if (olderIndex != -1) {
        sale = _olderSales[olderIndex];
      } else {
        final doc = await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('sales')
            .doc(saleId)
            .get();
        if (doc.exists && doc.data() != null) {
          sale = Sale.fromFirestore(doc.data(), doc.id);
        }
      }

      if (sale != null) {
        final user = FirebaseAuth.instance.currentUser;
        await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('trash_sales')
            .doc(saleId)
            .set({
          ...sale.toMap(),
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': user?.email ?? user?.uid ?? 'Unknown',
        });
      }

      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .doc(saleId)
          .delete();

      if (sale != null) {
        await _restoreStock(sale, facilityId);
        final outstanding = sale.totalAmount - sale.totalPaid;
        if (outstanding != 0) {
          await _adjustClientBalance(sale.clientId, -outstanding, facilityId);
        }

        // Clean up any debt record this sale created - previously left
        // behind permanently, still showing the client owing money for
        // a sale that no longer exists.
        final debtSnap = await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('debts')
            .where('saleId', isEqualTo: saleId)
            .get();
        for (final debtDoc in debtSnap.docs) {
          await debtDoc.reference.delete();
        }
      }

      if (sale != null) {
        final userInfo = await ActivityLogger.getCurrentUserInfo();
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: userInfo['userId']!,
          userName: userInfo['userName'],
          actionType: 'Sales',
          description: 'Deleted sale to ${sale.clientName ?? 'Walk-in'} - Tsh ${sale.totalAmount.toStringAsFixed(0)}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      rethrow;
    }
  }

  /// Compute per-item and total realized/unrealized profit
  Sale _computeProfits(Sale sale) {
    final paymentRatio = sale.totalAmount > 0
        ? (sale.totalPaid / sale.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    final updatedItems = sale.items.map((item) {
      final profitValue = item.profit;
      final realized = profitValue * paymentRatio;
      final unrealized = profitValue - realized;
      return item.copyWith(realizedProfit: realized, unrealizedProfit: unrealized);
    }).toList();

    final totalProfit = updatedItems.fold(0.0, (sum, item) => sum + item.profit);
    final realizedProfit =
        updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
    final unrealizedProfit =
        updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

    return sale.copyWith(
      items: updatedItems,
      totalProfit: totalProfit,
      realizedProfit: realizedProfit,
      unrealizedProfit: unrealizedProfit,
    );
  }

  /// Deduct stock quantities
  /// Restore stock quantities (used when a sale is deleted) - restores
  /// each item to the exact batch(es) it was originally deducted from
  /// (recorded on the item as `batchAllocations` at sale time), rather
  /// than just bumping a generic total. Sales made before batch tracking
  /// existed have an empty allocations list and fall back to a plain
  /// aggregate restore, same as before.
  Future<void> _restoreStock(Sale sale, String facilityId) async {
    final productHelper = ProductProvider();

    for (final item in sale.items) {
      if (item.batchAllocations.isNotEmpty) {
        await productHelper.restoreSellableFIFO(
          facilityId: facilityId,
          productId: item.productId,
          allocations: item.batchAllocations,
        );
      } else {
        final productRef = _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('products')
            .doc(item.productId);

        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(productRef);
          if (!snapshot.exists) return;
          final currentStock = (snapshot.data()?['sellableQty'] ?? 0).toDouble();
          transaction.update(productRef, {'sellableQty': currentStock + item.quantity});
        });
      }
    }
  }

  /// Adjust a client's running balance by [delta] (positive = they owe more,
  /// negative = debt reduced). This replaces re-summing every sale the
  /// client has ever made, which is the pattern used everywhere else in the
  /// app already (see AddPaymentScreen) - this just brings SaleProvider in
  /// line with it.
  Future<void> _adjustClientBalance(
      String? clientId, double delta, String facilityId) async {
    if (clientId == null || clientId.isEmpty || delta == 0) return;

    final clientRef = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .doc(clientId);

    try {
      await clientRef.set(
        {'balance': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error adjusting client balance: $e');
    }
  }

  /// Totals & summaries - note these only reflect sales currently loaded
  /// in memory (the live page + any pages the user has paged through), not
  /// the facility's entire history. For full-history totals, use
  /// SalesSummaryService, which reads precomputed daily summaries instead
  /// of scanning raw sales.
  double get totalSales => sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);

  double get totalEarnings => sales.fold(0.0, (sum, sale) => sum + sale.totalPaid);

  double get totalProfit => sales.fold(0.0, (sum, sale) => sum + sale.totalProfit);

  double get realizedProfit => sales.fold(0.0, (sum, sale) => sum + sale.realizedProfit);

  double get unrealizedProfit =>
      sales.fold(0.0, (sum, sale) => sum + sale.unrealizedProfit);

  List<Sale> get debtSales =>
      sales.where((sale) => sale.totalPaid < sale.totalAmount).toList();

  Map<String, double> get debtByClient {
    final Map<String, double> result = {};
    for (var sale in debtSales) {
      final clientId = sale.clientId ?? 'Unknown Client';
      final debt = sale.totalAmount - sale.totalPaid;
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
