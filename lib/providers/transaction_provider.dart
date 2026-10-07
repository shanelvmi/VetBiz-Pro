import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import 'facility_provider.dart';
import '../utils/activity_logger.dart';
import '../utils/receipt_numbering.dart';
import '../services/cursor_paginated_list_controller.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/activity_type.dart';

class TransactionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TransactionProvider() {
    transactionsListController = CursorPaginatedListController<TransactionModel>(
      pageSize: 25,
      fetchPage: _fetchTransactionsListPage,
      countCreatedAfter: _countNewTransactions,
    );
  }

  /// Same fix as Sales/Services: only stream the most recent [pageSize]
  /// transactions live; older ones page in on demand via
  /// [loadMoreTransactions] instead of loading a facility's entire
  /// transaction history every time.
  static const int pageSize = 25;

  List<TransactionModel> _liveTransactions = [];
  final List<TransactionModel> _olderTransactions = [];
  List<TransactionModel> get transactions => [..._liveTransactions, ..._olderTransactions];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
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
      TransactionModel transaction, BuildContext context) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

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
      final receiptNumber = await nextReceiptNumber(facilityId, counterName: counterName);

      final newTransaction = transaction.copyWith(id: docRef.id, receiptNumber: receiptNumber);

      await docRef.set({...newTransaction.toMap(), ...newTransaction.searchFields()});

      // No manual add needed if real-time listener is active
      if (_subscription == null) {
        _liveTransactions.add(newTransaction);
        notifyListeners();
      }

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.transactions.key,
        description: 'Added ${newTransaction.type}: ${newTransaction.description} - Tsh ${newTransaction.amount.toStringAsFixed(0)}',
      );

    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------
  /// UPDATE TRANSACTION
  /// ---------------------------------------------------
  Future<void> updateTransaction(
      TransactionModel updatedTransaction, BuildContext context) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('Facility ID missing, cannot update transaction.');
        return;
      }

      await _firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.transactions)
          .doc(updatedTransaction.id)
          .set({...updatedTransaction.toMap(), ...updatedTransaction.searchFields()});

      // Update local list only if not listening in realtime
      if (_subscription == null) {
        final index = _liveTransactions.indexWhere(
            (t) => t.id == updatedTransaction.id);
        if (index != -1) {
          _liveTransactions[index] = updatedTransaction;
          notifyListeners();
        }
      }

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.transactions.key,
        description: 'Updated ${updatedTransaction.type}: ${updatedTransaction.description} - Tsh ${updatedTransaction.amount.toStringAsFixed(0)}',
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
      BuildContext context, String transactionId) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

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

      final userInfo = await ActivityLogger.getCurrentUserInfo();

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
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => transactions
      .where((t) => t.type.toLowerCase() == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalOtherIncome => transactions
      .where((t) => t.type.toLowerCase() == 'other income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get outstandingPayment => 0.0;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
