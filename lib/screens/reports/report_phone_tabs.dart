import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../config/money.dart';
import '../../config/payment_methods.dart';
import '../../l10n/l10n.dart';
import '../../models/daily_report.dart';
import '../../theme/activity_type_style.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_safe_area.dart';
import '../../widgets/phone_list/record_tile.dart';
import '../../widgets/phone_report/phone_report_row.dart';
import '../../widgets/phone_report/phone_report_section.dart';
import 'report_activity_log_loader.dart';

/// PH7b (docs/design/phone_reports.md): the report's 10 tabs on a phone, the
/// same figures as the tablet's tabs (report_tabbed_content.dart) as rows
/// of two lines and label-and-value rows. ReportTabbedContent chooses these
/// or its own builders with one AppLayout.isPhone check.
class ReportPhoneTabs {
  final DailyReport report;

  /// An admin: the Activity Log tab exists, and Summary shows Expenses
  /// (PH4b hides Total Expenses from assistants).
  final bool isAdmin;
  final FirebaseFirestore? firestore;

  /// Shown under the Summary's figures (View Reports' Accountability and
  /// Declaration, which sit beside the tabs on wider windows).
  final Widget? summaryFooter;

  const ReportPhoneTabs({required this.report, required this.isAdmin, this.firestore, this.summaryFooter});

  Widget _page(BuildContext context, String id, List<Widget> children) => ListView(
        key: ValueKey('phoneReport-tab-$id'),
        padding: EdgeInsets.fromLTRB(PhoneReportMetrics.pagePadding, PhoneReportMetrics.pagePadding,
            PhoneReportMetrics.pagePadding, PhoneReportMetrics.pagePadding + AppSafeArea.bottomOf(context)),
        children: children,
      );

  String _labelValue(BuildContext context, String label, Object value) => context.l10n.phoneReport_labelValue(label, '$value');

  List<Widget> _methodRows(BuildContext context, Map<String, double> byMethod) => [
        for (final e in PaymentMethod.mergeShown(byMethod).entries)
          PhoneReportStat(label: context.l10n.paymentMethodLabel(e.key), value: Money.format(e.value)),
      ];

  // ---------- Summary (R4) ----------

  Widget summary(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final revenue = report.salesTotalValue + report.servicesTotalValue + report.totalOtherIncome;
    final unitsSold = report.productMovement.fold(0, (sum, p) => sum + p.sold);
    final hint = TextStyle(fontSize: PhoneReportMetrics.subtitle, color: colors.textHint);
    return _page(context, 'summary', [
      PhoneReportSection(
        id: 'summary',
        icon: Icons.dashboard_outlined,
        title: l10n.reports_dailySummary,
        rows: const [],
        footer: [
          PhoneReportStat(label: l10n.reports_totalSales, value: Money.format(report.salesTotalValue)),
          PhoneReportStat(label: l10n.reports_serviceRevenue, value: Money.format(report.servicesTotalValue)),
          PhoneReportStat(label: l10n.payments_typeDebtRepayments, value: Money.format(report.repaymentsValue)),
          if (isAdmin) PhoneReportStat(label: l10n.transactions_expenses, value: Money.format(report.totalExpenses)),
          PhoneReportStat(label: l10n.payments_typeOtherIncome, value: Money.format(report.totalOtherIncome)),
          PhoneReportStat(label: l10n.reports_outstandingNewDebt, value: Money.format(report.newDebtValue)),
          PhoneReportStat(label: l10n.transactions_title, value: '${report.salesCount + report.servicesCount}'),
          PhoneReportStat(label: l10n.reports_servicesPerformed, value: '${report.servicesCount}'),
          PhoneReportStat(label: l10n.reports_productsSold, value: l10n.reports_unitsCount(unitsSold)),
          PhoneReportStat(label: l10n.reports_totalRevenueToday, value: Money.format(revenue), bold: true),
        ],
      ),
      Text(l10n.reports_generatedAtBy(AppDateFormat.dateNoPadTime12Short.format(report.generatedAt), report.generatedByName),
          style: hint),
      if (report.submittedAt != null)
        Text(l10n.reports_submittedAt(AppDateFormat.dateNoPadTime12Short.format(report.submittedAt!)), style: hint),
      if (summaryFooter != null) ...[const SizedBox(height: PhoneReportMetrics.sectionGap), summaryFooter!],
    ]);
  }

