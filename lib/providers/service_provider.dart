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
import '../services/cursor_paginated_list_controller.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DebtProvider debtProvider;

  ServiceProvider({required this.debtProvider}) {
    servicesListController = CursorPaginatedListController<Service>(
      pageSize: 25,
      fetchPage: _fetchServicesListPage,
      countCreatedAfter: _countNewServices,
    );
  }

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

  // ==================== Services list screen: real cursor pagination ====================
  //
  // A second, separate mechanism just for the Services list screen's
  // own display - same reasoning as SaleProvider's equivalent section:
  // does not replace `services`/`updateService()` above, which
  // PaymentProvider depends on regardless of what page the list screen
  // shows.

  /// searchTerm searches client name only (prefix match) - see
  /// SaleProvider's identical field for the full reasoning (Firestore's
  /// one-range-filter-per-query limit, and the deliberate choice to
  /// drop the snapshot boundary while a search is active).
  ({String searchTerm, String statusFilter, String categoryFilter, String dateFilter}) _servicesListQuery =
      (searchTerm: '', statusFilter: 'All', categoryFilter: 'All', dateFilter: 'All time');

  late final CursorPaginatedListController<Service> servicesListController;

  ({String searchTerm, String statusFilter, String categoryFilter, String dateFilter}) updateServicesListFilters({
    required String searchTerm,
    required String statusFilter,
    required String categoryFilter,
    required String dateFilter,
  }) {
    _servicesListQuery = (
      searchTerm: searchTerm.trim().toLowerCase(),
      statusFilter: statusFilter,
      categoryFilter: categoryFilter,
      dateFilter: dateFilter,
    );
    return _servicesListQuery;
  }

  DateTime? _dateFilterStart(String dateFilter, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (dateFilter) {
      case 'Today':
        return today;
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      case 'This month':
        return DateTime(now.year, now.month, 1);
      default:
        return null; // 'All time'
    }
  }

  Future<CursorPage<Service>> _fetchServicesListPage({
    required DateTime snapshotAt,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final facilityId = _facilityId;
    if (facilityId == null) {
      return const CursorPage(items: [], lastDocument: null, hasMore: false);
    }

    final q = _servicesListQuery;
    final hasSearch = q.searchTerm.isNotEmpty;
    Query<Map<String, dynamic>> query =
        _firestore.collection('facilities').doc(facilityId).collection('services');

    if (q.statusFilter != 'All') {
      query = query.where('paymentStatus', isEqualTo: q.statusFilter);
    }
    if (q.categoryFilter != 'All') {
      query = query.where('category', isEqualTo: q.categoryFilter);
    }

    if (hasSearch) {
      query = query
          .where('clientNameLower', isGreaterThanOrEqualTo: q.searchTerm)
          .where('clientNameLower', isLessThan: '${q.searchTerm}\uf8ff')
          .orderBy('clientNameLower')
          .orderBy(FieldPath.documentId);
    } else {
      final dateStart = _dateFilterStart(q.dateFilter, snapshotAt);
      if (dateStart != null) {
        query = query.where('serviceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart));
      }
      query = query
          .where('serviceDate', isLessThanOrEqualTo: Timestamp.fromDate(snapshotAt))
          .orderBy('serviceDate', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return CursorPage(
      items: snapshot.docs.map((d) => Service.fromFirestore(d.data(), d.id)).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= pageSize,
    );
  }

  Future<int> _countNewServices({required DateTime after}) async {
    final facilityId = _facilityId;
    if (facilityId == null) return 0;

    final q = _servicesListQuery;
    if (q.searchTerm.isNotEmpty) return 0;

    Query<Map<String, dynamic>> query = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('services')
        .where('serviceDate', isGreaterThan: Timestamp.fromDate(after));
    if (q.statusFilter != 'All') {
      query = query.where('paymentStatus', isEqualTo: q.statusFilter);
    }
    if (q.categoryFilter != 'All') {
      query = query.where('category', isEqualTo: q.categoryFilter);
    }

    final agg = await query.count().get();
    return agg.count ?? 0;
  }

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
        ...serviceToSave.searchFields(),
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
          'clientNameLower': (saved.clientName ?? '').toLowerCase(),
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
        ...updated.searchFields(),
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
      await _handleServiceDebt(updated, service.id, previous: previous);
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

    // Reverse whatever this service still owed against the client's
    // balance, and remove its own debt record if it had one -
    // previously neither happened at all, leaving Client.balance
    // overstated and a stale debt entry behind for a service that no
    // longer exists (the same gap deleteSale already correctly closes
    // for sales).
    final totalAmount = (existing?.totalAmount ?? (dataForTrash?['totalAmount'] as num?)?.toDouble() ?? 0.0);
    final totalPaid = (existing?.totalPaid ?? (dataForTrash?['totalPaid'] as num?)?.toDouble() ?? 0.0);
    final clientId = existing?.clientId ?? dataForTrash?['clientId'] as String?;
    final owed = totalAmount - totalPaid;
    final debtRefForDeletedService =
        _firestore.collection('facilities').doc(_facilityId).collection('debts').doc('service_$id');
    try {
      final cleanupBatch = _firestore.batch();
      if (clientId != null && owed != 0) {
        cleanupBatch.set(
          _firestore.collection('facilities').doc(_facilityId).collection('clients').doc(clientId),
          {'balance': FieldValue.increment(-owed)},
          SetOptions(merge: true),
        );
      }
      cleanupBatch.delete(debtRefForDeletedService);

      if (clientId != null && owed > 0) {
        // Same reasoning as _handleServiceDebt's paid-off branch - only
        // worth a recompute if this service's own debt was actually the
        // one holding the client's recorded oldest-unpaid date.
        final clientRef = _firestore.collection('facilities').doc(_facilityId).collection('clients').doc(clientId);
        final clientDoc = await clientRef.get();
        final rawOldest = clientDoc.data()?['oldestUnpaidDebtDate'];
        final currentOldest = rawOldest is Timestamp ? rawOldest.toDate() : null;
        final thisDebtDoc = await debtRefForDeletedService.get();
        final rawThis = thisDebtDoc.data()?['timestamp'];
        final thisDebtTimestamp = rawThis is Timestamp ? rawThis.toDate() : null;

        if (currentOldest != null && thisDebtTimestamp != null && thisDebtTimestamp.isAtSameMomentAs(currentOldest)) {
          final remainingSnap = await _firestore
              .collection('facilities')
              .doc(_facilityId)
              .collection('debts')
              .where('clientId', isEqualTo: clientId)
              .orderBy('timestamp')
              .limit(2)
              .get();
          final remainingDocs = remainingSnap.docs.where((d) => d.id != debtRefForDeletedService.id).toList();
          final nextTs = remainingDocs.isEmpty ? null : remainingDocs.first.data()['timestamp'];
          final newOldest = nextTs is Timestamp ? nextTs.toDate() : null;
          cleanupBatch.set(
            clientRef,
            {'oldestUnpaidDebtDate': newOldest != null ? Timestamp.fromDate(newOldest) : null},
            SetOptions(merge: true),
          );
        }
      }

      await cleanupBatch.commit();
    } catch (e) {
      debugPrint('Error reversing client balance / cleaning up debt on service delete: $e');
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
  Future<void> _handleServiceDebt(Service service, String serviceId, {Service? previous}) async {
    if (_facilityId == null || service.clientId == null) return;

    final owed = service.totalAmount - service.totalPaid;
    final previousOwed = previous != null ? (previous.totalAmount - previous.totalPaid) : 0.0;
    final delta = owed - previousOwed;

    // Deterministic, not auto-generated - this service always maps to
    // exactly one debt document. An auto-generated id here (the
    // previous behavior) meant every edit created a brand-new,
    // separate debt record instead of updating this service's own one,
    // silently accumulating duplicates that inflated a client's
    // apparent debt with every edit.
    final debtRef =
        _firestore.collection('facilities').doc(_facilityId).collection('debts').doc('service_$serviceId');
    final clientRef =
        _firestore.collection('facilities').doc(_facilityId).collection('clients').doc(service.clientId);

    final batch = _firestore.batch();

    // Read once, upfront - needed by both branches below (clientPhone
    // only for the still-owed case, oldestUnpaidDebtDate's current
    // value for both).
    String? clientPhone;
    DateTime? currentOldestUnpaidDebtDate;
    try {
      final clientDoc = await clientRef.get();
      clientPhone = clientDoc.data()?['phone'] as String?;
      final rawOldest = clientDoc.data()?['oldestUnpaidDebtDate'];
      if (rawOldest is Timestamp) currentOldestUnpaidDebtDate = rawOldest.toDate();
    } catch (e) {
      debugPrint('Could not read client for debt handling: $e');
    }

    DateTime? newOldestUnpaidDebtDate = currentOldestUnpaidDebtDate;
    var oldestUnpaidDebtDateChanged = false;

    if (owed > 0) {
      // Preserve the debt's real original timestamp across edits - now
      // possible at all since the id is deterministic, so the same
      // debt document can be read back rather than only ever written
      // fresh.
      DateTime? originalTimestamp;
      try {
        final existingDebtDoc = await debtRef.get();
        if (existingDebtDoc.exists) {
          final existingTimestamp = existingDebtDoc.data()?['timestamp'];
          if (existingTimestamp is Timestamp) originalTimestamp = existingTimestamp.toDate();
        }
      } catch (e) {
        debugPrint('Could not read existing debt for timestamp: $e');
      }

      final debt = Debt(
        id: debtRef.id,
        clientId: service.clientId!,
        clientName: service.clientName,
        clientPhone: clientPhone,
        serviceId: serviceId,
        saleId: null,
        source: 'Service',
        amountOwed: owed,
        timestamp: originalTimestamp ?? DateTime.now(),
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
      batch.set(debtRef, debt.toMap());

      if (originalTimestamp == null && currentOldestUnpaidDebtDate == null) {
        // A brand-new debt, and the client had no other unpaid debt at
        // all - this one becomes the (only, therefore oldest) unpaid
        // debt. Never older than an existing one, since it's created
        // right now, so no query is needed to know this.
        newOldestUnpaidDebtDate = debt.timestamp;
        oldestUnpaidDebtDateChanged = true;
      }
    } else if (previousOwed > 0) {
      // Was owed before, isn't anymore (e.g. edited down to fully
      // paid) - the old debt record is stale and must go, not be left
      // behind showing a debt that no longer exists.
      batch.delete(debtRef);

      if (currentOldestUnpaidDebtDate != null) {
        // Read this debt's own timestamp before it's gone, to compare
        // against the client's currently-recorded oldest.
        DateTime? thisDebtTimestamp;
        try {
          final existingDebtDoc = await debtRef.get();
          final raw = existingDebtDoc.data()?['timestamp'];
          if (raw is Timestamp) thisDebtTimestamp = raw.toDate();
        } catch (e) {
          debugPrint('Could not read debt timestamp before deletion: $e');
        }
        if (thisDebtTimestamp != null && thisDebtTimestamp.isAtSameMomentAs(currentOldestUnpaidDebtDate)) {
          // This was the debt holding that date - find whichever debt
          // is oldest among what's left, excluding this one (its
          // deletion is only queued in the batch below, not yet
          // committed, so it would otherwise still count itself here).
          final remainingSnap = await _firestore
              .collection('facilities')
              .doc(_facilityId)
              .collection('debts')
              .where('clientId', isEqualTo: service.clientId)
              .orderBy('timestamp')
              .limit(2)
              .get();
          final remainingDocs = remainingSnap.docs.where((d) => d.id != debtRef.id).toList();
          final nextTs = remainingDocs.isEmpty ? null : remainingDocs.first.data()['timestamp'];
          newOldestUnpaidDebtDate = nextTs is Timestamp ? nextTs.toDate() : null;
          oldestUnpaidDebtDateChanged = true;
        }
      }
    }

    if (delta != 0) {
      batch.set(clientRef, {'balance': FieldValue.increment(delta)}, SetOptions(merge: true));
    }
    if (oldestUnpaidDebtDateChanged) {
      batch.set(
        clientRef,
        {
          'oldestUnpaidDebtDate':
              newOldestUnpaidDebtDate != null ? Timestamp.fromDate(newOldestUnpaidDebtDate) : null,
        },
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error handling service debt: $e');
    }
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
