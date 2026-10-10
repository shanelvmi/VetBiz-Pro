import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/user_role_provider.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';

/// Opens the full report as a single continuous scroll, mirroring the
/// PDF's own section order - this is the "what would the PDF look
/// like" preview: same structure and flow, but a fast, native render
/// rather than an actual generated PDF document. Follows the same
/// modal convention already established by showAddSaleScreen().
Future<void> showReportFullViewScreen(BuildContext context, DailyReport report) async {
  final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportFullViewScreen(report: report, isModal: false)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Full Report',
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.72).clamp(0, 1100).toDouble();
      final modalHeight = (screenSize.height * 0.9) < 480 ? 480.0 : screenSize.height * 0.9;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            child: Material(
              child: ReportFullViewScreen(report: report, isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class ReportFullViewScreen extends StatelessWidget {
  final DailyReport report;
  final bool isModal;

  const ReportFullViewScreen({super.key, required this.report, required this.isModal});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleBlock(context),
                      const SizedBox(height: AppSpacing.s20),
                      _summarySection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _salesSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _servicesSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _productsSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _stockReconciliationSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _debtSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _expensesSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _paymentReconciliationSection(context),
                      const SizedBox(height: AppSpacing.s16),
                      _paymentMethodsSection(context),
                      // Admins only - it lists everyone's activity.
                      if (Provider.of<UserRoleProvider>(context, listen: false).isAdmin &&
                          report.activityLogEntries.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s16),
                        _activityLogSection(context),
                      ],
                      const SizedBox(height: AppSpacing.s16),
                      _declarationSection(context),
                      const SizedBox(height: AppSpacing.s24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
      decoration: BoxDecoration(color: context.colors.primary),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: context.colors.onPrimary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text('Full Report', style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
          ),
          if (isModal)
            IconButton(
              icon: Icon(Icons.close, color: context.colors.onPrimary),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            BackButton(color: context.colors.onPrimary),
        ],
      ),
    );
  }

  Widget _titleBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Closing Report', style: TextStyle(fontSize: AppFontSize.f22, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
        const SizedBox(height: AppSpacing.s6),
        Text(AppDateFormat.dateLongFull.format(report.reportDate),
            style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
        Text(
          report.status == 'submitted' ? 'Submitted by ${report.generatedByName}' : 'Draft - not yet submitted',
          style: TextStyle(fontSize: AppFontSize.f12_5, color: report.status == 'submitted' ? context.colors.textMuted : context.colors.warningStrong),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary));
  }

  Widget _statRow(BuildContext context, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
          Text(value, style: TextStyle(fontSize: AppFontSize.f13, fontWeight: bold ? AppFontWeight.bold : AppFontWeight.medium)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Text(message, style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f13)),
    );
  }

  Widget _summarySection(BuildContext context) {
    final revenue = report.salesTotalValue + report.servicesTotalValue + report.totalOtherIncome;
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Daily Summary'),
          const SizedBox(height: AppSpacing.s8),
          _statRow(context, 'Total Sales', Money.symbolDecimal(report.salesTotalValue)),
          _statRow(context, 'Service Revenue', Money.symbolDecimal(report.servicesTotalValue)),
          _statRow(context, 'Total Revenue', Money.symbolDecimal(revenue), bold: true),
          if (report.totalOtherIncome > 0) _statRow(context, 'Other Income', Money.symbolDecimal(report.totalOtherIncome)),
          _statRow(context, 'Debt Repayments', Money.symbolDecimal(report.repaymentsValue)),
          _statRow(context, 'Expenses', Money.symbolDecimal(report.totalExpenses)),
          _statRow(context, 'New Debt Today', Money.symbolDecimal(report.newDebtValue)),
        ],
      ),
    );
  }

  Widget _salesSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Sales'),
          const SizedBox(height: AppSpacing.s8),
          if (report.salesLineItems.isEmpty)
            _emptyState(context, 'No sales recorded today.')
          else
            for (final s in report.salesLineItems) _statRow(context, s.customerName, Money.symbolDecimal(s.amount)),
        ],
      ),
    );
  }

  Widget _servicesSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Veterinary Services'),
          const SizedBox(height: AppSpacing.s8),
          if (report.serviceBreakdown.isEmpty)
            _emptyState(context, 'No services provided today.')
          else
            for (final s in report.serviceBreakdown) _statRow(context, s.serviceName, Money.symbolDecimal(s.revenue)),
        ],
      ),
    );
  }

  Widget _productsSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Product Movement'),
          const SizedBox(height: AppSpacing.s8),
          if (report.productMovement.isEmpty)
            _emptyState(context, 'No product movement today.')
          else
            for (final p in report.productMovement)
              _statRow(context, 
                p.name,
                p.adjustment == 0
                    ? 'Sold: ${p.sold} ${p.unit}  |  Closing: ${p.expectedClosing} ${p.unit}'
                    : 'Sold: ${p.sold} ${p.unit}  |  Adjusted: ${p.adjustment > 0 ? '+' : ''}${p.adjustment} ${p.unit}  |  Closing: ${p.expectedClosing} ${p.unit}',
              ),
        ],
      ),
    );
  }

  Widget _stockReconciliationSection(BuildContext context) {
    final watchlisted = report.productMovement.where((p) => p.isWatchlisted).toList();
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Expected vs Physical Stock'),
          const SizedBox(height: AppSpacing.s8),
          if (watchlisted.isEmpty)
            _emptyState(context, 'No watch-listed products for this facility.')
          else if (report.status != 'submitted')
            _emptyState(context, 'Physical counts have not been submitted yet.')
          else
            for (final p in watchlisted)
              _statRow(context, p.name, 'Expected: ${p.expectedClosing}  |  Physical: ${p.physicalCount ?? '-'}'),
        ],
      ),
    );
  }

  Widget _debtSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Debt Activity'),
          const SizedBox(height: AppSpacing.s8),
          if (report.clientDebtEntries.isEmpty)
            _emptyState(context, 'No debt activity today.')
          else
            for (final c in report.clientDebtEntries) _statRow(context, c.clientName, Money.symbolDecimal(c.closingDebt)),
        ],
      ),
    );
  }

  Widget _expensesSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Expenses Recorded'),
          const SizedBox(height: AppSpacing.s8),
          if (report.expenseLineItems.isEmpty)
            _emptyState(context, 'No expenses recorded today.')
          else
            for (final e in report.expenseLineItems) _statRow(context, e.description, Money.symbolDecimal(e.amount)),
        ],
      ),
    );
  }

  Widget _paymentReconciliationSection(BuildContext context) {
    if (report.paymentReconciliation.isEmpty) {
      return _card(context, 
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Payment Reconciliation'),
            const SizedBox(height: AppSpacing.s8),
            _emptyState(context, 'No payments recorded today.'),
          ],
        ),
      );
    }
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Payment Reconciliation'),
          const SizedBox(height: AppSpacing.s8),
          for (final p in report.paymentReconciliation) ...[
            Text(p.method, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
            _statRow(context, 'Expected balance', Money.symbolDecimal(p.expected)),
            if (p.physicalCount != null) ...[
              _statRow(context, 'Physical balance counted', Money.symbolDecimal(p.physicalCount!), bold: true),
              _statRow(context, 'Variance', (p.variance != null && p.variance != 0) ? '${Money.symbolDecimal(p.variance!)} - VARIANCE' : '${Money.symbolDecimal(0)} - Match',
                  bold: p.variance != null && p.variance != 0),
              if (p.varianceReason != null && p.varianceReason!.isNotEmpty)
                _statRow(context, 'Reason', p.varianceReason!),
            ] else if (!p.requiresCount)
              _emptyState(context, 'No income via ${p.method} today - outflow only, no count needed.')
            else
              _emptyState(context, 'Not yet submitted.'),
            if (p != report.paymentReconciliation.last) const SizedBox(height: AppSpacing.s10),
          ],
        ],
      ),
    );
  }

  Widget _paymentMethodsSection(BuildContext context) {
    final combined = <String, double>{};
    for (final entry in report.salesByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in report.servicesByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in report.repaymentsByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in report.otherIncomeByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }

    Widget category(String title, Map<String, double> byMethod, String emptyText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
          if (byMethod.isEmpty)
            _emptyState(context, emptyText)
          else
            for (final entry in byMethod.entries) _statRow(context, entry.key, Money.symbolDecimal(entry.value)),
          const SizedBox(height: AppSpacing.s10),
        ],
      );
    }

    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Payment Methods'),
          const SizedBox(height: AppSpacing.s8),
          if (combined.isEmpty)
            _emptyState(context, 'No payments recorded today.')
          else ...[
            for (final entry in combined.entries) _statRow(context, entry.key, Money.symbolDecimal(entry.value), bold: true),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),
            category('Sales', report.salesByPaymentMethod, 'No sales today.'),
            category('Services', report.servicesByPaymentMethod, 'No services today.'),
            category('Debt Repayments', report.repaymentsByPaymentMethod, 'No repayments today.'),
            category('Other Income', report.otherIncomeByPaymentMethod, 'No other income today.'),
          ],
        ],
      ),
    );
  }

  Widget _activityLogSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Activity Log'),
          const SizedBox(height: AppSpacing.s8),
          for (final entry in report.activityLogEntries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Text('${AppDateFormat.time24.format(entry.time)}  ${entry.description} - ${entry.userName}',
                  style: const TextStyle(fontSize: AppFontSize.f12_5)),
            ),
        ],
      ),
    );
  }

  Widget _declarationSection(BuildContext context) {
    return _card(context, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Daily Closing Declaration'),
          const SizedBox(height: AppSpacing.s8),
          Text(
            report.declarationConfirmed
                ? "Confirmed - I have reviewed today's transactions and that the cash and stock figures "
                    'entered represent the closing figures for my shift.'
                : 'Not yet confirmed.',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: report.declarationConfirmed ? context.colors.successStrong : context.colors.warningStrong),
          ),
        ],
      ),
    );
  }
}
