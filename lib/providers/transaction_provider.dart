import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import 'facility_provider.dart';

class TransactionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => [..._transactions];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _facilityId;

  /// ---------------------------------------------------
  /// CLEAR ALL DATA WHEN FACILITY CHANGES
  /// ---------------------------------------------------
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _transactions.clear();
    notifyListeners();
  }

  /// ---------------------------------------------------
  /// REAL-TIME LISTENER
  /// ---------------------------------------------------
  void listenToTransactions(String facilityId) {
    if (_facilityId == facilityId) return; // already listening

    _facilityId = facilityId;
    _subscription?.cancel();

    if (facilityId.isEmpty) return;

    _subscription = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) =>
              TransactionModel.fromFirestore(doc.data(), doc.id))
          .toList();

      debugPrint(
          "TransactionProvider: Loaded ${_transactions.length} transactions for $facilityId");

      notifyListeners();
    }, onError: (error) {
      debugPrint("Transaction listen error: $error");
    });
  }

  /// ---------------------------------------------------
  /// ONE-TIME FETCH (optional, still available)
  /// ---------------------------------------------------
  Future<void> fetchTransactions(String facilityId) async {
    try {
      final snapshot = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      _transactions = snapshot.docs
          .map((doc) =>
              TransactionModel.fromFirestore(doc.data(), doc.id))
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
          .collection('facilities')
          .doc(facilityId)
          .collection('transactions')
          .doc();

      final newTransaction = transaction.copyWith(id: docRef.id);

      await docRef.set(newTransaction.toMap());

      // No manual add needed if real-time listener is active
      if (_subscription == null) {
        _transactions.add(newTransaction);
        notifyListeners();
      }

    } catch (e) {
      debugPrint('Error adding transaction: $e');
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
          .collection('facilities')
          .doc(facilityId)
          .collection('transactions')
          .doc(updatedTransaction.id)
          .set(updatedTransaction.toMap());

      // Update local list only if not listening in realtime
      if (_subscription == null) {
        final index = _transactions.indexWhere(
            (t) => t.id == updatedTransaction.id);
        if (index != -1) {
          _transactions[index] = updatedTransaction;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating transaction: $e');
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

      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('Facility ID missing, cannot delete transaction.');
        return;
      }

      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('transactions')
          .doc(transactionId)
          .delete();

      if (_subscription == null) {
        _transactions.removeWhere((t) => t.id == transactionId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }

  /// ---------------------------------------------------
  /// CALCULATIONS
  /// ---------------------------------------------------
  double get subProfit => _transactions
      .where((t) => t.type.toLowerCase() == 'profit')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type.toLowerCase() == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalOtherIncome => _transactions
      .where((t) => t.type.toLowerCase() == 'other income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get outstandingPayment => 0.0;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
