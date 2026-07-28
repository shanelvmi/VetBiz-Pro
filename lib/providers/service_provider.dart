import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service.dart';
import '../models/debt.dart';
import 'debt_provider.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DebtProvider debtProvider;

  ServiceProvider({required this.debtProvider});

  List<Service> _services = [];
  List<Service> get services => [..._services];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSubscription;
  String? _facilityId;

  String? get facilityId => _facilityId;

  /// Clear provider
  void clear() {
    _servicesSubscription?.cancel();
    _services.clear();
    _facilityId = null;
    notifyListeners();
  }

  /// ===== TOTALS (LIVE) =====
  double get totalAmount =>
      _services.fold(0.0, (s, x) => s + x.totalAmount);

  double get totalPaid =>
      _services.fold(0.0, (s, x) => s + x.totalPaid);

  double get totalExpenses =>
      _services.fold(0.0, (s, x) => s + x.totalExpenses);

  double get totalServiceProfit =>
      _services.fold(0.0, (s, x) => s + x.totalServiceProfit);

  /// ===== LISTEN =====
  void listenToServices(String facilityId) {
    if (_facilityId == facilityId) return;

    _servicesSubscription?.cancel();
    _facilityId = facilityId;

    final ref = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('services');

    _servicesSubscription = ref.snapshots().listen((snapshot) {
      _services = snapshot.docs
          .map((doc) => Service.fromFirestore(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  /// ===== ADD SERVICE =====
  Future<String?> addService(Service service) async {
    if (_facilityId == null) return null;

    final ref = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services');

    final serviceToSave = service.copyWith();

    try {
      final docRef = await ref.add({
        ...serviceToSave.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Local cache (instant UI)
      final saved = serviceToSave.copyWith(id: docRef.id);
      _services.insert(0, saved);
      notifyListeners();

      // Handle debt and transaction
      await _handleServiceDebt(saved, docRef.id);
      await _handleServiceTransaction(saved, docRef.id);

      return docRef.id;
    } catch (e) {
      debugPrint('ServiceProvider.addService error: $e');
      rethrow;
    }
  }

  /// ===== UPDATE SERVICE =====
  Future<void> updateService(Service service) async {
    if (_facilityId == null || service.id.isEmpty) return;

    final doc = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services')
        .doc(service.id);

    final updated = service.copyWith();

    try {
      await doc.update({
        ...updated.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _services.indexWhere((s) => s.id == service.id);
      if (index != -1) {
        _services[index] = updated;
        notifyListeners();
      }

      // Re-handle debt and transaction
      await _handleServiceDebt(updated, service.id);
      await _handleServiceTransaction(updated, service.id);
    } catch (e) {
      debugPrint('ServiceProvider.updateService error: $e');
      rethrow;
    }
  }

  /// ===== LOCAL UPDATE AFTER PAYMENT =====
  void updateLocalService(Service updated) {
    final index = _services.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;

    _services[index] = updated.copyWith();
    notifyListeners();
  }

  /// ===== DELETE =====
  Future<void> deleteService(String id) async {
    if (_facilityId == null) return;

    final doc = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('services')
        .doc(id);

    await doc.delete();

    _services.removeWhere((s) => s.id == id);
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
  }

  /// ===== DEBT =====
  Future<void> _handleServiceDebt(Service service, String serviceId) async {
    if (_facilityId == null) return;

    final owed = service.totalAmount - service.totalPaid;
    if (owed <= 0 || service.clientId == null) return;

    // Each service debt is its own document
    final debt = Debt(
      id: '',
      clientId: service.clientId!,
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
  Future<void> _handleServiceTransaction(
      Service service, String serviceId) async {
    if (_facilityId == null || service.itemsUsed.isEmpty) return;

    final ref = _firestore
        .collection('facilities')
        .doc(_facilityId)
        .collection('transactions');

    final old = await ref.where('serviceId', isEqualTo: serviceId).get();
    for (var d in old.docs) {
      await d.reference.delete();
    }

    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'System';

    await ref.add({
      'amount': service.totalExpenses,
      'category': 'Vet Service Expenses',
      'date': Timestamp.fromDate(DateTime.now()),
      'description': 'Items used for: ${service.name}',
      'recordedBy': name,
      'type': 'expense',
      'serviceId': serviceId,
    });
  }

  @override
  void dispose() {
    _servicesSubscription?.cancel();
    super.dispose();
  }
}
