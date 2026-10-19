import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service.dart';
import '../models/debt.dart';
import '../models/restore_outcome.dart';
import '../services/record_trash.dart';
import 'debt_provider.dart';
import 'product_provider.dart';
import '../utils/activity_logger.dart';
import '../utils/receipt_numbering.dart';
import '../services/cursor_paginated_list_controller.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/activity_type.dart';
import '../config/money.dart';
import '../config/app_limits.dart';
import '../config/app_ranges.dart';
import '../config/payment_methods.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final DebtProvider? debtProvider;

  // Who is signed in, for the activity entry, the expense and the payment.
  // Tests pass their own; the app uses ActivityLogger.getCurrentUserInfo
  // (FirebaseAuth).
  final Future<Map<String, String>> Function() _currentUserInfo;

  // Delete to Trash and restore from it (docs/design/delete_restore.md).
  late final RecordTrash _trash;

  ServiceProvider({
    this.debtProvider,
    FirebaseFirestore? firestore,
    Future<Map<String, String>> Function()? currentUserInfo,
    String Function()? deletedBy,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUserInfo = currentUserInfo ?? ActivityLogger.getCurrentUserInfo {
    _trash = RecordTrash(_firestore, trashedServiceType,
        currentUserInfo: _currentUserInfo, deletedBy: deletedBy ?? RecordTrash.signedInUser);
    servicesListController = CursorPaginatedListController<Service>(
      pageSize: AppLimits.pageSize,
      fetchPage: _fetchServicesListPage,
      countCreatedAfter: _countNewServices,
    );
  }

  /// How many services to fetch per page. The live listener holds the
  /// most recently-touched [pageSize] services in real time; older pages
  /// are fetched on demand via [loadMoreServices]. This used to load a
  /// facility's ENTIRE service history on every app open - same issue we
  /// fixed for sales, fixed here the same way.
  static const int pageSize = AppLimits.pageSize;

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
      .collection(Collections.facilities)
      .doc(facilityId)
      .collection(Collections.services)
      // Ordered by updatedAt (always present - see Service.toMap, it
      // defaults to serverTimestamp) rather than serviceDate (nullable,
      // user-editable) so pagination has a reliable, always-populated
      // cursor field. serviceDate is used separately for day-bucketing in
      // the dailyServiceSummaries Cloud Function.
      .orderBy(Fields.updatedAt, descending: true);

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
        return now.subtract(AppRanges.week);
      case 'Last 30 days':
        return now.subtract(AppRanges.month);
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
        _firestore.collection(Collections.facilities).doc(facilityId).collection(Collections.services);

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
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.services)
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

  /// A new service id, made on the device (no read, works offline). The
  /// service form makes one when it opens and passes it to [addService] as
  /// the service's id, so a retry of the same service reuses it.
  String newServiceId() => _firestore.collection(Collections.services).doc().id;

  /// ===== ADD SERVICE =====
  /// Records a service and everything it changes in ONE transaction
  /// (docs/design/atomic_sales.md, option b): the service, one unit of
  /// stock per item matched to a product (FIFO), the receipt number, the
  /// client's balance, the debt (debts/service_{id}), the expense for the
  /// items bought outside (transactions/service_{id}), the upfront payment
  /// (payments/service_{id}) and the activity entry
  /// (activity_logs/service_{id}). Either all of it is saved or none of it.
  ///
  /// [service].id is the id the form made when it opened; a retry passes
  /// the same one. If that service is already saved (the first attempt
  /// landed but its answer was lost), this returns its id and writes
  /// nothing, so a retry can never record the service twice or deduct the
  /// stock again.
  ///
  /// Nothing is swallowed: it throws [InsufficientStockException] when the
  /// stock does not cover a matched item, and the Firestore error otherwise
  /// (for example offline). In both cases nothing was written. The list on
  /// screen gets the service only after the commit.
  Future<String?> addService(Service service) async {
    final facilityId = _facilityId;
    if (facilityId == null) return null;

    final facilityRef = _firestore.collection(Collections.facilities).doc(facilityId);
    final servicesRef = facilityRef.collection(Collections.services);
    final serviceRef = service.id.isEmpty ? servicesRef.doc() : servicesRef.doc(service.id);
    final serviceId = serviceRef.id;

    // Read before the transaction: it can read nothing after its first
    // write, and this doesn't change within a service.
    final userInfo = await _currentUserInfo();

    // Candidate batches are found by a query, which a transaction cannot
    // run, so outside it (as deductSellableFIFO does); the transaction then
    // re-reads each one, so it plans from current values.
    final productIds = service.itemsUsed.map((item) => item['productId'] as String?).nonNulls.toSet();
    final candidateRefs = <String, List<DocumentReference<Map<String, dynamic>>>>{};
    for (final productId in productIds) {
      final snap = await facilityRef
          .collection(Collections.products)
          .doc(productId)
          .collection(Collections.batches)
          .where('sellableQty', isGreaterThan: 0)
          .get();
      candidateRefs[productId] =
          (snap.docs.toList()..sort(ProductProvider.compareByExpiry)).map((d) => d.reference).toList();
    }

    final clientId = (service.clientId == null || service.clientId!.isEmpty) ? null : service.clientId;
    final clientRef = clientId == null ? null : facilityRef.collection(Collections.clients).doc(clientId);

    // The transaction returns null when the stock doesn't cover the
    // service: it then ends having written nothing, and the exception is
    // thrown below, outside it, so it reaches the screen as itself on
    // every platform.
    String? shortage;
    final saved = await _firestore.runTransaction<Service?>((transaction) async {
      shortage = null;

      // --- Reads (all of them before any write) ---
      final existing = await transaction.get(serviceRef);
      if (existing.exists) {
        // A retry of a service that was saved.
        return Service.fromFirestore(existing.data()!, serviceId);
      }

      final receipt = await claimReceiptNumber(transaction, _firestore, facilityId);

      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final batchSnaps = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final productId in productIds) {
        batchSnaps[productId] = [
          for (final ref in candidateRefs[productId]!) await transaction.get(ref),
        ];
        productSnaps[productId] =
            await transaction.get(facilityRef.collection(Collections.products).doc(productId));
      }

      final clientSnap = clientRef == null ? null : await transaction.get(clientRef);

      // --- Plan (writes nothing) ---
      // One unit per item matched to a real product, FIFO (soonest-expiry
      // batch first, same as Sales), recording the batches it came from so
      // a delete or an edit can put it back. Items bought outside never
      // touch stock.
      final stockPlan = SellableStockPlan();
      final updatedItems = <Map<String, dynamic>>[];
      try {
        for (final item in service.itemsUsed) {
          final productId = item['productId'] as String?;
          if (productId == null) {
            updatedItems.add(item);
            continue;
          }
          final allocations = stockPlan.take(
            product: productSnaps[productId]!,
            batches: batchSnaps[productId]!,
            quantity: 1,
          );
          updatedItems.add({...item, 'batchAllocations': allocations});
        }
      } on InsufficientStockException catch (e) {
        shortage = e.message;
        return null;
      }

      final serviceToSave =
          service.copyWith(id: serviceId, itemsUsed: updatedItems, receiptNumber: receipt.value);

      // --- Writes ---
      transaction.set(serviceRef, {
        ...serviceToSave.toMap(),
        ...serviceToSave.searchFields(),
        Fields.updatedAt: FieldValue.serverTimestamp(),
      });
      stockPlan.apply(transaction);
      receipt.write(transaction);

      if (clientRef != null) {
        _writeNewServiceDebt(transaction, facilityRef, clientRef, clientSnap!, serviceToSave);
      }

      // Only the items NOT matched to a real product become a new cash
      // expense - stock-matched items were already paid for when that
      // stock was purchased, so expensing them again here would
      // double-count the cost. See Service.externalExpenseTotal.
      // The user's fullName from Firestore: Firebase Auth's own displayName
      // is never set in this app.
      final expense = _newExpense(serviceToSave, serviceId, userInfo['userName']!);
      if (expense != null) {
        transaction.set(facilityRef.collection(Collections.transactions).doc('service_$serviceId'), expense);
      }

      // Record the upfront amount collected (if any) as a payment - the
      // same fix applied to sales, so dailyCollections captures cash
      // collected on services too, not just sales.
      if (serviceToSave.totalPaid > 0) {
        transaction.set(facilityRef.collection(Collections.payments).doc('service_$serviceId'), {
          'clientId': serviceToSave.clientId,
          'clientName': serviceToSave.clientName,
          'serviceId': serviceId,
          'amount': serviceToSave.totalPaid,
          'timestamp': FieldValue.serverTimestamp(),
          'paidById': userInfo[Fields.userId] ?? '',
          'source': 'service',
          'paymentMethod': serviceToSave.paymentMethod,
          'clientNameLower': (serviceToSave.clientName ?? '').toLowerCase(),
        });
      }

      ActivityLogger.logActivityIn(
        transaction,
        facilityRef.collection(Collections.activityLogs).doc('service_$serviceId'),
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'] ?? 'Unknown',
        actionType: ActivityType.services.key,
        description:
            'Recorded service for ${serviceToSave.clientName ?? 'Walk-in'} - ${Money.savedWhole(serviceToSave.totalAmount)}',
      );

      return serviceToSave;
    });

    if (saved == null) throw InsufficientStockException(shortage ?? 'Not enough sellable stock');

    // Only now, after the commit, does the list on screen show it.
    if (_findCachedService(serviceId) == null) {
      _liveServices.insert(0, saved);
      notifyListeners();
    }
    return serviceId;
  }

  /// The debt part of [addService], inside its transaction: what
  /// [_handleServiceDebt] does for a new service (no previous version, so
  /// no old debt to replace). The client's balance goes up by what is
  /// still owed; an unpaid service gets its debt as debts/service_{id}
  /// (deterministic, so this service always maps to exactly one debt
  /// document), and becomes the client's oldest unpaid debt if they had
  /// none.
  void _writeNewServiceDebt(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> facilityRef,
    DocumentReference<Map<String, dynamic>> clientRef,
    DocumentSnapshot<Map<String, dynamic>> clientSnap,
    Service service,
  ) {
    final owed = service.totalAmount - service.totalPaid;
    final clientData = clientSnap.data();
    final rawOldest = clientData?['oldestUnpaidDebtDate'];
    final update = <String, dynamic>{};

    if (owed > 0) {
      final debtRef = facilityRef.collection(Collections.debts).doc('service_${service.id}');
      final debt = Debt(
        id: debtRef.id,
        clientId: service.clientId!,
        clientName: service.clientName,
        clientPhone: clientData?['phone'] as String?,
        serviceId: service.id,
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
      transaction.set(debtRef, debt.toMap());

      // A brand-new debt, and the client had no other unpaid debt at
      // all - this one becomes the (only, therefore oldest) unpaid debt.
      if (rawOldest is! Timestamp) {
        update['oldestUnpaidDebtDate'] = Timestamp.fromDate(debt.timestamp);
      }
    }
    if (owed != 0) update['balance'] = FieldValue.increment(owed);
    if (update.isEmpty) return;

    if (clientSnap.exists) {
      transaction.update(clientRef, update);
    } else {
      // As before: a client deleted while the form was open.
      transaction.set(clientRef, update, SetOptions(merge: true));
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
        .collection(Collections.facilities)
        .doc(_facilityId)
        .collection(Collections.services)
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
        Fields.updatedAt: FieldValue.serverTimestamp(),
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
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.services.key,
        description: 'Updated service for ${updated.clientName ?? 'Walk-in'} - ${Money.savedWhole(updated.totalAmount)}',
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
  /// Moves the service to `trash_services` in ONE transaction (auto-purged
  /// after 30 days by a scheduled Cloud Function): the trash copy (with its
  /// expense, so a restore can give it back), its stock back on the batches
  /// it came from (always, cached or not), its debt and expense removed,
  /// the client's balance and oldest unpaid date lowered, and the activity
  /// entry. The upfront payment stays counted. Nothing is swallowed.
  Future<void> deleteService(String id) async {
    final facilityId = _facilityId;
    if (facilityId == null) return;
    await _trash.delete(facilityId, id);
    _liveServices.removeWhere((s) => s.id == id);
    _olderServices.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Puts a service back from Trash with its stock, debt, balance and
  /// expense, in ONE transaction (RecordTrash.restore: refusals, retries).
  Future<RestoreResult> restoreService(String id, String facilityId) => _trash.restore(facilityId, id);

  /// A service, for RecordTrash.
  static final trashedServiceType = TrashedRecordType(
    liveCollection: Collections.services,
    trashCollection: Collections.trashServices,
    idPrefix: 'service',
    debtLinkField: 'serviceId',
    itemsField: 'itemsUsed',
    itemNameField: 'itemName',
    oneUnitPerItem: true,
    actionType: ActivityType.services.key,
    deletedDescription: (data) =>
        'Deleted service for ${data['clientName'] ?? 'Walk-in'} - ${Money.savedAsStored(data['totalAmount'] ?? 0)}',
    searchFields: (id, data) => Service.fromFirestore(data, id).searchFields(),
    newDebt: (id, data, owed, clientPhone) {
      final service = Service.fromFirestore(data, id);
      // As _writeNewServiceDebt writes it, dated at the service.
      return Debt(
        id: 'service_$id',
        clientId: service.clientId!,
        clientName: service.clientName,
        clientPhone: clientPhone,
        serviceId: id,
        saleId: null,
        source: 'Service',
        amountOwed: owed,
        timestamp: service.serviceDate ?? DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          {
            'serviceName': service.name,
            'category': service.category,
            'totalAmount': service.totalAmount,
            'totalPaid': service.totalPaid,
          }
        ],
      ).toMap();
    },
    recomputedExpense: (id, data, recordedBy) => _newExpense(Service.fromFirestore(data, id), id, recordedBy),
  );

  /// The expense for the items of [service] bought outside, as
  /// transactions/service_{id} holds it; null when there are none. Only the
  /// items NOT matched to a real product count (Service.externalExpenseTotal).
  static Map<String, dynamic>? _newExpense(Service service, String serviceId, String recordedBy) {
    final expenseAmount = service.externalExpenseTotal;
    if (expenseAmount <= 0) return null;
    // Same filter as Service.externalExpenseTotal - only the items that
    // actually became this expense, so an audit can see exactly what
    // was expensed without opening the service record separately.
    final externalItemNames = service.itemsUsed
        .where((item) => item['productId'] == null)
        .map((item) => (item['itemName'] ?? '').toString())
        .where((itemName) => itemName.isNotEmpty)
        .toList();
    final itemsSummary = externalItemNames.isNotEmpty ? externalItemNames.join(', ') : 'N/A';
    return {
      'amount': expenseAmount,
      'category': 'Vet Service Expenses',
      'date': Timestamp.fromDate(DateTime.now()),
      'description': 'Items used for ${service.name}: $itemsSummary',
      'recordedBy': recordedBy,
      'type': 'expense',
      'serviceId': serviceId,
      'paymentMethod': service.paymentMethod ?? PaymentMethod.cash.key,
    };
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
        _firestore.collection(Collections.facilities).doc(_facilityId).collection(Collections.debts).doc('service_$serviceId');
    final clientRef =
        _firestore.collection(Collections.facilities).doc(_facilityId).collection(Collections.clients).doc(service.clientId);

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
              .collection(Collections.facilities)
              .doc(_facilityId)
              .collection(Collections.debts)
              .where('clientId', isEqualTo: service.clientId)
              .orderBy('timestamp')
              .limit(AppLimits.moreThanOneCheck)
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
        .collection(Collections.facilities)
        .doc(_facilityId)
        .collection(Collections.transactions);

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
    final userInfo = await _currentUserInfo();
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
      'paymentMethod': service.paymentMethod ?? PaymentMethod.cash.key,
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
          firestore: _firestore,
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
          firestore: _firestore,
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
        .collection(Collections.facilities)
        .doc(_facilityId)
        .collection(Collections.products)
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