  // ---------- Sales ----------

  Widget sales(BuildContext context) {
    final l10n = context.l10n;
    return _page(context, 'sales', [
      PhoneReportSection(
        id: 'sales',
        icon: Icons.shopping_cart_outlined,
        title: l10n.payments_typeSales,
        emptyText: l10n.reports_noSalesToday,
        rows: [
          for (final s in report.salesLineItems)
            PhoneReportRow(
              title: s.customerName,
              amount: Money.format(s.amount),
              details: [
                ReportPart(s.receiptNo),
                ReportPart(AppDateFormat.time24.format(s.time)),
                ReportPart(l10n.sales_itemCount(s.itemCount)),
                ReportPart(l10n.paymentMethodLabel(s.paymentMethod)),
              ],
            ),
        ],
        footer: [
          if (report.salesLineItems.isNotEmpty)
            PhoneReportStat(label: l10n.reports_totalSales, value: Money.format(report.salesTotalValue), bold: true),
        ],
      ),
      if (report.salesByPaymentMethod.isNotEmpty)
        PhoneReportSection(
          id: 'sales-methods',
          icon: Icons.credit_card_outlined,
          title: l10n.reports_paymentMethods,
          rows: const [],
          footer: _methodRows(context, report.salesByPaymentMethod),
        ),
    ]);
  }

  // ---------- Services ----------

  Widget services(BuildContext context) {
    final l10n = context.l10n;
    return _page(context, 'services', [
      PhoneReportSection(
        id: 'services',
        icon: Icons.medical_services_outlined,
        title: l10n.reports_vetServices,
        emptyText: l10n.reports_noServicesToday,
        rows: [
          for (final s in report.serviceBreakdown)
            PhoneReportRow(
              title: s.serviceName,
              amount: Money.format(s.revenue),
              details: [ReportPart(_labelValue(context, l10n.reports_colNumber, s.count))],
            ),
        ],
        footer: [
          if (report.serviceBreakdown.isNotEmpty)
            PhoneReportStat(label: l10n.reports_totalServiceRevenue, value: Money.format(report.servicesTotalValue), bold: true),
        ],
      ),
      if (report.servicesByPaymentMethod.isNotEmpty)
        PhoneReportSection(
          id: 'services-methods',
          icon: Icons.credit_card_outlined,
          title: l10n.reports_paymentMethods,
          rows: const [],
          footer: _methodRows(context, report.servicesByPaymentMethod),
        ),
    ]);
  }

  // ---------- Products ----------

  Widget products(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    String signed(int n) => n == 0 ? '-' : '${n > 0 ? '+' : ''}$n';
    return _page(context, 'products', [
      PhoneReportSection(
        id: 'products',
        icon: Icons.inventory_2_outlined,
        title: l10n.reports_productMovement,
        note: l10n.reports_systemTracked,
        emptyText: l10n.reports_noMovementToday,
        rows: [
          for (final p in report.productMovement)
            PhoneReportRow(
              title: p.name,
              // The tablet's star: a shape, not colour alone.
              icon: p.isWatchlisted ? Icons.star : null,
              iconColor: colors.accent,
              amount: '${p.expectedClosing} ${p.unit.isEmpty ? '' : l10n.productUnitLabel(p.unit)}'.trim(),
              tooltip: p.adjustmentDetail,
              details: [
                ReportPart(_labelValue(context, l10n.reports_colOpening, p.opening)),
                ReportPart(_labelValue(context, l10n.reports_colAdded, p.added)),
                ReportPart(_labelValue(context, l10n.reports_colAdjusted, signed(p.adjustment)),
                    p.adjustment == 0 ? null : colors.warningStrong),
                ReportPart(_labelValue(context, l10n.reports_colSold, p.sold)),
              ],
            ),
        ],
        footer: [
          if (report.productMovement.isNotEmpty)
            PhoneReportStat(
                label: l10n.reports_totalUnitsSold,
                value: '${report.productMovement.fold(0, (sum, p) => sum + p.sold)}',
                bold: true),
        ],
      ),
    ]);
  }

  // ---------- Stock Reconciliation (R5) ----------

