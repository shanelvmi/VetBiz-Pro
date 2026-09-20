import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service.dart';
import '../models/debt.dart';
import 'debt_provider.dart';
import 'product_provider.dart';
import '../utils/activity_logger.dart';
import '../utils/receipt_numbering.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DebtProvider debtProvider;

  ServiceProvider({required this.debtProvider});

  /// How many services to fetch per page. The live listener holds the
  /// most recently-touched [pageSize] services in real time; older pages
  /// are fetched on demand via [loadMoreServices]. This used to load a
  /// facility's ENTIRE service history on every app open - same issue we
  /// fixed for sales, fixed here the same way.
  static const int pageSize = 25;

  List<Service> _liveServices = [];
  final List<Service> _olderServices = [];
  List<Service> get services => [..._liveServices, ..._olderServices];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSubscription;
  String? _facilityId;

  String? get facilityId => _facilityId;

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// Clear provider
  void clear() {
    _servicesSubscription?.cancel();
    _liveServices = [];
    _olderServices.clear();
    _lastDocument = null;
    _hasMore = true;
    _facilityId = null;
    notifyListeners();
  }

  /// ===== TOTALS (LIVE) - reflect only what's currently loaded, i.e. the
  /// live window + any pages paged through. For period totals (Today/This
  /// Week/etc.) use DashboardSummaryService, which reads precomputed daily
  /// aggregates instead. =====
  double get totalAmount =>
      services.fold(0.0, (s, x) => s + x.totalAmount);

  double get totalPaid =>
      services.fold(0.0, (s, x) => s + x.totalPaid);

  double get totalExpenses =>
      services.fold(0.0, (s, x) => s + x.totalExpenses);

  double get totalServiceProfit =>
      services.fold(0.0, (s, x) => s + x.totalServiceProfit);

  Query<Map<String, dynamic>> _baseQuery(String facilityId) => _firestore
      .collection('facilities')
      .doc(facilityId)
      .collection('services')
      // Ordered by updatedAt (always present - see Service.toMap, it
      // defaults to serverTimestamp) rather than serviceDate (nullable,
      // user-editable) so pagination has a reliable, always-populated
      // cursor field. serviceDate is used separately for day-bucketing in
      // the dailyServiceSummaries Cloud Function.
      .orderBy('updatedAt', descending: true);

  /// ===== LISTEN (paginated) =====
  void listenToServices(String facilityId) {
    if (_facilityId == facilityId && _servicesSubscription != null) return;

    _facilityId = facilityId;
    _liveServices = [];
    _olderServices.clear();
    _lastDocument = null;
    _hasMore = true;

    _servicesSubscription?.cancel();

    _servicesSubscription = _baseQuery(facilityId)
        .limit(pageSize)
        .snapshots()
        .listen((snapshot) {
      _liveServices = snapshot.docs
          .map((doc) => Service.fromFirestore(doc.data(), doc.id))
          .toList();

      if (_olderServices.isEmpty) {
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= pageSize;
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('ServiceProvider listen error: $e');
    });
  }

  /// Fetch the next page of older services (one-time read, not live).
  Future<void> loadMoreServices() async {
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

      final more = snapshot.docs
          .map((doc) => Service.fromFirestore(doc.data(), doc.id))
          .toList();
      _olderServices.addAll(more);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= pageSize;
    } catch (e) {
      debugPrint('Error loading more services: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// ===== ADD SERVICE =====
  Future<String?> addService(Service service) async {
    if (_facilityId == null) return null;

    final ref = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services');

    var serviceToSave = service.copyWith();
    final docRef = ref.doc(); // pre-allocate the ID, no write yet

    // Deduct stock FIRST (FIFO) so the saved service records exactly
    // which batch(es) were actually consumed - same reasoning as Sales.
    List<Map<String, dynamic>> updatedItems;
    try {
      updatedItems = await _deductStockForItems(serviceToSave.itemsUsed);
    } catch (e) {
      debugPrint('Error deducting stock for service: $e');
      return null;
    }
    serviceToSave = serviceToSave.copyWith(itemsUsed: updatedItems);
    serviceToSave = serviceToSave.copyWith(receiptNumber: await nextReceiptNumber(_facilityId!));

    try {
      await docRef.set({
        ...serviceToSave.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Local cache (instant UI)
      final saved = serviceToSave.copyWith(id: docRef.id);
      _liveServices.insert(0, saved);
      notifyListeners();

      // Handle debt and transaction
      await _handleServiceDebt(saved, docRef.id);
      await _handleServiceTransaction(saved, docRef.id);

      // Record the upfront amount collected (if any) as a payment - the
      // same fix applied to sales, so dailyCollections captures cash
      // collected on services too, not just sales.
      if (saved.totalPaid > 0) {
        final user = FirebaseAuth.instance.currentUser;
        await _firestore
            .collection('facilities')
            .doc(_facilityId)
            .collection('payments')
            .add({
          'clientId': saved.clientId,
          'clientName': saved.clientName,
          'serviceId': docRef.id,
          'amount': saved.totalPaid,
          'timestamp': FieldValue.serverTimestamp(),
          'paidById': user?.uid ?? '',
          'source': 'service',
          'paymentMethod': saved.paymentMethod,
        });
      }

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: _facilityId!,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Services',
        description: 'Recorded service for ${saved.clientName ?? 'Walk-in'} - Tsh ${saved.totalAmount.toStringAsFixed(0)}',
      );

      return docRef.id;
    } catch (e) {
      debugPrint('ServiceProvider.addService error: $e');
      rethrow;
    }
  }

  /// Looks up a service already held in memory (live or older page) -
  /// used by update/delete to know what the PREVIOUS item list was, so
  /// stock deductions can be correctly reconciled.
  Service? _findCachedService(String id) {
    final liveIndex = _liveServices.indexWhere((s) => s.id == id);
    if (liveIndex != -1) return _liveServices[liveIndex];
    final olderIndex = _olderServices.indexWhere((s) => s.id == id);
    if (olderIndex != -1) return _olderServices[olderIndex];
    return null;
  }

  /// ===== UPDATE SERVICE =====
  Future<void> updateService(Service service) async {
    if (_facilityId == null || service.id.isEmpty) return;

    final doc = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services')
        .doc(service.id);

    // Captured before we overwrite the cache - this is what tells us
    // which stock deductions the OLD item list made, so we can reverse
    // exactly those before applying the new list.
    final previous = _findCachedService(service.id);

    var updated = service.copyWith();

    try {
      // Reconcile stock first: undo whatever the old item list deducted,
      // then deduct the new item list (FIFO) - this is what lets the
      // saved service record which batches the NEW list actually came
      // from, instead of writing stale data first and reconciling after.
      if (previous != null) {
        await _restoreStockForItems(previous.itemsUsed);
      }
      final updatedItems = await _deductStockForItems(updated.itemsUsed);
      updated = updated.copyWith(itemsUsed: updatedItems);

      await doc.update({
        ...updated.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final liveIndex = _liveServices.indexWhere((s) => s.id == service.id);
      final olderIndex =
          liveIndex == -1 ? _olderServices.indexWhere((s) => s.id == service.id) : -1;
      if (liveIndex != -1) {
        _liveServices[liveIndex] = updated;
      } else if (olderIndex != -1) {
        _olderServices[olderIndex] = updated;
      }
      notifyListeners();

      // Re-handle debt and transaction
      await _handleServiceDebt(updated, service.id);
      await _handleServiceTransaction(updated, service.id);

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: _facilityId!,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Services',
        description: 'Updated service for ${updated.clientName ?? 'Walk-in'} - Tsh ${updated.totalAmount.toStringAsFixed(0)}',
      );
    } catch (e) {
      debugPrint('ServiceProvider.updateService error: $e');
      rethrow;
    }
  }

  /// ===== LOCAL UPDATE AFTER PAYMENT =====
  void updateLocalService(Service updated) {
    final liveIndex = _liveServices.indexWhere((s) => s.id == updated.id);
    final olderIndex =
        liveIndex == -1 ? _olderServices.indexWhere((s) => s.id == updated.id) : -1;

    if (liveIndex != -1) {
      _liveServices[liveIndex] = updated.copyWith();
    } else if (olderIndex != -1) {
      _olderServices[olderIndex] = updated.copyWith();
    } else {
      return;
    }
    notifyListeners();
  }

  /// ===== DELETE =====
  /// Moves the service to `trash_services` instead of erasing it
  /// permanently, so an accidental delete can be undone from the Trash
  /// screen. Auto-purged after 30 days by a scheduled Cloud Function.
  Future<void> deleteService(String id) async {
    if (_facilityId == null) return;

    // Captured before deletion so any deducted stock can be restored,
    // and reused below for the trash copy - avoids a second read.
    final existing = _findCachedService(id);

    final doc = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services')
        .doc(id);

    Map<String, dynamic>? dataForTrash;
    if (existing != null) {
      dataForTrash = existing.toMap();
    } else {
      final snapshot = await doc.get();
      if (snapshot.exists) dataForTrash = snapshot.data();
    }

    if (dataForTrash != null) {
      final user = FirebaseAuth.instance.currentUser;
      await _firestore
          .collection('facilities')
          .doc(_facilityId)
          .collection('trash_services')
          .doc(id)
          .set({
        ...dataForTrash,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': user?.email ?? user?.uid ?? 'Unknown',
      });
    }

    await doc.delete();

    _liveServices.removeWhere((s) => s.id == id);
    _olderServices.removeWhere((s) => s.id == id);
    notifyListeners();

    // Delete associated transactions
    final tx = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('transactions')
        .where('serviceId', isEqualTo: id);

    final snap = await tx.get();
    for (var d in snap.docs) {
      await d.reference.delete();
    }

    // Restore any stock this service had previously deducted.
    if (existing != null) {
      await _restoreStockForItems(existing.itemsUsed);
    }

    if (dataForTrash != null && _facilityId != null) {
      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: _facilityId!,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Services',
        description: 'Deleted service for ${dataForTrash['clientName'] ?? 'Walk-in'} - Tsh ${(dataForTrash['totalAmount'] ?? 0).toString()}',
      );
    }
  }

  /// ===== DEBT =====
  Future<void> _handleServiceDebt(Service service, String serviceId) async {
    if (_facilityId == null) return;

    final owed = service.totalAmount - service.totalPaid;
    if (owed <= 0 || service.clientId == null) return;

    // One-time lookup at write time (not per-render) since Service
    // doesn't store the client's phone directly.
    String? clientPhone;
    try {
      final clientDoc = await _firestore
          .collection('facilities')
          .doc(_facilityId)
          .collection('clients')
          .doc(service.clientId)
          .get();
      clientPhone = clientDoc.data()?['phone'] as String?;
    } catch (e) {
      debugPrint('Could not look up client phone for debt: $e');
    }

    // Each service debt is its own document
    final debt = Debt(
      id: '',
      clientId: service.clientId!,
      clientName: service.clientName,
      clientPhone: clientPhone,
      serviceId: serviceId,
      saleId: null,
      source: 'Service',
      amountOwed: owed,
      timestamp: DateTime.now(),
      updatedAt: DateTime.now(),
      items: [
        {
          'serviceName': service.name,
          'category': service.category,
          'totalAmount': service.totalAmount,
          'totalPaid': service.totalPaid,
        }
      ],
    );

    await debtProvider.addOrUpdateDebtForClient(debt);
  }

  /// ===== TRANSACTION (EXPENSES) =====
  /// Only the portion of items NOT matched to a real product becomes a
  /// new cash expense - stock-matched items were already paid for when
  /// that stock was purchased, so expensing them again here would
  /// double-count the cost. See Service.externalExpenseTotal.
  Future<void> _handleServiceTransaction(
      Service service, String serviceId) async {
    if (_facilityId == null) return;

    final ref = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('transactions');

    final old = await ref.where('serviceId', isEqualTo: serviceId).get();
    for (var d in old.docs) {
      await d.reference.delete();
    }

    final expenseAmount = service.externalExpenseTotal;
    if (expenseAmount <= 0) return;

    // Same real Firestore fullName lookup already used for activity
    // logging above in this file - Firebase Auth's own displayName is
    // never actually set anywhere in this app (it uses a separate
    // fullName field in Firestore instead), so it was silently falling
    // back to 'System' for every single service expense.
    final userInfo = await ActivityLogger.getCurrentUserInfo();
    final name = userInfo['userName']!;

    // Same filter as Service.externalExpenseTotal - only the items that
    // actually became this expense, not every item on the service, so
    // an audit can see exactly what was expensed without opening the
    // service record separately.
    final externalItemNames = service.itemsUsed
        .where((item) => item['productId'] == null)
        .map((item) => (item['itemName'] ?? '').toString())
        .where((itemName) => itemName.isNotEmpty)
        .toList();
    final itemsSummary = externalItemNames.isNotEmpty ? externalItemNames.join(', ') : 'N/A';

    await ref.add({
      'amount': expenseAmount,
      'category': 'Vet Service Expenses',
      'date': Timestamp.fromDate(DateTime.now()),
      'description': 'Items used for ${service.name}: $itemsSummary',
      'recordedBy': name,
      'type': 'expense',
      'serviceId': serviceId,
      'paymentMethod': service.paymentMethod ?? 'Cash',
    });
  }

  /// ===== STOCK RECONCILIATION FOR ITEMS USED =====
  /// Deducts 1 unit of sellable stock for each item matched to a real
  /// product (has a productId), FIFO - soonest-expiry batch first, same
  /// as Sales. Non-matched items (externally bought, fare, or any other
  /// plain expense) never touch stock at all, since they never came from
  /// it. Returns the item list with each matched item's real batch
  /// allocation recorded, for accurate restoration later.
  Future<List<Map<String, dynamic>>> _deductStockForItems(List<Map<String, dynamic>> items) async {
    if (_facilityId == null) return items;

    final productHelper = ProductProvider();
    final updated = <Map<String, dynamic>>[];
    final deductedSoFar = <int, List<Map<String, dynamic>>>{};

    try {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final productId = item['productId'] as String?;
        if (productId == null) {
          updated.add(item);
          continue;
        }

        final allocations = await productHelper.deductSellableFIFO(
          facilityId: _facilityId!,
          productId: productId,
          quantity: 1,
        );
        deductedSoFar[i] = allocations;
        updated.add({...item, 'batchAllocations': allocations});
      }
    } catch (e) {
      // Roll back whatever was already deducted before this item failed.
      for (var i = 0; i < items.length; i++) {
        final allocations = deductedSoFar[i];
        if (allocations == null) continue;
        final productId = items[i]['productId'] as String?;
        if (productId == null) continue;
        await productHelper.restoreSellableFIFO(
          facilityId: _facilityId!,
          productId: productId,
          allocations: allocations,
        );
      }
      rethrow;
    }

    return updated;
  }

  /// Reverses the above - used when a service is deleted, or when it's
  /// edited (undo the old item list's impact before applying the new
  /// one). Restores to the exact batch(es) originally consumed when
  /// available; falls back to the old +1 aggregate adjustment for
  /// services recorded before batch tracking existed.
  Future<void> _restoreStockForItems(List<Map<String, dynamic>> items) async {
    final productHelper = ProductProvider();

    for (final item in items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;

      final allocations = (item['batchAllocations'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (allocations != null && allocations.isNotEmpty) {
        await productHelper.restoreSellableFIFO(
          facilityId: _facilityId!,
          productId: productId,
          allocations: allocations,
        );
      } else {
        await _adjustProductStock(productId, 1);
      }
    }
  }

  /// Transaction-safe stock adjustment - reads the current server value
  /// and writes atomically, same pattern used for sales and stock moves
  /// elsewhere, so two vets recording services concurrently can't
  /// silently overwrite each other's stock update. Clamps at 0 rather
  /// than throwing, so a stock mismatch never blocks saving a service
  /// that's already been performed.
  Future<void> _adjustProductStock(String productId, int delta) async {
    if (_facilityId == null) return;

    final productRef = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('products')
        .doc(productId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) return;

        final currentSellable = (snapshot.data()?['sellableQty'] ?? 0) as int;
        final newSellable = currentSellable + delta;

        transaction.update(productRef, {
          'sellableQty': newSellable < 0 ? 0 : newSellable,
        });
      });
    } catch (e) {
      debugPrint('Could not adjust stock for product $productId: $e');
    }
  }

  @override
  void dispose() {
    _servicesSubscription?.cancel();
    super.dispose();
  }
}
