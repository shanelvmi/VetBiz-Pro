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
        paymentMethod: map['paymentMethod'] as String? ?? 'Unknown',
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
  final int opening;
  final int added;
  final int sold;
  final int expectedClosing;
  final bool isWatchlisted;
  final int? physicalCount;
  final String? varianceReason;

  const ProductMovementEntry({
    required this.productId,
    required this.name,
    required this.opening,
    required this.added,
    required this.sold,
    required this.expectedClosing,
    required this.isWatchlisted,
    this.physicalCount,
    this.varianceReason,
  });

  /// null until a physical count has been entered - only meaningful
  /// for watch-listed products.
  int? get variance => physicalCount == null ? null : physicalCount! - expectedClosing;

  ProductMovementEntry copyWith({int? physicalCount, String? varianceReason}) => ProductMovementEntry(
        productId: productId,
        name: name,
        opening: opening,
        added: added,
        sold: sold,
        expectedClosing: expectedClosing,
        isWatchlisted: isWatchlisted,
        physicalCount: physicalCount ?? this.physicalCount,
        varianceReason: varianceReason ?? this.varianceReason,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'opening': opening,
        'added': added,
        'sold': sold,
        'expectedClosing': expectedClosing,
        'isWatchlisted': isWatchlisted,
        'physicalCount': physicalCount,
        'varianceReason': varianceReason,
      };

  factory ProductMovementEntry.fromMap(Map<String, dynamic> map) => ProductMovementEntry(
        productId: map['productId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        opening: (map['opening'] as num?)?.toInt() ?? 0,
        added: (map['added'] as num?)?.toInt() ?? 0,
        sold: (map['sold'] as num?)?.toInt() ?? 0,
        expectedClosing: (map['expectedClosing'] as num?)?.toInt() ?? 0,
        isWatchlisted: (map['isWatchlisted'] as bool?) ?? false,
        physicalCount: (map['physicalCount'] as num?)?.toInt(),
        varianceReason: map['varianceReason'] as String?,
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
  final double totalExpenses;
  final Map<String, double> expensesByCategory;
  final List<ExpenseLineItem> expenseLineItems;
  final List<ExpenseLineItem> otherIncomeLineItems;

  // Debt
  final double newDebtValue;
  final double repaymentsValue;
  final double outstandingChange;
  final List<ClientDebtEntry> clientDebtEntries;

  // Cash reconciliation
  final double expectedCashInDrawer;
  final double? physicalCashCounted; // null until Submit
  final String? cashVarianceReason;

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
    this.totalExpenses = 0,
    this.expensesByCategory = const {},
    this.expenseLineItems = const [],
    this.otherIncomeLineItems = const [],
    this.newDebtValue = 0,
    this.repaymentsValue = 0,
    this.outstandingChange = 0,
    this.clientDebtEntries = const [],
    this.expectedCashInDrawer = 0,
    this.physicalCashCounted,
    this.cashVarianceReason,
    this.productMovement = const [],
    this.activityLogEntries = const [],
    this.declarationConfirmed = false,
  });

  double? get cashVariance => physicalCashCounted == null ? null : physicalCashCounted! - expectedCashInDrawer;

  bool get hasStockVariance => productMovement.any((p) => p.variance != null && p.variance != 0);

  DailyReport copyWith({
    String? status,
    DateTime? submittedAt,
    double? physicalCashCounted,
    String? cashVarianceReason,
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
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      expenseLineItems: expenseLineItems,
      newDebtValue: newDebtValue,
      repaymentsValue: repaymentsValue,
      outstandingChange: outstandingChange,
      clientDebtEntries: clientDebtEntries,
      expectedCashInDrawer: expectedCashInDrawer,
      physicalCashCounted: physicalCashCounted ?? this.physicalCashCounted,
      cashVarianceReason: cashVarianceReason ?? this.cashVarianceReason,
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
      'totalExpenses': totalExpenses,
      'expensesByCategory': encodeDoubleMap(expensesByCategory),
      'expenseLineItems': expenseLineItems.map((e) => e.toMap()).toList(),
      'otherIncomeLineItems': otherIncomeLineItems.map((e) => e.toMap()).toList(),
      'newDebtValue': newDebtValue,
      'repaymentsValue': repaymentsValue,
      'outstandingChange': outstandingChange,
      'clientDebtEntries': clientDebtEntries.map((e) => e.toMap()).toList(),
      'expectedCashInDrawer': expectedCashInDrawer,
      'physicalCashCounted': physicalCashCounted,
      'cashVarianceReason': cashVarianceReason,
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
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0,
      expensesByCategory: parseDoubleMap(map['expensesByCategory']),
      expenseLineItems: parseList(map['expenseLineItems'], ExpenseLineItem.fromMap),
      otherIncomeLineItems: parseList(map['otherIncomeLineItems'], ExpenseLineItem.fromMap),
      newDebtValue: (map['newDebtValue'] as num?)?.toDouble() ?? 0,
      repaymentsValue: (map['repaymentsValue'] as num?)?.toDouble() ?? 0,
      outstandingChange: (map['outstandingChange'] as num?)?.toDouble() ?? 0,
      clientDebtEntries: parseList(map['clientDebtEntries'], ClientDebtEntry.fromMap),
      expectedCashInDrawer: (map['expectedCashInDrawer'] as num?)?.toDouble() ?? 0,
      physicalCashCounted: (map['physicalCashCounted'] as num?)?.toDouble(),
      cashVarianceReason: map['cashVarianceReason'] as String?,
      productMovement: parseList(map['productMovement'], ProductMovementEntry.fromMap),
      activityLogEntries: parseList(map['activityLogEntries'], ActivityLogEntry.fromMap),
      declarationConfirmed: (map['declarationConfirmed'] as bool?) ?? false,
    );
  }
}
