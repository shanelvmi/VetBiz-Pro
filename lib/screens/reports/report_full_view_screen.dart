import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_report.dart';

/// Opens the full report as a single continuous scroll, mirroring the
/// PDF's own section order - this is the "what would the PDF look
/// like" preview: same structure and flow, but a fast, native render
/// rather than an actual generated PDF document. Follows the same
/// modal convention already established by showAddSaleScreen().
Future<void> showReportFullViewScreen(BuildContext context, DailyReport report) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

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
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.72).clamp(0, 1100).toDouble();
      final modalHeight = (screenSize.height * 0.9) < 480 ? 480.0 : screenSize.height * 0.9;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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

  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color offWhite = Color(0xFFFDFDF9);

  String _money(num value) => NumberFormat.decimalPattern().format(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleBlock(),
                      const SizedBox(height: 20),
                      _summarySection(),
                      const SizedBox(height: 16),
                      _salesSection(),
                      const SizedBox(height: 16),
                      _servicesSection(),
                      const SizedBox(height: 16),
                      _productsSection(),
                      const SizedBox(height: 16),
                      _stockReconciliationSection(),
                      const SizedBox(height: 16),
                      _debtSection(),
                      const SizedBox(height: 16),
                      _expensesSection(),
                      const SizedBox(height: 16),
                      _paymentReconciliationSection(),
                      const SizedBox(height: 16),
                      _paymentMethodsSection(),
                      if (report.activityLogEntries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _activityLogSection(),
                      ],
                      const SizedBox(height: 16),
                      _declarationSection(),
                      const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: primaryDeepGreen),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Full Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (isModal)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            const BackButton(color: Colors.white),
        ],
      ),
    );
  }

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Closing Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryDeepGreen)),
        const SizedBox(height: 6),
        Text(DateFormat('EEEE, d MMMM yyyy').format(report.reportDate),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(
          report.status == 'submitted' ? 'Submitted by ${report.generatedByName}' : 'Draft - not yet submitted',
          style: TextStyle(fontSize: 12.5, color: report.status == 'submitted' ? Colors.grey[600] : Colors.orange[800]),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen));
  }

  Widget _statRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    );
  }

  Widget _summarySection() {
    final revenue = report.salesTotalValue + report.servicesTotalValue + report.totalOtherIncome;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Daily Summary'),
          const SizedBox(height: 8),
          _statRow('Total Sales', 'Tsh ${_money(report.salesTotalValue)}'),
          _statRow('Service Revenue', 'Tsh ${_money(report.servicesTotalValue)}'),
          _statRow('Total Revenue', 'Tsh ${_money(revenue)}', bold: true),
          if (report.totalOtherIncome > 0) _statRow('Other Income', 'Tsh ${_money(report.totalOtherIncome)}'),
          _statRow('Debt Repayments', 'Tsh ${_money(report.repaymentsValue)}'),
          _statRow('Expenses', 'Tsh ${_money(report.totalExpenses)}'),
          _statRow('New Debt Today', 'Tsh ${_money(report.newDebtValue)}'),
        ],
      ),
    );
  }

  Widget _salesSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Sales'),
          const SizedBox(height: 8),
          if (report.salesLineItems.isEmpty)
            _emptyState('No sales recorded today.')
          else
            for (final s in report.salesLineItems) _statRow(s.customerName, 'Tsh ${_money(s.amount)}'),
        ],
      ),
    );
  }

  Widget _servicesSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Veterinary Services'),
          const SizedBox(height: 8),
          if (report.serviceBreakdown.isEmpty)
            _emptyState('No services provided today.')
          else
            for (final s in report.serviceBreakdown) _statRow(s.serviceName, 'Tsh ${_money(s.revenue)}'),
        ],
      ),
    );
  }

  Widget _productsSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Product Movement'),
          const SizedBox(height: 8),
          if (report.productMovement.isEmpty)
            _emptyState('No product movement today.')
          else
            for (final p in report.productMovement)
              _statRow(
                p.name,
                p.adjustment == 0
                    ? 'Sold: ${p.sold} ${p.unit}  |  Closing: ${p.expectedClosing} ${p.unit}'
                    : 'Sold: ${p.sold} ${p.unit}  |  Adjusted: ${p.adjustment > 0 ? '+' : ''}${p.adjustment} ${p.unit}  |  Closing: ${p.expectedClosing} ${p.unit}',
              ),
        ],
      ),
    );
  }

  Widget _stockReconciliationSection() {
    final watchlisted = report.productMovement.where((p) => p.isWatchlisted).toList();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Expected vs Physical Stock'),
          const SizedBox(height: 8),
          if (watchlisted.isEmpty)
            _emptyState('No watch-listed products for this facility.')
          else if (report.status != 'submitted')
            _emptyState('Physical counts have not been submitted yet.')
          else
            for (final p in watchlisted)
              _statRow(p.name, 'Expected: ${p.expectedClosing}  |  Physical: ${p.physicalCount ?? '-'}'),
        ],
      ),
    );
  }

  Widget _debtSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Debt Activity'),
          const SizedBox(height: 8),
          if (report.clientDebtEntries.isEmpty)
            _emptyState('No debt activity today.')
          else
            for (final c in report.clientDebtEntries) _statRow(c.clientName, 'Tsh ${_money(c.closingDebt)}'),
        ],
      ),
    );
  }

  Widget _expensesSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Expenses Recorded'),
          const SizedBox(height: 8),
          if (report.expenseLineItems.isEmpty)
            _emptyState('No expenses recorded today.')
          else
            for (final e in report.expenseLineItems) _statRow(e.description, 'Tsh ${_money(e.amount)}'),
        ],
      ),
    );
  }

  Widget _paymentReconciliationSection() {
    if (report.paymentReconciliation.isEmpty) {
      return _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Payment Reconciliation'),
            const SizedBox(height: 8),
            _emptyState('No payments recorded today.'),
          ],
        ),
      );
    }
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Payment Reconciliation'),
          const SizedBox(height: 8),
          for (final p in report.paymentReconciliation) ...[
            Text(p.method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            _statRow('Expected balance', 'Tsh ${_money(p.expected)}'),
            if (p.physicalCount != null) ...[
              _statRow('Physical balance counted', 'Tsh ${_money(p.physicalCount!)}', bold: true),
              _statRow('Variance', (p.variance != null && p.variance != 0) ? 'Tsh ${_money(p.variance!)} - VARIANCE' : 'Tsh 0 - Match',
                  bold: p.variance != null && p.variance != 0),
              if (p.varianceReason != null && p.varianceReason!.isNotEmpty)
                _statRow('Reason', p.varianceReason!),
            ] else if (!p.requiresCount)
              _emptyState('No income via ${p.method} today - outflow only, no count needed.')
            else
              _emptyState('Not yet submitted.'),
            if (p != report.paymentReconciliation.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _paymentMethodsSection() {
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (byMethod.isEmpty)
            _emptyState(emptyText)
          else
            for (final entry in byMethod.entries) _statRow(entry.key, 'Tsh ${_money(entry.value)}'),
          const SizedBox(height: 10),
        ],
      );
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Payment Methods'),
          const SizedBox(height: 8),
          if (combined.isEmpty)
            _emptyState('No payments recorded today.')
          else ...[
            for (final entry in combined.entries) _statRow(entry.key, 'Tsh ${_money(entry.value)}', bold: true),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            category('Sales', report.salesByPaymentMethod, 'No sales today.'),
            category('Services', report.servicesByPaymentMethod, 'No services today.'),
            category('Debt Repayments', report.repaymentsByPaymentMethod, 'No repayments today.'),
            category('Other Income', report.otherIncomeByPaymentMethod, 'No other income today.'),
          ],
        ],
      ),
    );
  }

  Widget _activityLogSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Activity Log'),
          const SizedBox(height: 8),
          for (final entry in report.activityLogEntries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${DateFormat('HH:mm').format(entry.time)}  ${entry.description} - ${entry.userName}',
                  style: const TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Widget _declarationSection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Daily Closing Declaration'),
          const SizedBox(height: 8),
          Text(
            report.declarationConfirmed
                ? "Confirmed - I have reviewed today's transactions and that the cash and stock figures "
                    'entered represent the closing figures for my shift.'
                : 'Not yet confirmed.',
            style: TextStyle(fontSize: 12.5, color: report.declarationConfirmed ? Colors.green[700] : Colors.orange[800]),
          ),
        ],
      ),
    );
  }
}
