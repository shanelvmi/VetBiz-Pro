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
              paymentMethod: s.paymentMethod ?? 'On Credit',
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
    // Every amount actually received today, by method - sales,
    // services, and debt repayments alike. This is the "in" side of
    // reconciling any method, not just cash.
    final receivedByMethod = <String, double>{};
    final repaymentsByClient = <String, double>{};
    final repaymentsByMethod = <String, double>{};
    // Fallback name source for a client whose debt was fully repaid
    // today - their debts document gets deleted the moment the balance
    // hits zero, so by the time this report runs, there's no debts
    // record left to read a name from. The payment record itself
    // isn't deleted and already stores clientName directly, so it
    // covers exactly the gap closingDebtByClient/clientNameById can't.
    final paymentClientNameById = <String, String>{};

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
        repaymentsByMethod[method] = (repaymentsByMethod[method] ?? 0) + amount;
        if (clientId != null) {
          repaymentsByClient[clientId] = (repaymentsByClient[clientId] ?? 0) + amount;
          final paymentClientName = data['clientName'] as String?;
          if (paymentClientName != null && paymentClientName.isNotEmpty) {
            paymentClientNameById[clientId] = paymentClientName;
          }
        }
      }

      receivedByMethod[method] = (receivedByMethod[method] ?? 0) + amount;
    }

    // ---- Transactions: other income and itemized expenses.
    final txSnap = await _labeled('transactions', () => facilities
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: todayStart)
        .where('date', isLessThanOrEqualTo: nowStamp)
        .get());

    double totalOtherIncome = 0;
    double totalExpenses = 0;
    // Every expense paid today, by method - the "out" side of
    // reconciling any method. Other income received by method is
    // tracked too, since money coming in via, say, a bank transfer
    // belongs to that method's expected balance, not just cash's.
    final expensesByMethod = <String, double>{};
    final otherIncomeByMethod = <String, double>{};
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
        if (method.isNotEmpty) {
          expensesByMethod[method] = (expensesByMethod[method] ?? 0) + amount;
        }
      } else if (type == 'other income') {
        totalOtherIncome += amount;
        otherIncomeLineItems.add(ExpenseLineItem(time: date, description: description, category: category, amount: amount));
        if (method.isNotEmpty) {
          otherIncomeByMethod[method] = (otherIncomeByMethod[method] ?? 0) + amount;
        }
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
    // If yesterday's snapshot doesn't exist at all - the Cloud
    // Function hadn't run yet, or this is a facility's very first day
    // - there's no real prior figure to compare against. Falling back
    // to 0 here would make the entire current debt total look like
    // today's change, the same mistake as the product opening bug
    // above; treating today's total as unchanged from yesterday keeps
    // this honest instead: nothing is known to have changed.
    final yesterdayOutstandingRaw = (yesterdaySnapshotDoc.data()?['totalOutstanding'] as num?)?.toDouble();

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
    final yesterdayOutstanding = yesterdayOutstandingRaw ?? todayOutstanding;
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
        clientName: clientNameById[clientId] ?? paymentClientNameById[clientId] ?? 'Unknown',
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

    // Today's authoritative opening figure, per product - written by
    // the recordDailySnapshots Cloud Function at the start of the day,
    // not reverse-computed. The whole document being missing (the
    // Cloud Function hasn't run yet today, or this is a facility's
    // very first day) is handled separately below, falling back to
    // each product's current live stock rather than zero - see the
    // opening computation in the loop for why. A specific product
    // missing from an otherwise-real snapshot (created after the
    // snapshot ran today) correctly still defaults to 0 here.
    final stockSnapshotDoc = await _labeled(
        'dailyStockSnapshots', () => facilities.collection('dailyStockSnapshots').doc(_dateKey(today)).get());
    final openingByProduct = <String, int>{};
    final snapshotSellableStock = stockSnapshotDoc.data()?['sellableStock'] as Map<String, dynamic>?;
    if (snapshotSellableStock != null) {
      snapshotSellableStock.forEach((productId, value) {
        openingByProduct[productId] = (value as num?)?.toInt() ?? 0;
      });
    }

    // Today's genuine additions, per product - summed from the
    // stockAdditions log addBatch() writes on every call (new batch or
    // merge alike), rather than inferred from a batch document's own
    // current totals or its receivedAt timestamp. A merge into an
    // existing batch never changes that batch's receivedAt, and its
    // current sellableQty total isn't the same as what was added
    // today if it already had stock from before - this log is what
    // makes "Added" reliable in both cases.
    final stockAdditionsSnap = await _labeled('stockAdditions', () => facilities
        .collection('stockAdditions')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .get());
    final addedByProduct = <String, int>{};
    for (final doc in stockAdditionsSnap.docs) {
      final data = doc.data();
      final productId = data['productId'] as String?;
      if (productId == null) continue;
      final delta = (data['sellableDelta'] as num?)?.toInt() ?? 0;
      addedByProduct[productId] = (addedByProduct[productId] ?? 0) + delta;
    }

    // Today's logged stock quantity edits - explains an "Adjusted"
    // figure with who changed it and what it went from/to, whenever
    // the change came through a path that actually logs it. A product
    // adjusted more than once today keeps only the latest edit, since
    // the "Adjusted" number itself is a single net figure, not a list.
    final stockAdjustmentsSnap = await _labeled('stock_adjustments', () => facilities
        .collection('stock_adjustments')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThanOrEqualTo: nowStamp)
        .get());
    final adjustmentDetailByProduct = <String, String>{};
    for (final doc in stockAdjustmentsSnap.docs) {
      final data = doc.data();
      final productId = data['productId'] as String?;
      if (productId == null) continue;
      final userName = (data['userName'] as String?) ?? 'Unknown';
      final oldSellable = (data['oldSellableQty'] as num?)?.toInt() ?? 0;
      final newSellable = (data['newSellableQty'] as num?)?.toInt() ?? 0;
      final source = (data['source'] as String?) ?? 'Stock edit';
      adjustmentDetailByProduct[productId] = '$source by $userName ($oldSellable to $newSellable)';
    }

    final productMovement = <ProductMovementEntry>[];

    for (final doc in productsSnap.docs) {
      final data = doc.data();
      final sold = unitsSoldByProduct[doc.id] ?? 0;
      final added = addedByProduct[doc.id] ?? 0;
      final isWatchlisted = (data['isWatchlisted'] as bool?) ?? false;
      // Only sellableQty - warehouse stock (stockQty) isn't something
      // a customer could actually buy today, so it has no place in a
      // daily closing report focused on what was available to sell.
      final actualSellable = (data['sellableQty'] as num?)?.toInt() ?? 0;
      // If today's snapshot document doesn't exist at all, there's no
      // real opening figure to read - falling back to today's live
      // stock as-is would be wrong the moment anything actually
      // happened today, since live stock already reflects today's
      // sales and additions. Reversing those out of the live figure
      // reconstructs what opening genuinely must have been: whatever
      // is sellable right now, plus what was sold today, minus what
      // was added today. Zero is still correct, and used via
      // openingByProduct's own lookup below, for a specific product
      // that's missing from an otherwise-real snapshot - one created
      // after the snapshot ran today.
      final opening = stockSnapshotDoc.exists ? (openingByProduct[doc.id] ?? 0) : (actualSellable + sold - added);
      // Whatever's left unexplained once tracked additions and sales
      // are accounted for - a warehouse-to-shelf release, a miscount
      // correction, or any other sellable-quantity change that wasn't
      // a fresh restock or an actual sale.
      final adjustment = actualSellable - (opening + added - sold);

      // Only carried forward when there's something to say: a
      // watch-listed product always appears (it always needs a
      // physical count), everything else only appears if it actually
      // moved today - a shop with hundreds of untouched SKUs
      // shouldn't get hundreds of zero-movement rows.
      if (isWatchlisted || sold > 0 || added > 0 || adjustment != 0) {
        productMovement.add(ProductMovementEntry(
          productId: doc.id,
          name: (data['name'] as String?) ?? '',
          unit: (data['unit'] as String?) ?? '',
          opening: opening < 0 ? 0 : opening,
          added: added,
          adjustment: adjustment,
          sold: sold,
          expectedClosing: actualSellable,
          isWatchlisted: isWatchlisted,
          adjustmentDetail: adjustment != 0 ? adjustmentDetailByProduct[doc.id] : null,
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

    // Every method that showed up anywhere today - received, other
    // income, or expenses - gets its own reconciliation row. A method
    // that only appeared as an expense (paid out of pocket, say) still
    // needs a row, since its expected balance would be negative and
    // that's worth surfacing too.
    final allMethodsToday = <String>{
      ...receivedByMethod.keys,
      ...otherIncomeByMethod.keys,
      ...expensesByMethod.keys,
    };
    final paymentReconciliation = allMethodsToday.map((method) {
      final expected = (receivedByMethod[method] ?? 0) + (otherIncomeByMethod[method] ?? 0) - (expensesByMethod[method] ?? 0);
      final hadIncomeToday = (receivedByMethod[method] ?? 0) + (otherIncomeByMethod[method] ?? 0) > 0;
      return PaymentMethodReconciliation(
        method: method,
        expected: expected,
        requiresCount: method == 'Cash' || hadIncomeToday,
      );
    }).toList()
      ..sort((a, b) => a.method.compareTo(b.method));

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
      otherIncomeByPaymentMethod: otherIncomeByMethod,
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      expenseLineItems: expenseLineItems,
      otherIncomeLineItems: otherIncomeLineItems,
      newDebtValue: newDebtValue,
      repaymentsValue: repaymentsValue,
      repaymentsByPaymentMethod: repaymentsByMethod,
      outstandingChange: outstandingChange,
      clientDebtEntries: clientDebtEntries,
      paymentReconciliation: paymentReconciliation,
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
    required List<PaymentMethodReconciliation> paymentReconciliation,
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
      paymentReconciliation: paymentReconciliation,
      declarationConfirmed: declarationConfirmed,
    );

    await _labeled('dailyReports (submit)', () => docRef.set(updated.toMap()));
    return updated;
  }
}
