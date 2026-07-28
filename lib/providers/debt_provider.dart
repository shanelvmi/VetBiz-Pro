import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt.dart';

class DebtProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Debt> _debts = [];
  List<Debt> get debts => [..._debts];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _facilityId;

  /// Clear all debts (used when switching facility or logout)
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _debts.clear();
    notifyListeners();
  }

  /// Listen to debts in real-time for a facility
  void listenToDebts(String facilityId) {
    if (_facilityId == facilityId) return;

    _facilityId = facilityId;
    _subscription?.cancel();

    if (facilityId.isEmpty) return;

    _subscription = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('debts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _debts = snapshot.docs
          .map((doc) => Debt.fromMap(doc.id, doc.data()))
          .toList();

      debugPrint(
          'DebtProvider: loaded ${_debts.length} debts for facility $facilityId');
      notifyListeners();
    }, onError: (error) {
      debugPrint('DebtProvider error: $error');
    });
  }

  /// Add a new debt
  Future<String?> addDebt(Debt debt, String facilityId) async {
    if (facilityId.isEmpty) return null;
    try {
      final docRef = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .add(debt.toMap());
      debugPrint(
          'DebtProvider: added debt ${docRef.id} for client ${debt.clientId}');
      return docRef.id;
    } catch (e) {
      debugPrint('DebtProvider addDebt error: $e');
      return null;
    }
  }

  /// Update an existing debt
  Future<void> updateDebt(Debt debt, String facilityId) async {
    if (facilityId.isEmpty || debt.id.isEmpty) return;
    try {
      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .doc(debt.id)
          .update(debt.toMap());
      debugPrint('DebtProvider: updated debt ${debt.id}');
    } catch (e) {
      debugPrint('DebtProvider updateDebt error: $e');
    }
  }

  /// Delete a debt
  Future<void> deleteDebt(String debtId, String facilityId) async {
    if (facilityId.isEmpty || debtId.isEmpty) return;
    try {
      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .doc(debtId)
          .delete();
      debugPrint('DebtProvider: deleted debt $debtId');
    } catch (e) {
      debugPrint('DebtProvider deleteDebt error: $e');
    }
  }

  /// Total outstanding debt across all clients
  double totalOutstanding() {
    return _debts.fold(0.0, (sum, debt) => sum + debt.amountOwed);
  }

  /// Filter debts for a specific client
  List<Debt> debtsByClient(String clientId) {
    return _debts.where((d) => d.clientId == clientId).toList();
  }

  /// Add or update debt for a client (works for sales or services)
  Future<void> addOrUpdateDebtForClient(Debt debt) async {
    if (_facilityId == null || debt.clientId.isEmpty) return;

    if (debt.source == 'Service') {
      // Each service gets its own debt document → NO MERGE
      await addDebt(debt, _facilityId!);
    } else {
      // Sales: merge by client + source
      final existingDebts = _debts
          .where((d) => d.clientId == debt.clientId && d.source == debt.source)
          .toList();

      if (existingDebts.isEmpty) {
        await addDebt(debt, _facilityId!);
      } else {
        final existingDebt = existingDebts.first;
        final updatedDebt = existingDebt.copyWith(
          amountOwed: existingDebt.amountOwed + debt.amountOwed,
          items: [...existingDebt.items, ...debt.items],
          updatedAt: DateTime.now(),
        );
        await updateDebt(updatedDebt, _facilityId!);
      }
    }
  }

  /// Group debts by client and return summaries with clientName dynamically fetched
  Future<List<ClientDebtSummary>> summarizeDebts(String facilityId) async {
    final Map<String, List<Debt>> grouped = {};
    for (var debt in _debts) {
      grouped.putIfAbsent(debt.clientId, () => []).add(debt);
    }

    List<ClientDebtSummary> summaries = [];

    for (var entry in grouped.entries) {
      final clientId = entry.key;
      final clientDebts = entry.value;

      // Fetch client name dynamically
      String clientName = 'Unknown';
      try {
        final doc = await _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('clients')
            .doc(clientId)
            .get();
        if (doc.exists) {
          clientName = doc.data()?['name'] ?? 'Unknown';
        }
      } catch (_) {}

      final totalOwed =
          clientDebts.fold(0.0, (sum, d) => sum + d.amountOwed);
      final lastDebtDate = clientDebts
          .map((d) => d.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      summaries.add(ClientDebtSummary(
        clientId: clientId,
        clientName: clientName,
        totalOwed: totalOwed,
        lastDebtDate: lastDebtDate,
        debts: clientDebts,
      ));
    }

    return summaries;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Helper class for grouped debts by client
class ClientDebtSummary {
  final String clientId;
  final String clientName;
  final double totalOwed;
  final DateTime lastDebtDate;
  final List<Debt> debts;

  ClientDebtSummary({
    required this.clientId,
    required this.clientName,
    required this.totalOwed,
    required this.lastDebtDate,
    required this.debts,
  });
}
