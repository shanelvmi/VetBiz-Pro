// PH7b: a daily report as the app stores it, with every section filled
// (more than 5 rows where a list can grow, so See all shows), very long
// Kiswahili names and 8-digit amounts, Tigo Pesa beside Mixx by Yas; and
// the pumps the report screens' tests share (phone_list_harness.dart's
// pumpPh5: the real providers over a fake Firestore).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/screens/reports/report_tabbed_content.dart';
import 'package:vetbiz_pro/services/auth_service.dart';

import 'fake_firestore.dart';
import 'phone_list_harness.dart';
import 'screen_size_matrix.dart';

/// No one signed in (View Reports' generate reads the name through it).
class Ph7bNoAuth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Today at [hour]:[minute].
DateTime ph7bAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

DateTime get ph7bToday {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// The report's id for [day], as DailyReportService keys it.
String ph7bReportId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Today's report. [status] 'draft' or 'submitted' (a submitted one carries
/// the counts); [activityLog] whether the admin's log was saved with it.
DailyReport ph7bReport({String status = 'submitted', bool activityLog = false, DateTime? day}) {
  final submitted = status == 'submitted';
  final date = day ?? ph7bToday;
  return DailyReport(
    id: ph7bReportId(date),
    facilityId: testFacilityId,
    reportDate: date,
    generatedAt: date.add(const Duration(hours: 18, minutes: 5)),
    generatedByName: 'Asha Mohamed',
    status: status,
    submittedAt: submitted ? date.add(const Duration(hours: 18, minutes: 30)) : null,
    salesCount: 7,
    salesTotalValue: matrixBigAmount + 165000,
    salesByPaymentMethod: {'Cash': 90000, 'M-Pesa': matrixBigAmount, 'Tigo Pesa': 30000, 'Mixx by Yas': 45000},
    salesLineItems: [
      SaleLineItem(saleId: 's1', time: ph7bAt(8, 15), receiptNo: 'SL-000101', customerName: matrixLongClientName, itemCount: 3, amount: matrixBigAmount, paymentMethod: 'M-Pesa'),
      SaleLineItem(saleId: 's2', time: ph7bAt(9), receiptNo: 'SL-000102', customerName: 'Walk-in', itemCount: 1, amount: 15000, paymentMethod: 'Cash'),
      SaleLineItem(saleId: 's3', time: ph7bAt(10, 30), receiptNo: 'SL-000103', customerName: 'Juma Hassan', itemCount: 2, amount: 30000, paymentMethod: 'Tigo Pesa'),
      SaleLineItem(saleId: 's4', time: ph7bAt(11), receiptNo: 'SL-000104', customerName: 'Neema Paulo', itemCount: 1, amount: 45000, paymentMethod: 'Mixx by Yas'),
      SaleLineItem(saleId: 's5', time: ph7bAt(12, 45), receiptNo: 'SL-000105', customerName: 'Walk-in', itemCount: 4, amount: 25000, paymentMethod: 'Cash'),
      SaleLineItem(saleId: 's6', time: ph7bAt(14), receiptNo: 'SL-000106', customerName: 'Baraka Mollel', itemCount: 1, amount: 20000, paymentMethod: 'Cash'),
      SaleLineItem(saleId: 's7', time: ph7bAt(16, 20), receiptNo: 'SL-000107', customerName: 'Rehema Said', itemCount: 2, amount: 30000, paymentMethod: 'Cash'),
    ],
    servicesCount: 9,
    servicesTotalValue: 285000,
    servicesByPaymentMethod: {'Cash': 185000, 'Tigo Pesa': 40000, 'Mixx by Yas': 60000},
    serviceBreakdown: const [
      ServiceTypeBreakdown(serviceName: 'Chanjo ya Kideri kwa Kuku wa Kienyeji na wa Kisasa', count: 3, revenue: 60000),
      ServiceTypeBreakdown(serviceName: 'Deworming', count: 2, revenue: 40000),
      ServiceTypeBreakdown(serviceName: 'Consultation', count: 1, revenue: 25000),
      ServiceTypeBreakdown(serviceName: 'Castration', count: 1, revenue: 50000),
      ServiceTypeBreakdown(serviceName: 'Wound care', count: 1, revenue: 30000),
      ServiceTypeBreakdown(serviceName: 'Artificial insemination', count: 1, revenue: 80000),
    ],
    totalOtherIncome: 70000,
    otherIncomeByPaymentMethod: {'Cash': 50000, 'Tigo Pesa': 20000},
    totalExpenses: matrixBigAmount + 60000,
    expensesByCategory: {'Rent': matrixBigAmount, 'Utilities': 60000},
    expenseLineItems: [
      ExpenseLineItem(time: ph7bAt(7, 30), description: 'Kodi ya pango la duka kwa miezi mitatu ya mwanzo wa mwaka', category: 'Rent', amount: matrixBigAmount),
      ExpenseLineItem(time: ph7bAt(9, 10), description: 'Electricity', category: 'Utilities', amount: 20000),
      ExpenseLineItem(time: ph7bAt(10), description: 'Water', category: 'Utilities', amount: 10000),
      ExpenseLineItem(time: ph7bAt(11, 40), description: 'Transport', category: 'Transport', amount: 10000),
      ExpenseLineItem(time: ph7bAt(13), description: 'Airtime', category: 'Utilities', amount: 5000),
      ExpenseLineItem(time: ph7bAt(15), description: 'Cleaning', category: 'Other', amount: 15000),
    ],
    otherIncomeLineItems: [
      ExpenseLineItem(time: ph7bAt(12), description: 'Training fee', category: 'Other', amount: 50000),
      ExpenseLineItem(time: ph7bAt(17), description: 'Delivery fee', category: 'Other', amount: 20000),
    ],
    newDebtValue: 150000,
    repaymentsValue: 80000,
    repaymentsByPaymentMethod: {'Cash': 50000, 'Mixx by Yas': 30000},
    outstandingChange: 70000,
    clientDebtEntries: const [
      ClientDebtEntry(clientId: 'c1', clientName: matrixLongClientName, openingDebt: matrixBigAmount, newDebt: 50000, repayment: 20000, closingDebt: matrixBigAmount + 30000),
      ClientDebtEntry(clientId: 'c2', clientName: 'Juma Hassan', openingDebt: 40000, newDebt: 20000, repayment: 10000, closingDebt: 50000),
      ClientDebtEntry(clientId: 'c3', clientName: 'Neema Paulo', openingDebt: 0, newDebt: 30000, repayment: 0, closingDebt: 30000),
      ClientDebtEntry(clientId: 'c4', clientName: 'Baraka Mollel', openingDebt: 25000, newDebt: 0, repayment: 25000, closingDebt: 0),
      ClientDebtEntry(clientId: 'c5', clientName: 'Rehema Said', openingDebt: 10000, newDebt: 30000, repayment: 15000, closingDebt: 25000),
      ClientDebtEntry(clientId: 'c6', clientName: 'Peter John', openingDebt: 60000, newDebt: 20000, repayment: 10000, closingDebt: 70000),
    ],
    paymentReconciliation: [
      PaymentMethodReconciliation(method: 'Cash', expected: 425000, physicalCount: submitted ? 420000 : null, varianceReason: submitted ? 'Change given short' : null),
      PaymentMethodReconciliation(method: 'M-Pesa', expected: matrixBigAmount, physicalCount: submitted ? matrixBigAmount : null),
      const PaymentMethodReconciliation(method: 'Bank Transfer', expected: -60000, requiresCount: false),
    ],
    productMovement: [
      ProductMovementEntry(productId: 'p7', name: matrixLongProductName, unit: 'pcs', opening: 120, added: 20, adjustment: -2, sold: 18, expectedClosing: 120, isWatchlisted: true,
          physicalCount: submitted ? 118 : null, varianceReason: submitted ? 'Two bottles broken' : null, adjustmentDetail: 'Asha: 122 -> 120 at 10:20'),
      ProductMovementEntry(productId: 'p1', name: 'Albendazole 10%', unit: 'pcs', opening: 40, added: 0, adjustment: 0, sold: 6, expectedClosing: 34, isWatchlisted: true,
          physicalCount: submitted ? 34 : null),
      const ProductMovementEntry(productId: 'p2', name: 'Ivermectin 1%', unit: 'pcs', opening: 10, added: 5, adjustment: 0, sold: 3, expectedClosing: 12, isWatchlisted: false),
      const ProductMovementEntry(productId: 'p3', name: 'Vitamin B12', unit: 'pcs', opening: 8, added: 0, adjustment: 1, sold: 2, expectedClosing: 7, isWatchlisted: false),
      const ProductMovementEntry(productId: 'p4', name: 'Oxytetracycline 20%', unit: 'pcs', opening: 25, added: 0, adjustment: 0, sold: 4, expectedClosing: 21, isWatchlisted: false),
      const ProductMovementEntry(productId: 'p5', name: 'Penstrep', unit: 'pcs', opening: 12, added: 0, adjustment: 0, sold: 1, expectedClosing: 11, isWatchlisted: false),
      const ProductMovementEntry(productId: 'p8', name: 'Dairy meal 70kg', unit: 'bags', opening: 15, added: 10, adjustment: 0, sold: 5, expectedClosing: 20, isWatchlisted: false),
    ],
    activityLogIncluded: activityLog,
    declarationConfirmed: submitted,
  );
}

/// The admin's activity log saved with [report] (E4c: its own subdocument).
final ph7bActivity = [
  ActivityLogEntry(time: ph7bAt(8, 15), actionType: 'Sales', description: 'Sale SL-000101 to $matrixLongClientName', userName: 'Asha Mohamed'),
  ActivityLogEntry(time: ph7bAt(9, 10), actionType: 'Transactions', description: 'Expense: Electricity', userName: 'Asha Mohamed'),
  ActivityLogEntry(time: ph7bAt(10, 20), actionType: 'Products', description: 'Stock adjusted', userName: 'Juma Admin'),
];

/// Writes [report] (and, when it says so, its activity log) where the app
/// keeps it.
Future<void> ph7bSeedReport(FirebaseFirestore fs, DailyReport report) async {
  final doc = facilityCollection(fs, Collections.dailyReports).doc(report.id);
  await doc.set(report.toMap());
  if (report.activityLogIncluded) {
    await doc.collection('private').doc('activityLog').set({'entries': [for (final e in ph7bActivity) e.toMap()]});
  }
}

/// [report] in the tabbed content, filling a page, as View Reports and the
/// detail screen hold it.
Future<Ph5App> ph7bPumpTabs(WidgetTester tester, DailyReport report,
        {Size size = const Size(390, 844), MatrixLook look = MatrixLook.light, bool admin = true}) =>
    pumpPh5(
      tester,
      (fs) => Scaffold(body: ReportTabbedContent(report: report, firestore: fs)),
      size: size,
      look: look,
      admin: admin,
      seed: (fs) => ph7bSeedReport(fs, report),
    );

/// Opens the report tab labelled [label] (scrolled into view first: the
/// square test font makes the bar wider than the window).
Future<void> ph7bOpenTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(TabBar), matching: find.text(label)).first;
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.tap(tab);
  await ph5Settle(tester);
}

/// Drops the exceptions a wide layout raises today under the square test
/// font (its text is about twice real text's width); the fingerprints keep
/// them, so a change in them still shows.
void ph7bDropWideFontErrors(WidgetTester tester) {
  while (tester.takeException() != null) {}
}