  Widget stockReconciliation(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final watchlisted = report.productMovement.where((p) => p.isWatchlisted).toList();
    final submitted = report.status == 'submitted';
    return _page(context, 'stock', [
      PhoneReportSection(
        id: 'stock',
        icon: Icons.fact_check_outlined,
        title: l10n.reports_expectedVsPhysical,
        note: l10n.reports_watchlistedOnly,
        emptyText: watchlisted.isEmpty ? l10n.reports_noWatchlisted : l10n.reports_countsNotSubmitted,
        rows: [
          if (submitted)
            for (final p in watchlisted)
              () {
                final variance = p.variance ?? 0;
                final color = variance == 0 ? colors.successStrong : colors.dangerStrong;
                return PhoneReportRow(
                  title: p.name,
                  amount: variance == 0 ? '0' : '${variance > 0 ? '+' : ''}$variance',
                  amountColor: color,
                  details: [ReportPart(l10n.reports_expectedPhysical(p.expectedClosing, '${p.physicalCount ?? '-'}'))],
                  status: RecordStatus(variance == 0 ? l10n.reports_match : l10n.reports_variance, color),
                  note: variance != 0 && (p.varianceReason ?? '').isNotEmpty ? l10n.reports_reasonValue('${p.varianceReason}') : null,
                );
              }(),
        ],
      ),
    ]);
  }

  // ---------- Debt ----------

  Widget debt(BuildContext context) {
    final l10n = context.l10n;
    return _page(context, 'debt', [
      PhoneReportSection(
        id: 'debt-figures',
        icon: Icons.people_alt_outlined,
        title: l10n.reports_debtActivity,
        rows: const [],
        footer: [
          PhoneReportStat(label: l10n.reports_newDebtTodayLower, value: Money.format(report.newDebtValue)),
          PhoneReportStat(label: l10n.reports_repaymentsCollected, value: Money.format(report.repaymentsValue)),
          PhoneReportStat(label: l10n.reports_outstandingChange, value: Money.format(report.outstandingChange), bold: true),
        ],
      ),
      PhoneReportSection(
        id: 'debt',
        icon: Icons.receipt_long_outlined,
        title: l10n.reports_byCustomer,
        emptyText: l10n.reports_noDebtActivity,
        rows: [
          for (final c in report.clientDebtEntries)
            PhoneReportRow(
              title: c.clientName,
              amount: Money.format(c.closingDebt),
              details: [
                ReportPart(_labelValue(context, l10n.reports_colOpening, Money.format(c.openingDebt))),
                ReportPart(_labelValue(context, l10n.reports_colNewDebt, Money.format(c.newDebt))),
                ReportPart(_labelValue(context, l10n.reports_colRepayment, Money.format(c.repayment))),
              ],
            ),
        ],
      ),
    ]);
  }

  // ---------- Expenses ----------

  Widget expenses(BuildContext context) {
    final l10n = context.l10n;
    return _page(context, 'expenses', [
      PhoneReportSection(
        id: 'expenses',
        icon: Icons.receipt_long_outlined,
        title: l10n.reports_expensesRecorded,
        emptyText: l10n.reports_noExpensesToday,
        rows: [
          for (final e in report.expenseLineItems)
            PhoneReportRow(
              title: e.description,
              amount: Money.format(e.amount),
              details: [
                ReportPart(l10n.transactionCategoryLabel(e.category)),
                ReportPart(AppDateFormat.time24.format(e.time)),
              ],
            ),
        ],
        footer: [
          if (report.expenseLineItems.isNotEmpty)
            PhoneReportStat(label: l10n.reports_totalExpenses, value: Money.format(report.totalExpenses), bold: true),
        ],
      ),
    ]);
  }

  // ---------- Transactions ----------

  Widget transactions(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final combined = [
      ...report.expenseLineItems.map((e) => (item: e, isExpense: true)),
      ...report.otherIncomeLineItems.map((e) => (item: e, isExpense: false)),
    ]..sort((a, b) => a.item.time.compareTo(b.item.time));
    return _page(context, 'transactions', [
      PhoneReportSection(
        id: 'transactions',
        icon: Icons.sync_alt_outlined,
        title: l10n.reports_allTransactions,
        note: l10n.reports_transactionsNote,
        emptyText: l10n.reports_noTransactionsToday,
        rows: [
          for (final entry in combined)
            PhoneReportRow(
              title: entry.item.description,
              amount: '${entry.isExpense ? '-' : '+'}${Money.plain(entry.item.amount)}',
              amountColor: entry.isExpense ? colors.dangerStrong : colors.successStrong,
              details: [
                ReportPart(entry.isExpense ? l10n.transactionType_expense : l10n.payments_typeOtherIncome,
                    entry.isExpense ? colors.dangerStrong : colors.successStrong),
                ReportPart(l10n.transactionCategoryLabel(entry.item.category)),
                ReportPart(AppDateFormat.time24.format(entry.item.time)),
              ],
            ),
        ],
        footer: [
          if (combined.isNotEmpty) ...[
            PhoneReportStat(label: l10n.payments_typeOtherIncome, value: Money.format(report.totalOtherIncome)),
            PhoneReportStat(label: l10n.transactions_expenses, value: Money.format(report.totalExpenses), bold: true),
          ],
        ],
      ),
    ]);
  }

