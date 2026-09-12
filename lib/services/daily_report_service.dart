import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_report.dart';
import '../models/sale.dart';
import '../models/service.dart';

class DailyReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  CollectionReference<Map<String, dynamic>> _reportsCollection(String facilityId) =>
      _firestore.collection('facilities').doc(facilityId).collection('dailyReports');

  /// Fetches one page of reports, newest first. Pass [startAfter] (the
  /// last document from the previous page) to continue from where the
  /// last page left off. [dateCutoff], when given, restricts to
  /// reports on or after that date - used for the time filter, so
  /// "This month"/"This year" etc. narrow the query itself rather than
  /// only ever filtering whatever happens to already be loaded.
  Future<({List<DailyReport> reports, DocumentSnapshot<Map<String, dynamic>>? lastDoc})> getReportsPage({
    required String facilityId,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    DateTime? dateCutoff,
    DateTime? excludeOnOrAfter,
  }) async {
    Query<Map<String, dynamic>> query =
        _reportsCollection(facilityId).orderBy('reportDate', descending: true);
    if (dateCutoff != null) {
      query = query.where('reportDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateCutoff));
    }
    if (excludeOnOrAfter != null) {
      query = query.where('reportDate', isLessThan: Timestamp.fromDate(excludeOnOrAfter));
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.limit(limit).get();
    final reports = snap.docs.map((d) => DailyReport.fromMap(d.id, d.data())).toList();
    return (reports: reports, lastDoc: snap.docs.isEmpty ? null : snap.docs.last);
  }

  /// Total report count via Firestore's native count() aggregate -
  /// reads a single aggregate result rather than every document, so
  /// this stays cheap and fast no matter how many years of daily
  /// reports a facility has accumulated.
  Future<int> getReportsCount({required String facilityId, DateTime? dateCutoff, DateTime? excludeOnOrAfter}) async {
    Query<Map<String, dynamic>> query = _reportsCollection(facilityId);
    if (dateCutoff != null) {
      query = query.where('reportDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateCutoff));
    }
    if (excludeOnOrAfter != null) {
      query = query.where('reportDate', isLessThan: Timestamp.fromDate(excludeOnOrAfter));
    }
    final result = await query.count().get();
    return result.count ?? 0;
  }

  /// Deletes a draft report - re-checks the document's actual current
  /// status first rather than trusting the caller's in-memory copy,
  /// since the underlying data could have changed since it was loaded
  /// (e.g. someone else already submitted it). The Firestore rule
  /// itself also enforces draft-only and admin-only regardless, so
  /// this check is a clearer error message, not the only safeguard.
  Future<void> deleteDraftReport({required String facilityId, required String reportId}) async {
    final docRef = _reportsCollection(facilityId).doc(reportId);
    final doc = await _labeled('dailyReports (read before delete)', () => docRef.get());
    final status = doc.data()?['status'] as String?;
    if (status != 'draft') {
      throw Exception('Only a draft report can be deleted - this report has already been submitted.');
    }
    await _labeled('dailyReports (delete)', () => docRef.delete());
  }

  /// Runs a query and, if it fails, rethrows with a label identifying
  /// which read it was - generateDraftReport() reads from seven
  /// different collections before it writes anything, and without
  /// this a permission error on any one of them would look identical
  /// to every other, making it impossible to tell which collection's
  /// rule actually needs attention.
  Future<T> _labeled<T>(String label, Future<T> Function() query) async {
    try {
      return await query();
    } catch (e) {
      throw Exception('Failed reading "$label": $e');
    }
  }

  /// The existing report for today, whatever its status - a draft
  /// still being filled in, or an already-submitted one. Returns null
  /// if nothing has been generated yet today. Callers use this to
  /// decide the Generate button's state: nothing yet (offer to
  /// generate), draft (resume filling it in), submitted (view it).
  Future<DailyReport?> getTodaysReport(String facilityId) async {
    final doc = await _reportsCollection(facilityId).doc(_dateKey(DateTime.now())).get();
    if (!doc.exists) return null;
    return DailyReport.fromMap(doc.id, doc.data()!);
  }

  /// All previously generated reports for this facility, most recent
  /// first - for the View Reports list.
  Future<List<DailyReport>> getAllReports(String facilityId) async {
    final snap = await _reportsCollection(facilityId).orderBy('reportDate', descending: true).get();
    return snap.docs.map((d) => DailyReport.fromMap(d.id, d.data())).toList();
  }

  /// Generates today's draft report - every system-computed figure
  /// filled in, physical stock counts and cash counted left empty for
  /// the assistant to fill in before Submit. If a report already
  /// exists for today (draft or submitted), returns it unchanged
  /// rather than recomputing over it.
  Future<DailyReport> generateDraftReport({
    required String facilityId,
    required String generatedByName,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateKey = _dateKey(today);
    final docRef = _reportsCollection(facilityId).doc(dateKey);

    final existing = await _labeled('dailyReports (existence check)', () => docRef.get());
    if (existing.exists) {
      return DailyReport.fromMap(existing.id, existing.data()!);
    }

    final todayStart = Timestamp.fromDate(today);
    final nowStamp = Timestamp.fromDate(now);
    final facilities = _firestore.collection('facilities').doc(facilityId);

    // ---- Sales ----
    final salesSnap = await _labeled('sales', () => facilities
        .collection('sales')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .get());
    final sales = salesSnap.docs.map((d) => Sale.fromFirestore(d.data(), d.id)).toList();
    final salesCount = sales.length;
    final salesTotalValue = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final salesLineItems = sales
        .map((s) => SaleLineItem(
              saleId: s.id,
              time: s.timestamp,
              receiptNo: s.receiptNumber?.toString() ?? s.id.substring(0, s.id.length < 6 ? s.id.length : 6),
              customerName: s.clientName ?? 'Walk-in',
              itemCount: s.items.length,
              amount: s.totalAmount,
              paymentMethod: s.paymentMethod ?? 'Unknown',
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // ---- Services ----
    final servicesSnap = await _labeled('services', () => facilities
        .collection('services')
        .where('serviceDate', isGreaterThanOrEqualTo: todayStart)
        .where('serviceDate', isLessThanOrEqualTo: nowStamp)
        .get());
    final services = servicesSnap.docs.map((d) => Service.fromFirestore(d.data(), d.id)).toList();
    final servicesCount = services.length;
    final servicesTotalValue = services.fold(0.0, (sum, s) => sum + s.totalAmount);
    final serviceBreakdownMap = <String, ServiceTypeBreakdown>{};
    for (final s in services) {
      final key = s.name.isEmpty ? 'Other' : s.name;
      final existing = serviceBreakdownMap[key];
      serviceBreakdownMap[key] = ServiceTypeBreakdown(
        serviceName: key,
        count: (existing?.count ?? 0) + 1,
        revenue: (existing?.revenue ?? 0) + s.totalAmount,
      );
    }
    final serviceBreakdown = serviceBreakdownMap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    // ---- Payments ledger: payment-method breakdown for sales/services,
    // debt repayments (aggregate and per-client), and the cash-in side
    // of the drawer figure.
    final paymentsSnap = await _labeled('payments', () => facilities
        .collection('payments')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .get());

    final salesByPaymentMethod = <String, double>{};
    final servicesByPaymentMethod = <String, double>{};
    double repaymentsValue = 0;
    double cashIn = 0;
    final repaymentsByClient = <String, double>{};

    for (final doc in paymentsSnap.docs) {
      final data = doc.data();
      final source = (data['source'] as String?) ?? 'sale';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final method = (data['paymentMethod'] as String?) ?? 'Unknown';
      final clientId = data['clientId'] as String?;

      if (source == 'sale') {
        salesByPaymentMethod[method] = (salesByPaymentMethod[method] ?? 0) + amount;
      } else if (source == 'service') {
        servicesByPaymentMethod[method] = (servicesByPaymentMethod[method] ?? 0) + amount;
      } else if (source == 'debt_repayment') {
        repaymentsValue += amount;
        if (clientId != null) {
          repaymentsByClient[clientId] = (repaymentsByClient[clientId] ?? 0) + amount;
        }
      }

      if (method == 'Cash') cashIn += amount;
    }

    // ---- Transactions: other income and itemized expenses.
    final txSnap = await _labeled('transactions', () => facilities
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: todayStart)
        .where('date', isLessThanOrEqualTo: nowStamp)
        .get());

    double totalOtherIncome = 0;
    double totalExpenses = 0;
    double cashOutExpenses = 0;
    final expensesByCategory = <String, double>{};
    final expenseLineItems = <ExpenseLineItem>[];
    final otherIncomeLineItems = <ExpenseLineItem>[];

    for (final doc in txSnap.docs) {
      final data = doc.data();
      final type = (data['type'] as String?) ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final category = (data['category'] as String?) ?? 'Uncategorized';
      final method = (data['paymentMethod'] as String?) ?? '';
      final description = (data['description'] as String?) ?? '';
      final date = (data['date'] as Timestamp?)?.toDate() ?? now;

      if (type == 'expense') {
        totalExpenses += amount;
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
        expenseLineItems.add(ExpenseLineItem(time: date, description: description, category: category, amount: amount));
        if (method == 'Cash') cashOutExpenses += amount;
      } else if (type == 'other income') {
        totalOtherIncome += amount;
        otherIncomeLineItems.add(ExpenseLineItem(time: date, description: description, category: category, amount: amount));
      }
    }
    expenseLineItems.sort((a, b) => a.time.compareTo(b.time));
    otherIncomeLineItems.sort((a, b) => a.time.compareTo(b.time));

    // ---- Debts: new debt incurred today (see the same caveat as
    // before - the Debt model only stores a current remaining
    // balance, not a separate as-incurred figure, so this is a
    // daily-operational approximation, not full accounting).
    final debtsSnap = await _labeled('debts (today)', () => facilities
        .collection('debts')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .get());
    final newDebtByClient = <String, double>{};
    double newDebtValue = 0;
    for (final d in debtsSnap.docs) {
      final data = d.data();
      final amount = (data['amountOwed'] as num?)?.toDouble() ?? 0.0;
      final clientId = data['clientId'] as String?;
      newDebtValue += amount;
      if (clientId != null) {
        newDebtByClient[clientId] = (newDebtByClient[clientId] ?? 0) + amount;
      }
    }

    // ---- Outstanding change and per-client closing debt: today's
    // live totals against yesterday's recorded snapshot.
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdaySnapshotDoc = await _labeled(
        'dailySnapshots', () => facilities.collection('dailySnapshots').doc(_dateKey(yesterday)).get());
    final yesterdayOutstanding =
        (yesterdaySnapshotDoc.data()?['totalOutstanding'] as num?)?.toDouble() ?? 0.0;

    final debtsAllSnap = await _labeled('debts (all)', () => facilities.collection('debts').get());
    final closingDebtByClient = <String, double>{};
    final clientNameById = <String, String>{};
    double todayOutstanding = 0;
    for (final d in debtsAllSnap.docs) {
      final data = d.data();
      final amount = (data['amountOwed'] as num?)?.toDouble() ?? 0.0;
      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String? ?? 'Unknown';
      todayOutstanding += amount;
      if (clientId != null) {
        closingDebtByClient[clientId] = (closingDebtByClient[clientId] ?? 0) + amount;
        clientNameById[clientId] = clientName;
      }
    }
    final outstandingChange = todayOutstanding - yesterdayOutstanding;

    // Only clients whose debt actually moved today get a row - a
    // client who simply still owes money from before, untouched
    // today, isn't part of today's activity.
    final movedClientIds = <String>{...newDebtByClient.keys, ...repaymentsByClient.keys};
    final clientDebtEntries = movedClientIds.map((clientId) {
      final newDebt = newDebtByClient[clientId] ?? 0;
      final repayment = repaymentsByClient[clientId] ?? 0;
      final closingDebt = closingDebtByClient[clientId] ?? 0;
      final openingDebt = closingDebt - newDebt + repayment;
      return ClientDebtEntry(
        clientId: clientId,
        clientName: clientNameById[clientId] ?? 'Unknown',
        openingDebt: openingDebt < 0 ? 0 : openingDebt,
        newDebt: newDebt,
        repayment: repayment,
        closingDebt: closingDebt,
      );
    }).toList()
      ..sort((a, b) => a.clientName.compareTo(b.clientName));

    // ---- Products: per-product units sold today (from both sale
    // items and service-consumed items), and units added today (from
    // each product's batches subcollection, via a collection-group
    // query rather than one query per product).
    final unitsSoldByProduct = <String, int>{};
    final revenueByProduct = <String, double>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        if (item.productId.isEmpty) continue;
        unitsSoldByProduct[item.productId] = (unitsSoldByProduct[item.productId] ?? 0) + item.quantity;
        revenueByProduct[item.productId] =
            (revenueByProduct[item.productId] ?? 0) + (item.quantity * item.unitPrice - item.discount);
      }
    }
    for (final service in services) {
      for (final item in service.itemsUsed) {
        final productId = item['productId'] as String?;
        if (productId == null || productId.isEmpty) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        unitsSoldByProduct[productId] = (unitsSoldByProduct[productId] ?? 0) + qty;
      }
    }

    final productsSnap = await _labeled('products', () => facilities.collection('products').get());

    // Units added today, per product - queried directly against each
    // product's own batches subcollection (a nested, non-collection-
    // group read) rather than a collectionGroup('batches') query.
    // Firestore requires collection-group *queries* specifically to
    // have their own dedicated {path=**} rule to run at all, distinct
    // from a rule authorizing a direct read at a known nested path -
    // querying per-product here sidesteps that distinction entirely,
    // using only the plain nested rule that's been reliable from the
    // start, at the cost of one query per product instead of one
    // query overall.
    final batchResults = await Future.wait(productsSnap.docs.map((productDoc) => _labeled(
        'batches for ${productDoc.id}',
        () => facilities
            .collection('products')
            .doc(productDoc.id)
            .collection('batches')
            .where('receivedAt', isGreaterThanOrEqualTo: todayStart)
            .where('receivedAt', isLessThanOrEqualTo: nowStamp)
            .get())));

    final unitsAddedByProduct = <String, int>{};
    for (var i = 0; i < productsSnap.docs.length; i++) {
      final productId = productsSnap.docs[i].id;
      var added = 0;
      for (final batchDoc in batchResults[i].docs) {
        final data = batchDoc.data();
        added += ((data['stockQty'] as num?)?.toInt() ?? 0) + ((data['sellableQty'] as num?)?.toInt() ?? 0);
      }
      if (added > 0) unitsAddedByProduct[productId] = added;
    }

    final productMovement = <ProductMovementEntry>[];

    for (final doc in productsSnap.docs) {
      final data = doc.data();
      final sold = unitsSoldByProduct[doc.id] ?? 0;
      final added = unitsAddedByProduct[doc.id] ?? 0;
      final isWatchlisted = (data['isWatchlisted'] as bool?) ?? false;
      final expectedClosing =
          ((data['stockQty'] as num?)?.toInt() ?? 0) + ((data['sellableQty'] as num?)?.toInt() ?? 0);
      final opening = expectedClosing - added + sold;

      // Only carried forward when there's something to say: a
      // watch-listed product always appears (it always needs a
      // physical count), everything else only appears if it actually
      // moved today - a shop with hundreds of untouched SKUs
      // shouldn't get hundreds of zero-movement rows.
      if (isWatchlisted || sold > 0 || added > 0) {
        productMovement.add(ProductMovementEntry(
          productId: doc.id,
          name: (data['name'] as String?) ?? '',
          opening: opening < 0 ? 0 : opening,
          added: added,
          sold: sold,
          expectedClosing: expectedClosing,
          isWatchlisted: isWatchlisted,
        ));
      }
    }
    productMovement.sort((a, b) {
      if (a.isWatchlisted != b.isWatchlisted) return a.isWatchlisted ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    // ---- Activity log: a snapshot of today's entries from the app's
    // existing activity_logs collection (already written throughout
    // the day by sales, services, products, transactions, and
    // payments) - copied in at generation time, not a live reference.
    final activitySnap = await _labeled('activity_logs', () => facilities
        .collection('activity_logs')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .orderBy('timestamp')
        .get());
    final activityLogEntries = activitySnap.docs.map((doc) {
      final data = doc.data();
      return ActivityLogEntry(
        time: (data['timestamp'] as Timestamp?)?.toDate() ?? now,
        actionType: (data['actionType'] as String?) ?? 'Unknown',
        description: (data['description'] as String?) ?? '',
        userName: (data['userName'] as String?) ?? 'Unknown',
      );
    }).toList();

    final report = DailyReport(
      id: dateKey,
      facilityId: facilityId,
      reportDate: today,
      generatedAt: now,
      generatedByName: generatedByName,
      status: 'draft',
      salesCount: salesCount,
      salesTotalValue: salesTotalValue,
      salesByPaymentMethod: salesByPaymentMethod,
      salesLineItems: salesLineItems,
      servicesCount: servicesCount,
      servicesTotalValue: servicesTotalValue,
      servicesByPaymentMethod: servicesByPaymentMethod,
      serviceBreakdown: serviceBreakdown,
      totalOtherIncome: totalOtherIncome,
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      expenseLineItems: expenseLineItems,
      otherIncomeLineItems: otherIncomeLineItems,
      newDebtValue: newDebtValue,
      repaymentsValue: repaymentsValue,
      outstandingChange: outstandingChange,
      clientDebtEntries: clientDebtEntries,
      expectedCashInDrawer: cashIn - cashOutExpenses,
      productMovement: productMovement,
      activityLogEntries: activityLogEntries,
    );

    await _labeled('dailyReports (create)', () => docRef.set(report.toMap()));
    return report;
  }

  /// Finalizes a draft report: fills in the physical stock counts
  /// (for watch-listed products) and the physical cash count, marks
  /// the declaration confirmed, and flips status to 'submitted'. Once
  /// submitted, a report is never updated again - both this service
  /// and the Firestore rules enforce that.
  Future<DailyReport> submitReport({
    required String facilityId,
    required String reportId,
    required List<ProductMovementEntry> productMovement,
    required double physicalCashCounted,
    String? cashVarianceReason,
    required bool declarationConfirmed,
  }) async {
    final docRef = _reportsCollection(facilityId).doc(reportId);
    final doc = await _labeled('dailyReports (read for submit)', () => docRef.get());
    if (!doc.exists) {
      throw Exception('Report not found - it may not have been generated yet.');
    }
    final current = DailyReport.fromMap(doc.id, doc.data()!);
    if (current.status == 'submitted') {
      // Already finalized - return as-is rather than allowing a
      // second submission to alter a frozen report.
      return current;
    }

    final updated = current.copyWith(
      status: 'submitted',
      submittedAt: DateTime.now(),
      productMovement: productMovement,
      physicalCashCounted: physicalCashCounted,
      cashVarianceReason: cashVarianceReason,
      declarationConfirmed: declarationConfirmed,
    );

    await _labeled('dailyReports (submit)', () => docRef.set(updated.toMap()));
    return updated;
  }
}
