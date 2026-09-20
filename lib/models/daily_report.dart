import 'package:cloud_firestore/cloud_firestore.dart';

/// One line in the itemized Sales tab.
class SaleLineItem {
  final String saleId;
  final DateTime time;
  final String receiptNo;
  final String customerName;
  final int itemCount;
  final double amount;
  final String paymentMethod;

  const SaleLineItem({
    required this.saleId,
    required this.time,
    required this.receiptNo,
    required this.customerName,
    required this.itemCount,
    required this.amount,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() => {
        'saleId': saleId,
        'time': Timestamp.fromDate(time),
        'receiptNo': receiptNo,
        'customerName': customerName,
        'itemCount': itemCount,
        'amount': amount,
        'paymentMethod': paymentMethod,
      };

  factory SaleLineItem.fromMap(Map<String, dynamic> map) => SaleLineItem(
        saleId: map['saleId'] as String? ?? '',
        time: (map['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        receiptNo: map['receiptNo'] as String? ?? '',
        customerName: map['customerName'] as String? ?? 'Walk-in',
        itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: map['paymentMethod'] as String? ?? 'On Credit',
      );
}

/// One row in the Services tab - grouped by service name, not
/// itemized per visit, matching the mockup.
class ServiceTypeBreakdown {
  final String serviceName;
  final int count;
  final double revenue;

  const ServiceTypeBreakdown({required this.serviceName, required this.count, required this.revenue});

  Map<String, dynamic> toMap() => {'serviceName': serviceName, 'count': count, 'revenue': revenue};

  factory ServiceTypeBreakdown.fromMap(Map<String, dynamic> map) => ServiceTypeBreakdown(
        serviceName: map['serviceName'] as String? ?? 'Other',
        count: (map['count'] as num?)?.toInt() ?? 0,
        revenue: (map['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// One row in Product Movement. physicalCount and varianceReason stay
/// null for non-watch-listed products (system-tracked only, no
/// counting required) and for watch-listed products until the
/// assistant fills them in at Submit time.
class ProductMovementEntry {
  final String productId;
  final String name;
  final String unit;
  final int opening;
  final int added;
  final int adjustment;
  final int sold;
  final int expectedClosing;
  final bool isWatchlisted;
  final int? physicalCount;
  final String? varianceReason;
  // Set when this adjustment can be traced to a logged stock quantity
  // edit today (who, before/after) - null when no matching log entry
  // exists, since not every source of an adjustment is logged yet.
  final String? adjustmentDetail;

  const ProductMovementEntry({
    required this.productId,
    required this.name,
    this.unit = '',
    required this.opening,
    required this.added,
    required this.adjustment,
    required this.sold,
    required this.expectedClosing,
    required this.isWatchlisted,
    this.physicalCount,
    this.varianceReason,
    this.adjustmentDetail,
  });

  /// null until a physical count has been entered - only meaningful
  /// for watch-listed products.
  int? get variance => physicalCount == null ? null : physicalCount! - expectedClosing;

  ProductMovementEntry copyWith({int? physicalCount, String? varianceReason}) => ProductMovementEntry(
        productId: productId,
        name: name,
        unit: unit,
        opening: opening,
        added: added,
        adjustment: adjustment,
        sold: sold,
        expectedClosing: expectedClosing,
        isWatchlisted: isWatchlisted,
        physicalCount: physicalCount ?? this.physicalCount,
        varianceReason: varianceReason ?? this.varianceReason,
        adjustmentDetail: adjustmentDetail,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'opening': opening,
        'added': added,
        'adjustment': adjustment,
        'sold': sold,
        'expectedClosing': expectedClosing,
        'isWatchlisted': isWatchlisted,
        'physicalCount': physicalCount,
        'varianceReason': varianceReason,
        'adjustmentDetail': adjustmentDetail,
      };

  factory ProductMovementEntry.fromMap(Map<String, dynamic> map) => ProductMovementEntry(
        productId: map['productId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        opening: (map['opening'] as num?)?.toInt() ?? 0,
        added: (map['added'] as num?)?.toInt() ?? 0,
        adjustment: (map['adjustment'] as num?)?.toInt() ?? 0,
        sold: (map['sold'] as num?)?.toInt() ?? 0,
        expectedClosing: (map['expectedClosing'] as num?)?.toInt() ?? 0,
        isWatchlisted: (map['isWatchlisted'] as bool?) ?? false,
        physicalCount: (map['physicalCount'] as num?)?.toInt(),
        varianceReason: map['varianceReason'] as String?,
        adjustmentDetail: map['adjustmentDetail'] as String?,
      );
}

/// One row in the per-client Debt tab.
class ClientDebtEntry {
  final String clientId;
  final String clientName;
  final double openingDebt;
  final double newDebt;
  final double repayment;
  final double closingDebt;

  const ClientDebtEntry({
    required this.clientId,
    required this.clientName,
    required this.openingDebt,
    required this.newDebt,
    required this.repayment,
    required this.closingDebt,
  });

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientName': clientName,
        'openingDebt': openingDebt,
        'newDebt': newDebt,
        'repayment': repayment,
        'closingDebt': closingDebt,
      };

  factory ClientDebtEntry.fromMap(Map<String, dynamic> map) => ClientDebtEntry(
        clientId: map['clientId'] as String? ?? '',
        clientName: map['clientName'] as String? ?? 'Unknown',
        openingDebt: (map['openingDebt'] as num?)?.toDouble() ?? 0,
        newDebt: (map['newDebt'] as num?)?.toDouble() ?? 0,
        repayment: (map['repayment'] as num?)?.toDouble() ?? 0,
        closingDebt: (map['closingDebt'] as num?)?.toDouble() ?? 0,
      );
}

/// One row in the itemized Expenses tab.
class ExpenseLineItem {
  final DateTime time;
  final String description;
  final String category;
  final double amount;

  const ExpenseLineItem({required this.time, required this.description, required this.category, required this.amount});

  Map<String, dynamic> toMap() => {
        'time': Timestamp.fromDate(time),
        'description': description,
        'category': category,
        'amount': amount,
      };

  factory ExpenseLineItem.fromMap(Map<String, dynamic> map) => ExpenseLineItem(
        time: (map['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        description: map['description'] as String? ?? '',
        category: map['category'] as String? ?? 'Uncategorized',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// One entry in the Activity Log tab - a snapshot copy of a document
/// from the app's existing activity_logs collection (already written
/// to by sales, services, products, transactions and payments
/// throughout the day via ActivityLogger), taken at report-generation
/// time. Not a live reference - later activity never changes an
/// already-generated report.
class ActivityLogEntry {
  final DateTime time;
  final String actionType;
  final String description;
  final String userName;

  const ActivityLogEntry({
    required this.time,
    required this.actionType,
    required this.description,
    required this.userName,
  });

  Map<String, dynamic> toMap() => {
        'time': Timestamp.fromDate(time),
        'actionType': actionType,
        'description': description,
        'userName': userName,
      };

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) => ActivityLogEntry(
        time: (map['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        actionType: map['actionType'] as String? ?? 'Unknown',
        description: map['description'] as String? ?? '',
        userName: map['userName'] as String? ?? 'Unknown',
      );
}

/// One row in the payment-method reconciliation - expected balance
/// (from sales, services, debt repayments, and other income received
/// via this method, minus expenses paid via it) versus what was
/// physically counted, for every method actually used that day, not
/// just cash.
class PaymentMethodReconciliation {
  final String method;
  final double expected;
  final double? physicalCount; // null until Submit
  final String? varianceReason;
  // Cash always requires a physical count, since a till gets counted
  // regardless of whether it took in money today - that's the normal,
  // daily discipline for physical cash. Any other method only requires
  // one when it actually received income today; a method that only had
  // an expense against it (nothing came in) isn't a discrepancy
  // waiting to happen, it's just an honest outflow with nothing to
  // physically verify against.
  final bool requiresCount;

  const PaymentMethodReconciliation({
    required this.method,
    required this.expected,
    this.physicalCount,
    this.varianceReason,
    this.requiresCount = true,
  });

  double? get variance => physicalCount == null ? null : physicalCount! - expected;

  PaymentMethodReconciliation copyWith({double? physicalCount, String? varianceReason}) => PaymentMethodReconciliation(
        method: method,
        expected: expected,
        physicalCount: physicalCount ?? this.physicalCount,
        varianceReason: varianceReason ?? this.varianceReason,
        requiresCount: requiresCount,
      );

  Map<String, dynamic> toMap() => {
        'method': method,
        'expected': expected,
        'physicalCount': physicalCount,
        'varianceReason': varianceReason,
        'requiresCount': requiresCount,
      };

  factory PaymentMethodReconciliation.fromMap(Map<String, dynamic> map) => PaymentMethodReconciliation(
        method: map['method'] as String? ?? 'Unknown',
        expected: (map['expected'] as num?)?.toDouble() ?? 0,
        physicalCount: (map['physicalCount'] as num?)?.toDouble(),
        varianceReason: map['varianceReason'] as String?,
        requiresCount: (map['requiresCount'] as bool?) ?? true,
      );
}

/// One facility's daily closing report. 'draft' status means the
/// system-computed figures have been generated but physical stock and
/// cash counts haven't been entered/submitted yet; 'submitted' means
/// the assistant has filled those in, confirmed the declaration, and
/// the report is now permanently frozen - see DailyReportService and
/// the updated Firestore rule for how that freeze is enforced.
class DailyReport {
  final String id;
  final String facilityId;
  final DateTime reportDate;
  final DateTime generatedAt;
  final String generatedByName;
  final String status; // 'draft' | 'submitted'
  final DateTime? submittedAt;

  // Sales
  final int salesCount;
  final double salesTotalValue;
  final Map<String, double> salesByPaymentMethod;
  final List<SaleLineItem> salesLineItems;

  // Services
  final int servicesCount;
  final double servicesTotalValue;
  final Map<String, double> servicesByPaymentMethod;
  final List<ServiceTypeBreakdown> serviceBreakdown;

  // Transactions
  final double totalOtherIncome;
  final Map<String, double> otherIncomeByPaymentMethod;
  final double totalExpenses;
  final Map<String, double> expensesByCategory;
  final List<ExpenseLineItem> expenseLineItems;
  final List<ExpenseLineItem> otherIncomeLineItems;

  // Debt
  final double newDebtValue;
  final double repaymentsValue;
  final Map<String, double> repaymentsByPaymentMethod;
  final double outstandingChange;
  final List<ClientDebtEntry> clientDebtEntries;

  // Cash reconciliation
  final List<PaymentMethodReconciliation> paymentReconciliation;

  // Products
  final List<ProductMovementEntry> productMovement;

  // Activity log - a snapshot of the day's activity_logs entries
  final List<ActivityLogEntry> activityLogEntries;

  // Closing declaration
  final bool declarationConfirmed;

  const DailyReport({
    required this.id,
    required this.facilityId,
    required this.reportDate,
    required this.generatedAt,
    required this.generatedByName,
    this.status = 'draft',
    this.submittedAt,
    this.salesCount = 0,
    this.salesTotalValue = 0,
    this.salesByPaymentMethod = const {},
    this.salesLineItems = const [],
    this.servicesCount = 0,
    this.servicesTotalValue = 0,
    this.servicesByPaymentMethod = const {},
    this.serviceBreakdown = const [],
    this.totalOtherIncome = 0,
    this.otherIncomeByPaymentMethod = const {},
    this.totalExpenses = 0,
    this.expensesByCategory = const {},
    this.expenseLineItems = const [],
    this.otherIncomeLineItems = const [],
    this.newDebtValue = 0,
    this.repaymentsValue = 0,
    this.repaymentsByPaymentMethod = const {},
    this.outstandingChange = 0,
    this.clientDebtEntries = const [],
    this.paymentReconciliation = const [],
    this.productMovement = const [],
    this.activityLogEntries = const [],
    this.declarationConfirmed = false,
  });

  bool get hasPaymentVariance => paymentReconciliation.any((p) => p.variance != null && p.variance != 0);

  bool get hasStockVariance => productMovement.any((p) => p.variance != null && p.variance != 0);

  DailyReport copyWith({
    String? status,
    DateTime? submittedAt,
    List<PaymentMethodReconciliation>? paymentReconciliation,
    List<ProductMovementEntry>? productMovement,
    bool? declarationConfirmed,
  }) {
    return DailyReport(
      id: id,
      facilityId: facilityId,
      reportDate: reportDate,
      generatedAt: generatedAt,
      generatedByName: generatedByName,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      salesCount: salesCount,
      salesTotalValue: salesTotalValue,
      salesByPaymentMethod: salesByPaymentMethod,
      salesLineItems: salesLineItems,
      servicesCount: servicesCount,
      servicesTotalValue: servicesTotalValue,
      servicesByPaymentMethod: servicesByPaymentMethod,
      serviceBreakdown: serviceBreakdown,
      totalOtherIncome: totalOtherIncome,
      otherIncomeByPaymentMethod: otherIncomeByPaymentMethod,
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      expenseLineItems: expenseLineItems,
      newDebtValue: newDebtValue,
      repaymentsValue: repaymentsValue,
      repaymentsByPaymentMethod: repaymentsByPaymentMethod,
      outstandingChange: outstandingChange,
      clientDebtEntries: clientDebtEntries,
      paymentReconciliation: paymentReconciliation ?? this.paymentReconciliation,
      productMovement: productMovement ?? this.productMovement,
      declarationConfirmed: declarationConfirmed ?? this.declarationConfirmed,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, double> encodeDoubleMap(Map<String, double> m) => m;
    return {
      'facilityId': facilityId,
      'reportDate': Timestamp.fromDate(reportDate),
      'generatedAt': Timestamp.fromDate(generatedAt),
      'generatedByName': generatedByName,
      'status': status,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'salesCount': salesCount,
      'salesTotalValue': salesTotalValue,
      'salesByPaymentMethod': encodeDoubleMap(salesByPaymentMethod),
      'salesLineItems': salesLineItems.map((e) => e.toMap()).toList(),
      'servicesCount': servicesCount,
      'servicesTotalValue': servicesTotalValue,
      'servicesByPaymentMethod': encodeDoubleMap(servicesByPaymentMethod),
      'serviceBreakdown': serviceBreakdown.map((e) => e.toMap()).toList(),
      'totalOtherIncome': totalOtherIncome,
      'otherIncomeByPaymentMethod': encodeDoubleMap(otherIncomeByPaymentMethod),
      'totalExpenses': totalExpenses,
      'expensesByCategory': encodeDoubleMap(expensesByCategory),
      'expenseLineItems': expenseLineItems.map((e) => e.toMap()).toList(),
      'otherIncomeLineItems': otherIncomeLineItems.map((e) => e.toMap()).toList(),
      'newDebtValue': newDebtValue,
      'repaymentsValue': repaymentsValue,
      'repaymentsByPaymentMethod': encodeDoubleMap(repaymentsByPaymentMethod),
      'outstandingChange': outstandingChange,
      'clientDebtEntries': clientDebtEntries.map((e) => e.toMap()).toList(),
      'paymentReconciliation': paymentReconciliation.map((p) => p.toMap()).toList(),
      'productMovement': productMovement.map((e) => e.toMap()).toList(),
      'activityLogEntries': activityLogEntries.map((e) => e.toMap()).toList(),
      'declarationConfirmed': declarationConfirmed,
    };
  }

  factory DailyReport.fromMap(String id, Map<String, dynamic> map) {
    Map<String, double> parseDoubleMap(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((key, value) => MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0));
    }

    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromMap) {
      if (raw is! List) return [];
      return raw.map((e) => fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }

    return DailyReport(
      id: id,
      facilityId: map['facilityId'] as String? ?? '',
      reportDate: (map['reportDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      generatedByName: map['generatedByName'] as String? ?? 'Unknown',
      status: map['status'] as String? ?? 'draft',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      salesCount: (map['salesCount'] as num?)?.toInt() ?? 0,
      salesTotalValue: (map['salesTotalValue'] as num?)?.toDouble() ?? 0,
      salesByPaymentMethod: parseDoubleMap(map['salesByPaymentMethod']),
      salesLineItems: parseList(map['salesLineItems'], SaleLineItem.fromMap),
      servicesCount: (map['servicesCount'] as num?)?.toInt() ?? 0,
      servicesTotalValue: (map['servicesTotalValue'] as num?)?.toDouble() ?? 0,
      servicesByPaymentMethod: parseDoubleMap(map['servicesByPaymentMethod']),
      serviceBreakdown: parseList(map['serviceBreakdown'], ServiceTypeBreakdown.fromMap),
      totalOtherIncome: (map['totalOtherIncome'] as num?)?.toDouble() ?? 0,
      otherIncomeByPaymentMethod: parseDoubleMap(map['otherIncomeByPaymentMethod']),
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0,
      expensesByCategory: parseDoubleMap(map['expensesByCategory']),
      expenseLineItems: parseList(map['expenseLineItems'], ExpenseLineItem.fromMap),
      otherIncomeLineItems: parseList(map['otherIncomeLineItems'], ExpenseLineItem.fromMap),
      newDebtValue: (map['newDebtValue'] as num?)?.toDouble() ?? 0,
      repaymentsValue: (map['repaymentsValue'] as num?)?.toDouble() ?? 0,
      repaymentsByPaymentMethod: parseDoubleMap(map['repaymentsByPaymentMethod']),
      outstandingChange: (map['outstandingChange'] as num?)?.toDouble() ?? 0,
      clientDebtEntries: parseList(map['clientDebtEntries'], ClientDebtEntry.fromMap),
      paymentReconciliation: parseList(map['paymentReconciliation'], PaymentMethodReconciliation.fromMap),
      productMovement: parseList(map['productMovement'], ProductMovementEntry.fromMap),
      activityLogEntries: parseList(map['activityLogEntries'], ActivityLogEntry.fromMap),
      declarationConfirmed: (map['declarationConfirmed'] as bool?) ?? false,
    );
  }
}