  // ---------- Activity Log (R6: admins only, as today) ----------

  Widget activityLog(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    Widget section(List<Widget> rows, {String? empty}) => PhoneReportSection(
          id: 'activity',
          icon: Icons.history,
          title: l10n.export_activityLog,
          note: l10n.reports_everythingToday,
          emptyText: empty,
          rows: rows,
        );
    return _page(context, 'activity', [
      if (!report.activityLogIncluded)
        section(const [], empty: l10n.reports_activityNotIncluded)
      else
        // From the admin-only subdocument (E4c, a1); this tab is built for
        // admins only.
        ReportActivityLogLoader(
          report: report,
          firestore: firestore,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(PhoneReportMetrics.pagePadding),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) return section(const [], empty: l10n.error_couldNotLoad);
            final entries = snapshot.data;
            if (entries == null) return section(const [], empty: l10n.reports_activityLogNotSaved);
            return section(empty: l10n.reports_noActivityToday, [
              for (final entry in entries)
                PhoneReportRow(
                  title: entry.description,
                  amount: AppDateFormat.time24.format(entry.time),
                  icon: ActivityTypeStyle.icon(entry.actionType),
                  iconColor: ActivityTypeStyle.color(entry.actionType, colors),
                  details: [
                    ReportPart(l10n.activityTypeLabel(entry.actionType), ActivityTypeStyle.color(entry.actionType, colors)),
                    ReportPart(entry.userName),
                  ],
                ),
            ]);
          },
        ),
    ]);
  }

  // ---------- Payment Methods (R7: Tigo Pesa and Mixx by Yas merged) ----------

  Widget paymentMethods(BuildContext context) {
    final l10n = context.l10n;
    final combined = PaymentMethod.combineShown([
      report.salesByPaymentMethod,
      report.servicesByPaymentMethod,
      report.repaymentsByPaymentMethod,
      report.otherIncomeByPaymentMethod,
    ]);
    final combinedTotal = combined.values.fold(0.0, (sum, v) => sum + v);
    Widget category(String id, IconData icon, String title, Map<String, double> byMethod, String emptyText) =>
        PhoneReportSection(
          id: id,
          icon: icon,
          title: title,
          emptyText: emptyText,
          rows: const [],
          footer: _methodRows(context, byMethod),
        );
    return _page(context, 'methods', [
      PhoneReportSection(
        id: 'methods-combined',
        icon: Icons.credit_card_outlined,
        title: l10n.reports_combinedAll,
        note: l10n.reports_combinedNote,
        emptyText: combined.isEmpty ? l10n.reports_noPaymentsToday : null,
        rows: const [],
        footer: [
          for (final e in combined.entries) PhoneReportStat(label: l10n.paymentMethodLabel(e.key), value: Money.format(e.value)),
          if (combined.isNotEmpty) PhoneReportStat(label: l10n.common_total, value: Money.format(combinedTotal), bold: true),
        ],
      ),
      category('methods-sales', Icons.shopping_cart_outlined, l10n.payments_typeSales, report.salesByPaymentMethod,
          l10n.reports_noSalesShort),
      category('methods-services', Icons.medical_services_outlined, l10n.payments_typeServices,
          report.servicesByPaymentMethod, l10n.reports_noServicesShort),
      category('methods-repayments', Icons.people_alt_outlined, l10n.payments_typeDebtRepayments,
          report.repaymentsByPaymentMethod, l10n.reports_noRepaymentsShort),
      category('methods-other', Icons.savings_outlined, l10n.payments_typeOtherIncome, report.otherIncomeByPaymentMethod,
          l10n.reports_noOtherIncomeShort),
    ]);
  }
}
