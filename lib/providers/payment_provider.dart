import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment.dart';
import '../models/ledger_entry.dart';
import '../services/snapshot_ledger_controller.dart';
import 'sale_provider.dart';
import 'service_provider.dart';

class PaymentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PaymentProvider() {
    ledgerController = SnapshotLedgerController<LedgerEntry>(
      fetchLedger: _fetchLedger,
      countNewEntries: _countNewLedgerEntries,
    );
  }

  List<Payment> _payments = [];
  List<Payment> get payments => [..._payments];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  // ==================== Payments screen: snapshot-stable merged ledger ====================

  late final SnapshotLedgerController<LedgerEntry> ledgerController;

  String? _ledgerFacilityId;

  /// searchTerm: prefix match against clientNameLower - ignored
  /// entirely when initialClientId is set (see _fetchLedger for why -
  /// requiring it there would incorrectly exclude valid entries
  /// missing a clientName field, the exact bug already fixed once in
  /// AddPaymentScreen). Same trade-off as every other module this
  /// session: a name search can't combine with the date-range/snapshot
  /// boundary in the same Firestore query (one range filter per
  /// query), so an active search is a point-in-time lookup across all
  /// dates, not bounded to the chosen range - deliberate, not an
  /// oversight, for the same reason searching is more often "find this
  /// specific thing right now" than passive browsing. typeFilter
  /// matches LedgerEntry.type values directly
  /// ('sale'/'service'/'debt_repayment'/'other_income'), null meaning
  /// no filter. initialClientId scopes to one specific client's own
  /// history (opened from that client's own page) and excludes Other
  /// Income entirely, since those are never tied to a client.
  ({String searchTerm, String? typeFilter, String? methodFilter, String? initialClientId}) _ledgerQuery = (
    searchTerm: '',
    typeFilter: null,
    methodFilter: null,
    initialClientId: null,
  );

  ({String searchTerm, String? typeFilter, String? methodFilter, String? initialClientId}) updateLedgerFilters({
    required String facilityId,
    required String searchTerm,
    required String? typeFilter,
    required String? methodFilter,
    required String? initialClientId,
  }) {
    _ledgerFacilityId = facilityId;
    _ledgerQuery = (
      searchTerm: searchTerm.trim().toLowerCase(),
      typeFilter: typeFilter,
      methodFilter: methodFilter,
      initialClientId: initialClientId,
    );
    return _ledgerQuery;
  }

  LedgerEntry _paymentDocToEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final source = (data['source'] as String?) ?? 'sale';
    return LedgerEntry(
      type: source,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientId: data['clientId'] as String?,
      clientName: data['clientName'] as String?,
      clientPhone: data['clientPhone'] as String?,
      description: _labelForSource(source),
      paymentMethod: data['paymentMethod'] as String?,
      paidById: data['paidById'] as String?,
      saleId: data['saleId'] as String?,
      serviceId: data['serviceId'] as String?,
      debtId: data['debtId'] as String?,
      sortId: doc.id,
    );
  }

  String _labelForSource(String source) {
    switch (source) {
      case 'sale':
        return 'Sale payment';
      case 'service':
        return 'Service payment';
      case 'debt_repayment':
        return 'Debt repayment';
      default:
        return source;
    }
  }

  Future<List<LedgerEntry>> _fetchLedger({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime snapshotAt,
  }) async {
    final facilityId = _ledgerFacilityId;
    if (facilityId == null) return [];

    final q = _ledgerQuery;
    // Never look past whichever is earlier - the chosen range's own
    // end, or the moment this browsing session started - so a record
    // created after the session opened can't enter it even when the
    // date range itself would otherwise include today.
    final effectiveEnd = rangeEnd.isBefore(snapshotAt) ? rangeEnd : snapshotAt;
    final facilityRef = _firestore.collection('facilities').doc(facilityId);

    final entries = <LedgerEntry>[];

    // Other Income (type == 'other_income') is never tied to a client
    // at all, so it's excluded whenever this ledger is scoped to one
    // client's own history, and whenever searching by client name
    // specifically (an Other Income entry could never match that
    // search anyway).
    final includeOtherIncome = q.initialClientId == null &&
        q.searchTerm.isEmpty &&
        (q.typeFilter == null || q.typeFilter == 'other_income');
    final includePayments = q.typeFilter == null || q.typeFilter != 'other_income';

    if (includePayments) {
      Query<Map<String, dynamic>> paymentsQuery = facilityRef.collection('payments');
      if (q.initialClientId != null) {
        paymentsQuery = paymentsQuery.where('clientId', isEqualTo: q.initialClientId);
      }
      if (q.typeFilter != null) {
        paymentsQuery = paymentsQuery.where('source', isEqualTo: q.typeFilter);
      }
      if (q.methodFilter != null) {
        paymentsQuery = paymentsQuery.where('paymentMethod', isEqualTo: q.methodFilter);
      }

      if (q.initialClientId == null && q.searchTerm.isNotEmpty) {
        // Name search only applies when browsing broadly - see the
        // class-level doc comment on this query record.
        paymentsQuery = paymentsQuery
            .where('clientNameLower', isGreaterThanOrEqualTo: q.searchTerm)
            .where('clientNameLower', isLessThan: '${q.searchTerm}\uf8ff')
            .orderBy('clientNameLower');
      } else {
        paymentsQuery = paymentsQuery
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(effectiveEnd))
            .orderBy('timestamp', descending: true);
      }

      final paymentsSnap = await paymentsQuery.get();
      entries.addAll(paymentsSnap.docs.map(_paymentDocToEntry));

      // initialClientId's own further text search (typing beyond the
      // pre-filled client name) stays a small, client-side refinement
      // over this already one-client-scoped, date-bounded result set -
      // deliberately not folded into the query itself, since requiring
      // a clientNameLower match here would incorrectly exclude entries
      // that never had a clientName field set at all (the exact bug
      // AddPaymentScreen's own comment describes fixing once already).
      if (q.initialClientId != null && q.searchTerm.isNotEmpty) {
        entries.removeWhere((e) =>
            !(e.clientName ?? '').toLowerCase().contains(q.searchTerm) &&
            !e.description.toLowerCase().contains(q.searchTerm));
      }
    }

    if (includeOtherIncome) {
      Query<Map<String, dynamic>> txQuery = facilityRef
          .collection('transactions')
          .where('type', isEqualTo: 'other income')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(effectiveEnd))
          .orderBy('date', descending: true);
      if (q.methodFilter != null) {
        txQuery = txQuery.where('paymentMethod', isEqualTo: q.methodFilter);
      }

      final txSnap = await txQuery.get();
      for (final doc in txSnap.docs) {
        final data = doc.data();
        entries.add(LedgerEntry(
          type: 'other_income',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          timestamp: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          description: (data['description'] as String?)?.isNotEmpty == true
              ? data['description'] as String
              : 'Other income',
          paymentMethod: data['paymentMethod'] as String?,
          sortId: doc.id,
        ));
      }
    }

    // Deterministic - timestamp DESC, then sortId DESC as a tie-breaker
    // so two entries sharing the exact same timestamp never have an
    // order that could vary between loads.
    entries.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) return byTime;
      return b.sortId.compareTo(a.sortId);
    });

    return entries;
  }

  Future<int> _countNewLedgerEntries({
    required DateTime after,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final facilityId = _ledgerFacilityId;
    if (facilityId == null) return 0;

    final q = _ledgerQuery;
    if (q.searchTerm.isNotEmpty) return 0;

    final facilityRef = _firestore.collection('facilities').doc(facilityId);
    var total = 0;

    final includeOtherIncome = q.initialClientId == null && (q.typeFilter == null || q.typeFilter == 'other_income');
    final includePayments = q.typeFilter == null || q.typeFilter != 'other_income';

    if (includePayments) {
      Query<Map<String, dynamic>> paymentsQuery =
          facilityRef.collection('payments').where('timestamp', isGreaterThan: Timestamp.fromDate(after));
      if (q.initialClientId != null) {
        paymentsQuery = paymentsQuery.where('clientId', isEqualTo: q.initialClientId);
      }
      if (q.typeFilter != null) {
        paymentsQuery = paymentsQuery.where('source', isEqualTo: q.typeFilter);
      }
      if (q.methodFilter != null) {
        paymentsQuery = paymentsQuery.where('paymentMethod', isEqualTo: q.methodFilter);
      }
      final agg = await paymentsQuery.count().get();
      total += agg.count ?? 0;
    }

    if (includeOtherIncome) {
      Query<Map<String, dynamic>> txQuery = facilityRef
          .collection('transactions')
          .where('type', isEqualTo: 'other income')
          .where('date', isGreaterThan: Timestamp.fromDate(after));
      if (q.methodFilter != null) {
        txQuery = txQuery.where('paymentMethod', isEqualTo: q.methodFilter);
      }
      final agg = await txQuery.count().get();
      total += agg.count ?? 0;
    }

    return total;
  }

  /// Listen to all payments for a facility
  void listenToPayments(String facilityId) {
    _subscription?.cancel();
    if (facilityId.isEmpty) return;

    _subscription = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _payments = snapshot.docs
          .map((doc) => Payment.fromFirestore(doc.data(), doc.id))
          .toList();

      debugPrint('PaymentProvider: loaded ${_payments.length} payments');
      notifyListeners();
    }, onError: (error) {
      debugPrint('PaymentProvider error: $error');
    });
  }

  /// Add a new payment and update related sale or service
  Future<String?> addPayment({
    required Payment payment,
    SaleProvider? saleProvider,
    ServiceProvider? serviceProvider,
    required String facilityId,
  }) async {
    if (facilityId.isEmpty) return null;

    try {
      // Add payment to Firestore
      final docRef = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .add({...payment.toMap(), ...payment.searchFields()});

      debugPrint(
          'PaymentProvider: added payment ${docRef.id} for sale ${payment.saleId} or service ${payment.serviceId}');

      /// -----------------------
      /// Update related Sale
      /// -----------------------
      if (payment.saleId != null &&
          payment.saleId!.isNotEmpty &&
          saleProvider != null) {
        final saleIndex =
            saleProvider.sales.indexWhere((s) => s.id == payment.saleId);
        if (saleIndex != -1) {
          final sale = saleProvider.sales[saleIndex];
          final updatedTotalPaid = sale.totalPaid + payment.amount;

          // Recompute realized/unrealized profit
          final updatedItems = sale.items.map((item) {
            double paymentRatio = 0.0;
            if (sale.totalAmount > 0) {
              paymentRatio =
                  (updatedTotalPaid / sale.totalAmount).clamp(0.0, 1.0);
            }
            final realized = item.profit * paymentRatio;
            final unrealized = item.profit - realized;

            return item.copyWith(
              realizedProfit: realized,
              unrealizedProfit: unrealized,
            );
          }).toList();

          final totalProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.profit);
          final realizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
          final unrealizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

          final updatedSale = sale.copyWith(
            totalPaid: updatedTotalPaid,
            items: updatedItems,
            totalProfit: totalProfit,
            realizedProfit: realizedProfit,
            unrealizedProfit: unrealizedProfit,
            updatedAt: DateTime.now(),
          );

          await _firestore
              .collection('facilities')
              .doc(facilityId)
              .collection('sales')
              .doc(updatedSale.id)
              .update({
            ...updatedSale.toMap(),
            ...updatedSale.searchFields(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      /// -----------------------
      /// Update related Service
      /// -----------------------
      if (payment.serviceId != null &&
          payment.serviceId!.isNotEmpty &&
          serviceProvider != null) {
        final serviceIndex =
            serviceProvider.services.indexWhere((s) => s.id == payment.serviceId);
        if (serviceIndex != -1) {
          final service = serviceProvider.services[serviceIndex];
          final updatedTotalPaid = service.totalPaid + payment.amount;

          final updatedService = service.copyWith(
            totalPaid: updatedTotalPaid,
            updatedAt: DateTime.now(),
          );

          await serviceProvider.updateService(updatedService);
        }
      }

      return docRef.id;
    } catch (e) {
      debugPrint('PaymentProvider addPayment error: $e');
      return null;
    }
  }

  /// Total payments made for a specific client
  double totalPaidByClient(String clientId) {
    return _payments
        .where((p) => p.clientId == clientId)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Delete a payment and update related sale or service
  Future<void> deletePayment({
    required String paymentId,
    SaleProvider? saleProvider,
    ServiceProvider? serviceProvider,
    required String facilityId,
  }) async {
    if (facilityId.isEmpty || paymentId.isEmpty) return;

    try {
      final payment = _payments.firstWhere((p) => p.id == paymentId);
      await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .doc(paymentId)
          .delete();

      debugPrint(
          'PaymentProvider: deleted payment $paymentId for sale ${payment.saleId} or service ${payment.serviceId}');

      /// -----------------------
      /// Update related Sale
      /// -----------------------
      if (payment.saleId != null &&
          payment.saleId!.isNotEmpty &&
          saleProvider != null) {
        final saleIndex =
            saleProvider.sales.indexWhere((s) => s.id == payment.saleId);
        if (saleIndex != -1) {
          final sale = saleProvider.sales[saleIndex];
          final updatedTotalPaid = sale.totalPaid - payment.amount;

          final updatedItems = sale.items.map((item) {
            double paymentRatio = 0.0;
            if (sale.totalAmount > 0) {
              paymentRatio =
                  (updatedTotalPaid / sale.totalAmount).clamp(0.0, 1.0);
            }
            final realized = item.profit * paymentRatio;
            final unrealized = item.profit - realized;

            return item.copyWith(
              realizedProfit: realized,
              unrealizedProfit: unrealized,
            );
          }).toList();

          final totalProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.profit);
          final realizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
          final unrealizedProfit =
              updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

          final updatedSale = sale.copyWith(
            totalPaid: updatedTotalPaid,
            items: updatedItems,
            totalProfit: totalProfit,
            realizedProfit: realizedProfit,
            unrealizedProfit: unrealizedProfit,
            updatedAt: DateTime.now(),
          );

          await _firestore
              .collection('facilities')
              .doc(facilityId)
              .collection('sales')
              .doc(updatedSale.id)
              .update({
            ...updatedSale.toMap(),
            ...updatedSale.searchFields(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      /// -----------------------
      /// Update related Service
      /// -----------------------
      if (payment.serviceId != null &&
          payment.serviceId!.isNotEmpty &&
          serviceProvider != null) {
        final serviceIndex =
            serviceProvider.services.indexWhere((s) => s.id == payment.serviceId);
        if (serviceIndex != -1) {
          final service = serviceProvider.services[serviceIndex];
          final updatedTotalPaid = service.totalPaid - payment.amount;

          final updatedService = service.copyWith(
            totalPaid: updatedTotalPaid,
            updatedAt: DateTime.now(),
          );

          await serviceProvider.updateService(updatedService);
        }
      }
    } catch (e) {
      debugPrint('PaymentProvider deletePayment error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
