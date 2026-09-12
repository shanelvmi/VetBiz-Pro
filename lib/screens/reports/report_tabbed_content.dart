import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/daily_report.dart';

/// The full tabbed report layout (Summary through Activity Log) -
/// extracted as its own reusable widget since both the main "today's
/// report" view and the read-only past-report detail view need the
/// exact same tab structure, and duplicating ~600 lines of
/// tab-building code between them would mean every future change
/// needing to be made twice.
class ReportTabbedContent extends StatefulWidget {
  final DailyReport report;

  const ReportTabbedContent({super.key, required this.report});

  @override
  State<ReportTabbedContent> createState() => _ReportTabbedContentState();
}

class _ReportTabbedContentState extends State<ReportTabbedContent> with SingleTickerProviderStateMixin {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  late TabController _tabController;
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();

  static const _tabs = ['Summary', 'Sales', 'Services', 'Products', 'Stock Reconciliation', 'Debt', 'Expenses', 'Transactions', 'Activity Log', 'Payment Methods'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DailyReport get report => widget.report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: primaryDeepGreen,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: primaryDeepGreen,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryTab(),
              _buildSalesTab(),
              _buildServicesTab(),
              _buildProductsTab(),
              _buildStockReconciliationTab(),
              _buildDebtTab(),
              _buildExpensesTab(),
              _buildTransactionsTab(),
              _buildActivityLogTab(),
              _buildPaymentMethodsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabScroll(List<Widget> children) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDeepGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen)),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(List<String> labels, List<int> flexes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flexes[i],
            child: Text(labels[i],
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey[600])),
          );
        }),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
    );
  }

  // ---------- Summary ----------

  Widget _buildSummaryTab() {
    final revenue = report.salesTotalValue + report.servicesTotalValue;
    final totalCashReceived = (report.salesByPaymentMethod['Cash'] ?? 0) + (report.servicesByPaymentMethod['Cash'] ?? 0);
    final productsSoldUnits = report.productMovement.fold(0, (sum, p) => sum + p.sold);
    final transactionsCount = report.salesCount + report.servicesCount;

    // Exactly ten tiles, two fixed rows of five - a Wrap can't
    // guarantee five-per-row on every screen width, so this uses
    // plain Row/Expanded instead, same as the count is fixed and
    // known ahead of time.
    final row1 = [
      _summaryTile('Total Sales', 'Tsh ${_moneyFormat.format(report.salesTotalValue)}', Icons.shopping_cart_outlined, Colors.blue),
      _summaryTile('Service Revenue', 'Tsh ${_moneyFormat.format(report.servicesTotalValue)}', Icons.medical_services_outlined, Colors.green),
      _summaryTile('Debt Repayments', 'Tsh ${_moneyFormat.format(report.repaymentsValue)}', Icons.people_alt_outlined, Colors.purple),
      _summaryTile('Expenses', 'Tsh ${_moneyFormat.format(report.totalExpenses)}', Icons.receipt_long_outlined, Colors.red),
      _summaryTile('Total Cash Received', 'Tsh ${_moneyFormat.format(totalCashReceived)}', Icons.payments_outlined, primaryDeepGreen),
    ];
    final row2 = [
      _summaryTile('Outstanding New Debt', 'Tsh ${_moneyFormat.format(report.newDebtValue)}', Icons.warning_amber_outlined, Colors.orange),
      _summaryTile('Transactions', '$transactionsCount', Icons.sync_alt_outlined, Colors.blueGrey),
      _summaryTile('Services Performed', '${report.servicesCount}', Icons.build_outlined, Colors.teal),
      _summaryTile('Products Sold', '$productsSoldUnits units', Icons.inventory_2_outlined, warmAmber.withValues(alpha: 0.9)),
      _summaryTile('Total Revenue Today', 'Tsh ${_moneyFormat.format(revenue)}', Icons.trending_up_outlined, primaryDeepGreen),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.dashboard_outlined, 'Daily Summary'),
                const SizedBox(height: 14),
                _tileRow(row1),
                const SizedBox(height: 12),
                _tileRow(row2),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _summaryPreviewGrid()),
          const SizedBox(height: 8),
          Text('Generated at ${DateFormat('d MMM yyyy, h:mm a').format(report.generatedAt)} by ${report.generatedByName}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
          if (report.submittedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Submitted at ${DateFormat('d MMM yyyy, h:mm a').format(report.submittedAt!)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }

  Widget _tileRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  // Tab indices, matching _tabs - used so "View all" can jump straight
  // to the relevant tab instead of just describing where to look.
  static const _salesTabIndex = 1;
  static const _servicesTabIndex = 2;
  static const _productsTabIndex = 3;
  static const _debtTabIndex = 5;

  void _goToTab(int index) => _tabController.animateTo(index);

  Widget _summaryPreviewGrid() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _salesPreviewCard()),
              const SizedBox(width: 16),
              Expanded(child: _servicesPreviewCard()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _productsPreviewCard()),
              const SizedBox(width: 16),
              Expanded(child: _debtPreviewCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewCardShell({
    required IconData icon,
    required String title,
    required VoidCallback onViewAll,
    required Widget content,
  }) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(icon, title),
              InkWell(
                onTap: onViewAll,
                child: Text('View all', style: TextStyle(fontSize: 12, color: primaryDeepGreen, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      ),
    );
  }

  Widget _salesPreviewCard() {
    final preview = report.salesLineItems.take(3).toList();
    return _previewCardShell(
      icon: Icons.shopping_cart_outlined,
      title: 'Sales',
      onViewAll: () => _goToTab(_salesTabIndex),
      content: preview.isEmpty
          ? _emptyState('No sales recorded today.')
          : Column(
              children: [
                for (final s in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.customerName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                        Text('Tsh ${_moneyFormat.format(s.amount)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _servicesPreviewCard() {
    final preview = report.serviceBreakdown.take(3).toList();
    return _previewCardShell(
      icon: Icons.medical_services_outlined,
      title: 'Veterinary Services',
      onViewAll: () => _goToTab(_servicesTabIndex),
      content: preview.isEmpty
          ? _emptyState('No services provided today.')
          : Column(
              children: [
                for (final s in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.serviceName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                        Text('Tsh ${_moneyFormat.format(s.revenue)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _productsPreviewCard() {
    final preview = report.productMovement.take(3).toList();
    return _previewCardShell(
      icon: Icons.inventory_2_outlined,
      title: 'Product Movement',
      onViewAll: () => _goToTab(_productsTabIndex),
      content: preview.isEmpty
          ? _emptyState('No product movement today.')
          : Column(
              children: [
                for (final p in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                        Text('Sold: ${p.sold}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _debtPreviewCard() {
    final preview = report.clientDebtEntries.take(3).toList();
    return _previewCardShell(
      icon: Icons.people_alt_outlined,
      title: 'Debt Activity',
      onViewAll: () => _goToTab(_debtTabIndex),
      content: preview.isEmpty
          ? _emptyState('No debt activity today.')
          : Column(
              children: [
                for (final c in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(c.clientName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                        Text('Tsh ${_moneyFormat.format(c.closingDebt)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Sales ----------

  Widget _buildSalesTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.shopping_cart_outlined, 'Sales'),
            const SizedBox(height: 8),
            if (report.salesLineItems.isEmpty)
              _emptyState('No sales recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Receipt', 'Customer', 'Items', 'Amount', 'Payment'], [2, 2, 3, 1, 2, 2]),
              const Divider(height: 1),
              for (final s in report.salesLineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(DateFormat('HH:mm').format(s.time), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(s.receiptNo, style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 3, child: Text(s.customerName, style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 1, child: Text('${s.itemCount}', style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(s.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text(s.paymentMethod, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _statRow('Total Sales', 'Tsh ${_moneyFormat.format(report.salesTotalValue)}', bold: true),
            ],
          ],
        ),
      ),
      if (report.salesByPaymentMethod.isNotEmpty) ...[
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.credit_card_outlined, 'Payment Methods'),
              const SizedBox(height: 8),
              for (final e in report.salesByPaymentMethod.entries)
                _statRow(e.key, 'Tsh ${_moneyFormat.format(e.value)}'),
            ],
          ),
        ),
      ],
    ]);
  }

  // ---------- Services ----------

  Widget _buildServicesTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.medical_services_outlined, 'Veterinary Services'),
            const SizedBox(height: 8),
            if (report.serviceBreakdown.isEmpty)
              _emptyState('No services provided today.')
            else ...[
              _tableHeaderRow(['Service', 'Number', 'Revenue'], [4, 2, 2]),
              const Divider(height: 1),
              for (final s in report.serviceBreakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text(s.serviceName, style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 2, child: Text('${s.count}', style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 2, child: Text('Tsh ${_moneyFormat.format(s.revenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _statRow('Total Service Revenue', 'Tsh ${_moneyFormat.format(report.servicesTotalValue)}', bold: true),
            ],
          ],
        ),
      ),
      if (report.servicesByPaymentMethod.isNotEmpty) ...[
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.credit_card_outlined, 'Payment Methods'),
              const SizedBox(height: 8),
              for (final e in report.servicesByPaymentMethod.entries)
                _statRow(e.key, 'Tsh ${_moneyFormat.format(e.value)}'),
            ],
          ),
        ),
      ],
    ]);
  }

  // ---------- Products ----------

  Widget _buildProductsTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.inventory_2_outlined, 'Product Movement'),
            const SizedBox(height: 4),
            Text('System-tracked - only products with movement today, or watch-listed products, are shown.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            if (report.productMovement.isEmpty)
              _emptyState('No product movement today.')
            else ...[
              _tableHeaderRow(['Product', 'Opening', 'Added', 'Sold', 'Expected Closing'], [4, 2, 2, 2, 3]),
              const Divider(height: 1),
              for (final p in report.productMovement)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: p.isWatchlisted
                      ? BoxDecoration(
                          color: warmAmber.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            if (p.isWatchlisted) ...[
                              Icon(Icons.star, size: 13, color: warmAmber.withValues(alpha: 0.9)),
                              const SizedBox(width: 4),
                            ],
                            Flexible(child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text('${p.opening}', style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 2, child: Text('${p.added}', style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 2, child: Text('${p.sold}', style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 3, child: Text('${p.expectedClosing}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _statRow('Total Units Sold', '${report.productMovement.fold(0, (sum, p) => sum + p.sold)}', bold: true),
            ],
          ],
        ),
      ),
    ]);
  }

  // ---------- Stock Reconciliation ----------

  Widget _buildStockReconciliationTab() {
    final watchlisted = report.productMovement.where((p) => p.isWatchlisted).toList();
    final isSubmitted = report.status == 'submitted';

    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.fact_check_outlined, 'Expected vs Physical Stock'),
            const SizedBox(height: 4),
            Text('Watch-listed products only.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            if (watchlisted.isEmpty)
              _emptyState('No watch-listed products for this facility.')
            else if (!isSubmitted)
              _emptyState('Physical counts have not been submitted yet.')
            else ...[
              _tableHeaderRow(['Product', 'Expected', 'Physical', 'Difference', 'Status'], [3, 2, 2, 2, 2]),
              const Divider(height: 1),
              for (final p in watchlisted) _buildReconciliationRow(p),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _buildReconciliationRow(ProductMovementEntry p) {
    final variance = p.variance ?? 0;
    final hasVariance = variance != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Expanded(flex: 2, child: Text('${p.expectedClosing}', style: const TextStyle(fontSize: 13))),
              Expanded(flex: 2, child: Text('${p.physicalCount ?? '-'}', style: const TextStyle(fontSize: 13))),
              Expanded(
                flex: 2,
                child: Text(hasVariance ? '${variance > 0 ? '+' : ''}$variance' : '0',
                    style: TextStyle(fontSize: 13, color: hasVariance ? Colors.red[700] : Colors.black87, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 2,
                child: hasVariance
                    ? Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red[700]), const SizedBox(width: 3), Text('Variance', style: TextStyle(fontSize: 12, color: Colors.red[700]))])
                    : Row(children: [Icon(Icons.check_circle_outline, size: 14, color: Colors.green[600]), const SizedBox(width: 3), Text('Match', style: TextStyle(fontSize: 12, color: Colors.green[700]))]),
              ),
            ],
          ),
          if (hasVariance && (p.varianceReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Reason: ${p.varianceReason}', style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  // ---------- Debt ----------

  Widget _buildDebtTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.people_alt_outlined, 'Debt Activity'),
            const SizedBox(height: 10),
            _statRow('New debt today', 'Tsh ${_moneyFormat.format(report.newDebtValue)}'),
            _statRow('Repayments collected', 'Tsh ${_moneyFormat.format(report.repaymentsValue)}'),
            _statRow('Outstanding change', 'Tsh ${_moneyFormat.format(report.outstandingChange)}', bold: true),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.receipt_long_outlined, 'By Customer'),
            const SizedBox(height: 8),
            if (report.clientDebtEntries.isEmpty)
              _emptyState('No debt activity today.')
            else ...[
              _tableHeaderRow(['Customer', 'Opening', 'New Debt', 'Repayment', 'Closing'], [3, 2, 2, 2, 2]),
              const Divider(height: 1),
              for (final c in report.clientDebtEntries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(c.clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(c.openingDebt), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(c.newDebt), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(c.repayment), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(c.closingDebt), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ]);
  }

  // ---------- Expenses ----------

  Widget _buildExpensesTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.receipt_long_outlined, 'Expenses Recorded'),
            const SizedBox(height: 8),
            if (report.expenseLineItems.isEmpty)
              _emptyState('No expenses recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Description', 'Category', 'Amount'], [2, 4, 3, 2]),
              const Divider(height: 1),
              for (final e in report.expenseLineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(DateFormat('HH:mm').format(e.time), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 4, child: Text(e.description, style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 3, child: Text(e.category, style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(_moneyFormat.format(e.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _statRow('Total Expenses', 'Tsh ${_moneyFormat.format(report.totalExpenses)}', bold: true),
            ],
          ],
        ),
      ),
    ]);
  }

  // ---------- Transactions ----------

  Widget _buildTransactionsTab() {
    final combined = [
      ...report.expenseLineItems.map((e) => (item: e, isExpense: true)),
      ...report.otherIncomeLineItems.map((e) => (item: e, isExpense: false)),
    ]..sort((a, b) => a.item.time.compareTo(b.item.time));

    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.sync_alt_outlined, 'All Transactions'),
            const SizedBox(height: 4),
            Text('Income and expenses recorded directly, separate from sales and service revenue.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            if (combined.isEmpty)
              _emptyState('No transactions recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Description', 'Category', 'Type', 'Amount'], [2, 3, 2, 2, 2]),
              const Divider(height: 1),
              for (final entry in combined)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(DateFormat('HH:mm').format(entry.item.time), style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 3, child: Text(entry.item.description, style: const TextStyle(fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(entry.item.category, style: const TextStyle(fontSize: 12.5))),
                      Expanded(
                        flex: 2,
                        child: Text(entry.isExpense ? 'Expense' : 'Other Income',
                            style: TextStyle(fontSize: 12, color: entry.isExpense ? Colors.red[700] : Colors.green[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${entry.isExpense ? '-' : '+'}${_moneyFormat.format(entry.item.amount)}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: entry.isExpense ? Colors.red[700] : Colors.green[700])),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _statRow('Other Income', 'Tsh ${_moneyFormat.format(report.totalOtherIncome)}'),
              _statRow('Expenses', 'Tsh ${_moneyFormat.format(report.totalExpenses)}', bold: true),
            ],
          ],
        ),
      ),
    ]);
  }

  // ---------- Activity Log ----------

  // Matches the icon/color mapping used by the app's own standalone
  // Activity Log screen, so this tab feels like the same feature
  // rather than a separately-styled one.
  IconData _activityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _activityColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'inventory move':
        return Colors.blue;
      case 'products':
        return Colors.green;
      case 'sales':
        return warmAmber;
      case 'services':
        return Colors.purple;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      case 'admin':
        return Colors.red;
      default:
        return primaryDeepGreen;
    }
  }

  Widget _buildActivityLogTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.history, 'Activity Log'),
            const SizedBox(height: 4),
            Text('Everything recorded today, in order.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            if (report.activityLogEntries.isEmpty)
              _emptyState('No activity recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Type', 'Description', 'By'], [1, 2, 4, 2]),
              const Divider(height: 1),
              for (final entry in report.activityLogEntries) _buildActivityRow(entry),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _buildActivityRow(ActivityLogEntry entry) {
    final color = _activityColor(entry.actionType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(DateFormat('HH:mm').format(entry.time), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_activityIcon(entry.actionType), size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(child: Text(entry.actionType, style: TextStyle(fontSize: 12, color: color), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 4, child: Text(entry.description, style: const TextStyle(fontSize: 12.5))),
          Expanded(flex: 2, child: Text(entry.userName, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
        ],
      ),
    );
  }

  // ---------- Payment Methods ----------

  Widget _buildPaymentMethodsTab() {
    final combined = <String, double>{};
    for (final entry in report.salesByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in report.servicesByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    final combinedTotal = combined.values.fold(0.0, (sum, v) => sum + v);

    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.credit_card_outlined, 'Combined - All Payment Methods'),
            const SizedBox(height: 4),
            Text('Sales and service revenue together, by how it was actually received.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            if (combined.isEmpty)
              _emptyState('No payments recorded today.')
            else ...[
              for (final entry in combined.entries) _statRow(entry.key, 'Tsh ${_moneyFormat.format(entry.value)}'),
              const Divider(height: 18),
              _statRow('Total', 'Tsh ${_moneyFormat.format(combinedTotal)}', bold: true),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(Icons.shopping_cart_outlined, 'Sales'),
                    const SizedBox(height: 10),
                    if (report.salesByPaymentMethod.isEmpty)
                      _emptyState('No sales today.')
                    else
                      for (final entry in report.salesByPaymentMethod.entries)
                        _statRow(entry.key, 'Tsh ${_moneyFormat.format(entry.value)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(Icons.medical_services_outlined, 'Services'),
                    const SizedBox(height: 10),
                    if (report.servicesByPaymentMethod.isEmpty)
                      _emptyState('No services today.')
                    else
                      for (final entry in report.servicesByPaymentMethod.entries)
                        _statRow(entry.key, 'Tsh ${_moneyFormat.format(entry.value)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}
