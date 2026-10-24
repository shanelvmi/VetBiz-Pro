import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../models/admin_only_refusal.dart';
import 'facility_provider.dart';
import '../utils/activity_logger.dart';
import '../utils/receipt_numbering.dart';
import '../services/cursor_paginated_list_controller.dart';
import '../services/record_changes.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/activity_type.dart';
import '../config/money.dart';
import '../config/app_limits.dart';

class TransactionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;

  // Who is signed in, for the activity entries and the trash copy. Tests
  // pass their own; the app uses ActivityLogger.getCurrentUserInfo
  // (FirebaseAuth).
  final Future<Map<String, String>> Function() _currentUserInfo;

  // Whether the signed-in person is an admin (UserRoleProvider in the app).
  // Editing and deleting a transaction are admin-only (owner decision,
  // E4d-2); without one, nobody is.
  final bool Function() _isAdmin;
  static bool _nobodyIsAdmin() => false;

  TransactionProvider({
    FirebaseFirestore? firestore,
    Future<Map<String, String>> Function()? currentUserInfo,
    bool Function()? isAdmin,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUserInfo = currentUserInfo ?? ActivityLogger.getCurrentUserInfo,
        _isAdmin = isAdmin ?? _nobodyIsAdmin {
    transactionsListController = CursorPaginatedListController<TransactionModel>(
      pageSize: AppLimits.pageSize,
      fetchPage: _fetchTransactionsListPage,
      countCreatedAfter: _countNewTransactions,
    );
    // A service's expense transaction goes to Trash and comes back with it.
    _recordChanges = RecordChanges.listen({Collections.transactions, Collections.services}, _onTransactionsChanged);
  }

  /// Same fix as Sales/Services: only stream the most recent [pageSize]
  /// transactions live; older ones page in on demand via
  /// [loadMoreTransactions] instead of loading a facility's entire
  /// transaction history every time.
  static const int pageSize = AppLimits.pageSize;

  List<TransactionModel> _liveTransactions = [];
  final List<TransactionModel> _olderTransactions = [];
  List<TransactionModel> get transactions => [..._liveTransactions, ..._olderTransactions];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  late final StreamSubscription<RecordChange> _recordChanges;
  String? _facilityId;

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// ---------------------------------------------------
  /// CLEAR ALL DATA WHEN FACILITY CHANGES
  /// ---------------------------------------------------
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _liveTransactions.clear();
    _olderTransactions.clear();
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();
  }

  Query<Map<String, dynamic>> _baseQuery(String facilityId) => _firestore
      .collection(Collections.facilities)
      .doc(facilityId)
      .collection(Collections.transactions)
      .orderBy('date', descending: true);

  // ==================== Transactions list screen: real cursor pagination ====================
  //
  // A second, separate mechanism just for the Transactions list
  // screen's own display - does not replace `transactions` above.

  /// searchTerm searches description only (prefix match) - see
  /// SaleProvider's identical field for the full reasoning.
  ({String searchTerm, String? typeFilter}) _transactionsListQuery = (searchTerm: '', typeFilter: null);

  late final CursorPaginatedListController<TransactionModel> transactionsListController;

  String? _transactionsListFacilityId;

  ({String searchTerm, String? typeFilter}) updateTransactionsListFilters({
    required String facilityId,
    required String searchTerm,
    required String? typeFilter,
  }) {
    _transactionsListFacilityId = facilityId;
    _transactionsListQuery = (searchTerm: searchTerm.trim().toLowerCase(), typeFilter: typeFilter);
    return _transactionsListQuery;
  }

  Future<CursorPage<TransactionModel>> _fetchTransactionsListPage({
    required DateTime snapshotAt,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final facilityId = _transactionsListFacilityId;
    if (facilityId == null) {
      return const CursorPage(items: [], lastDocument: null, hasMore: false);
    }

    final q = _transactionsListQuery;
    final hasSearch = q.searchTerm.isNotEmpty;
    Query<Map<String, dynamic>> query =
        _firestore.collection(Collections.facilities).doc(facilityId).collection(Collections.transactions);

    if (q.typeFilter != null) {
      query = query.where('type', isEqualTo: q.typeFilter);
    }

    if (hasSearch) {
      query = query
          .where('descriptionLower', isGreaterThanOrEqualTo: q.searchTerm)
          .where('descriptionLower', isLessThan: '${q.searchTerm}\uf8ff')
          .orderBy('descriptionLower')
          .orderBy(FieldPath.documentId);
    } else {
      query = query
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(snapshotAt))
          .orderBy('date', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return CursorPage(
      items: snapshot.docs.map((d) => TransactionModel.fromFirestore(d.data(), d.id)).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= pageSize,
    );
  }

  Future<int> _countNewTransactions({required DateTime after}) async {
    final facilityId = _transactionsListFacilityId;
    if (facilityId == null) return 0;

    final q = _transactionsListQuery;
    if (q.searchTerm.isNotEmpty) return 0;

    Query<Map<String, dynamic>> query = _firestore
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.transactions)
        .where('date', isGreaterThan: Timestamp.fromDate(after));
    if (q.typeFilter != null) {
      query = query.where('type', isEqualTo: q.typeFilter);
    }

    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  /// ---------------------------------------------------
  /// REAL-TIME LISTENER (paginated - most recent page only)
  /// ---------------------------------------------------
  void listenToTransactions(String facilityId) {
    if (_facilityId == facilityId) return; // already listening

    _facilityId = facilityId;
    _liveTransactions = [];
    _olderTransactions.clear();
    _lastDocument = null;
    _hasMore = true;
    _subscription?.cancel();

    if (facilityId.isEmpty) return;

    _subscription = _baseQuery(facilityId)
        .limit(pageSize)
        .snapshots()
        .listen((snapshot) {
      _liveTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id))
          .toList();

      if (_olderTransactions.isEmpty) {
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= pageSize;
      }

      debugPrint(
          "TransactionProvider: Loaded ${_liveTransactions.length} live transactions for $facilityId");

      notifyListeners();
    }, onError: (error) {
      debugPrint("Transaction listen error: $error");
    });
  }

  /// A transaction (or a service with its expense) went to Trash or came
  /// back (BUG-1): the list starts over from its first page, and older pages
  /// loaded behind the live window are dropped and the window listened to
  /// again (as SaleProvider).
  void _onTransactionsChanged(String facilityId) {
    if (facilityId != _facilityId) return;
    unawaited(transactionsListController.refreshSession());
    if (_olderTransactions.isEmpty) return;
    _facilityId = null; // listenToTransactions skips the facility it already has
    listenToTransactions(facilityId);
  }

  /// Fetch the next page of older transactions (one-time read, not live).
  Future<void> loadMoreTransactions() async {
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
          .map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id))
          .toList();
      _olderTransactions.addAll(more);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= pageSize;
    } catch (e) {
      debugPrint('Error loading more transactions: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// ---------------------------------------------------
  /// ONE-TIME FETCH (optional, still available) - unchanged, used
  /// elsewhere for a full one-off fetch outside the live pagination.
  /// ---------------------------------------------------
  Future<void> fetchTransactions(String facilityId) async {
    try {
      final snapshot = await _baseQuery(facilityId).get();

      _liveTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  /// Convenience fetch
  Future<void> fetchTransactionsFromFirestore(BuildContext context) async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacilityId;

    if (facilityId == null || facilityId.isEmpty) {
      debugPrint("No facility selected, cannot fetch transactions.");
      return;
    }

    await fetchTransactions(facilityId);
  }

  /// ---------------------------------------------------
  /// ADD TRANSACTION
  /// ---------------------------------------------------
  Future<void> addTransaction(
      TransactionModel transaction, String? facilityId) async {
    try {
      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('Facility ID missing, cannot save transaction.');
        return;
      }

      final docRef = _firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.transactions)
          .doc();

      final counterName =
          transaction.type == 'expense' ? 'expenseReceiptNumber' : 'otherIncomeReceiptNumber';
      final receiptNumber = await nextReceiptNumber(facilityId, counterName: counterName, firestore: _firestore);

      final newTransaction = transaction.copyWith(id: docRef.id, receiptNumber: receiptNumber);

      await docRef.set({...newTransaction.toMap(), ...newTransaction.searchFields()});

      // No manual add needed if real-time listener is active
      if (_subscription == null) {
        _liveTransactions.add(newTransaction);
        notifyListeners();
      }

      final userInfo = await _currentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.transactions.key,
        description: 'Added ${newTransaction.type}: ${newTransaction.description} - ${Money.saved(newTransaction.amount)}',
      );

    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  /// What an edit never writes: they belong to the stored transaction, not
  /// to the Edit Transaction form (E4d-3).
  static const _keptOnEdit = ['date', 'recordedBy', 'receiptNumber'];

  /// ---------------------------------------------------
  /// UPDATE TRANSACTION
  /// ---------------------------------------------------
  Future<void> updateTransaction(
      TransactionModel updatedTransaction, String? facilityId) async {
    // Admin-only (owner decision, E4d-2): refused before anything is written.
    if (!_isAdmin()) throw const AdminOnlyException();
    try {
      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('Facility ID missing, cannot update transaction.');
        return;
      }

      final ref = _firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.transactions)
          .doc(updatedTransaction.id);

      // Only the fields AddTransactionScreen edits are written. The rest
      // stays as stored, read inside the same write: the receipt number, a
      // service expense's serviceId, the date and who recorded it. A set()
      // used to replace the whole document and drop the first two (E4d-3).
      // An empty payment method or note removes the stored one, as before.
      late TransactionModel saved;
      await _firestore.runTransaction((transaction) async {
        final stored = await transaction.get(ref);
        if (!stored.exists) throw StateError('The transaction no longer exists.');
        transaction.update(ref, {
          ...updatedTransaction.toMap(),
          if (updatedTransaction.paymentMethod == null) 'paymentMethod': FieldValue.delete(),
          if (updatedTransaction.note == null) 'note': FieldValue.delete(),
          ...updatedTransaction.searchFields(),
        }..removeWhere((field, _) => _keptOnEdit.contains(field)));
        final kept = TransactionModel.fromFirestore(stored.data()!, ref.id);
        saved = TransactionModel(
          id: kept.id, date: kept.date, recordedBy: kept.recordedBy, receiptNumber: kept.receiptNumber,
          description: updatedTransaction.description, amount: updatedTransaction.amount,
          type: updatedTransaction.type, category: updatedTransaction.category,
          paymentMethod: updatedTransaction.paymentMethod, note: updatedTransaction.note,
        );
      });

      // Update local list only if not listening in realtime
      if (_subscription == null) {
        final index = _liveTransactions.indexWhere(
            (t) => t.id == updatedTransaction.id);
        if (index != -1) {
          _liveTransactions[index] = saved;
          notifyListeners();
        }
      }

      final userInfo = await _currentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.transactions.key,
        description: 'Updated ${updatedTransaction.type}: ${updatedTransaction.description} - ${Money.saved(updatedTransaction.amount)}',
      );
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------
  /// DELETE TRANSACTION
  /// ---------------------------------------------------
  Future<void> deleteTransaction(
      String? facilityId, String transactionId) async {
    // Admin-only (owner decision, E4d-2): refused before anything is written.
    if (!_isAdmin()) throw const AdminOnlyException();
    try {
      final existingIndex = _liveTransactions.indexWhere((t) => t.id == transactionId);
      final deletedDescription = existingIndex != -1
          ? _liveTransactions[existingIndex].description
          : transactionId;

      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('Facility ID missing, cannot delete transaction.');
        return;
      }

      final docRef = _firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.transactions)
          .doc(transactionId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final userInfo = await _currentUserInfo();

      // Moved to `trash_transactions` instead of erased permanently, so
      // an accidental delete can be undone from the Trash screen - same
      // pattern already used for products/clients/services/sales.
      // Auto-purged after 30 days by a scheduled Cloud Function.
      await _firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.trashTransactions)
          .doc(transactionId)
          .set({
        ...snapshot.data()!,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': userInfo['userName'],
      });

      await docRef.delete();
      RecordChanges.changed(facilityId, Collections.transactions);

      if (_subscription == null) {
        _liveTransactions.removeWhere((t) => t.id == transactionId);
        notifyListeners();
      }

      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.transactions.key,
        description: 'Deleted transaction: $deletedDescription',
      );
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------
  /// CALCULATIONS - reflect only what's currently loaded (live window +
  /// paged-through history). For period totals (Today/This Week/etc.) use
  /// DashboardSummaryService, which reads precomputed daily aggregates.
  /// ---------------------------------------------------
  double get subProfit => transactions
      .where((t) => t.type.toLowerCase() == 'profit')
      .fold(0.0, (total, t) => total + t.amount);

  double get totalExpenses => transactions
      .where((t) => t.type.toLowerCase() == 'expense')
      .fold(0.0, (total, t) => total + t.amount);

  double get totalOtherIncome => transactions
      .where((t) => t.type.toLowerCase() == 'other income')
      .fold(0.0, (total, t) => total + t.amount);

  double get outstandingPayment => 0.0;

  @override
  void dispose() {
    _subscription?.cancel();
    _recordChanges.cancel();
    super.dispose();
  }
}
