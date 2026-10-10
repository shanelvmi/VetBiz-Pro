import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/user_role_provider.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

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

  late TabController _tabController;

  static const _tabs = ['Summary', 'Sales', 'Services', 'Products', 'Stock Reconciliation', 'Debt', 'Expenses', 'Transactions', 'Activity Log', 'Payment Methods'];

  // The Activity Log tab is the admins' (it lists everyone's activity); an
  // assistant opening a report doesn't get it.
  late final bool _showActivityLog;
  late final List<String> _tabTitles;

  @override
  void initState() {
    super.initState();
    _showActivityLog = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;
    _tabTitles = _showActivityLog ? _tabs : _tabs.where((t) => t != 'Activity Log').toList();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
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
          color: context.colors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: context.colors.primary,
            unselectedLabelColor: context.colors.textMuted,
            indicatorColor: context.colors.primary,
            labelStyle: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13),
            tabs: _tabTitles.map((t) => Tab(text: t)).toList(),
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
              if (_showActivityLog) _buildActivityLogTab(),
              _buildPaymentMethodsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabScroll(List<Widget> children) {
    return ListView(padding: const EdgeInsets.all(AppSpacing.s16), children: children);
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
          Text(value,
              style: TextStyle(
                  fontSize: AppFontSize.f13, fontWeight: bold ? AppFontWeight.bold : AppFontWeight.medium, color: valueColor)),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(List<String> labels, List<int> flexes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flexes[i],
            child: Text(labels[i],
                style: TextStyle(fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.bold, color: context.colors.textMuted)),
          );
        }),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
      child: Center(child: Text(message, style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f13))),
    );
  }

  // ---------- Summary ----------

  Widget _buildSummaryTab() {
    final revenue = report.salesTotalValue + report.servicesTotalValue + report.totalOtherIncome;
    final productsSoldUnits = report.productMovement.fold(0, (sum, p) => sum + p.sold);
    final transactionsCount = report.salesCount + report.servicesCount;

    // Exactly ten tiles, two fixed rows of five - a Wrap can't
    // guarantee five-per-row on every screen width, so this uses
    // plain Row/Expanded instead, same as the count is fixed and
    // known ahead of time.
    final row1 = [
      _summaryTile('Total Sales', Money.symbolDecimal(report.salesTotalValue), Icons.shopping_cart_outlined, context.colors.info),
      _summaryTile('Service Revenue', Money.symbolDecimal(report.servicesTotalValue), Icons.medical_services_outlined, context.colors.success),
      _summaryTile('Debt Repayments', Money.symbolDecimal(report.repaymentsValue), Icons.people_alt_outlined, Colors.purple),
      _summaryTile('Expenses', Money.symbolDecimal(report.totalExpenses), Icons.receipt_long_outlined, context.colors.danger),
      _summaryTile('Other Income', Money.symbolDecimal(report.totalOtherIncome), Icons.savings_outlined, context.colors.primary),
    ];
    final row2 = [
      _summaryTile('Outstanding New Debt', Money.symbolDecimal(report.newDebtValue), Icons.warning_amber_outlined, context.colors.warning),
      _summaryTile('Transactions', '$transactionsCount', Icons.sync_alt_outlined, Colors.blueGrey),
      _summaryTile('Services Performed', '${report.servicesCount}', Icons.build_outlined, Colors.teal),
      _summaryTile('Products Sold', '$productsSoldUnits units', Icons.inventory_2_outlined, context.colors.accent.withValues(alpha: AppAlpha.a85)),
      _summaryTile('Total Revenue Today', Money.symbolDecimal(revenue), Icons.trending_up_outlined, context.colors.primary),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.dashboard_outlined, 'Daily Summary'),
                const SizedBox(height: AppSpacing.s14),
                _tileRow(row1),
                const SizedBox(height: AppSpacing.s12),
                _tileRow(row2),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Expanded(child: _summaryPreviewGrid()),
          const SizedBox(height: AppSpacing.s8),
          Text('Generated at ${AppDateFormat.dateNoPadTime12Short.format(report.generatedAt)} by ${report.generatedByName}',
              style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
          if (report.submittedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text('Submitted at ${AppDateFormat.dateNoPadTime12Short.format(report.submittedAt!)}',
                  style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
            ),
        ],
      ),
    );
  }

  Widget _tileRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s10),
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
              const SizedBox(width: AppSpacing.s16),
              Expanded(child: _servicesPreviewCard()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _productsPreviewCard()),
              const SizedBox(width: AppSpacing.s16),
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
                child: Text('View all', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.customerName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.symbolDecimal(s.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.serviceName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.symbolDecimal(s.revenue), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text('Sold: ${p.sold}', style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(c.clientName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.symbolDecimal(c.closingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: color.withValues(alpha: AppAlpha.a20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.i20, color: color),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textSoft)),
                const SizedBox(height: AppSpacing.s2),
                Text(value, style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.bold)),
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
            const SizedBox(height: AppSpacing.s8),
            if (report.salesLineItems.isEmpty)
              _emptyState('No sales recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Receipt', 'Customer', 'Items', 'Amount', 'Payment'], [2, 2, 3, 1, 2, 2]),
              const Divider(height: 1),
              for (final s in report.salesLineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppDateFormat.time24.format(s.time), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(s.receiptNo, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 3, child: Text(s.customerName, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 1, child: Text('${s.itemCount}', style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.decimal(s.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
                      Expanded(flex: 2, child: Text(s.paymentMethod, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow('Total Sales', Money.symbolDecimal(report.salesTotalValue), bold: true),
            ],
          ],
        ),
      ),
      if (report.salesByPaymentMethod.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.credit_card_outlined, 'Payment Methods'),
              const SizedBox(height: AppSpacing.s8),
              for (final e in report.salesByPaymentMethod.entries)
                _statRow(e.key, Money.symbolDecimal(e.value)),
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
            const SizedBox(height: AppSpacing.s8),
            if (report.serviceBreakdown.isEmpty)
              _emptyState('No services provided today.')
            else ...[
              _tableHeaderRow(['Service', 'Number', 'Revenue'], [4, 2, 2]),
              const Divider(height: 1),
              for (final s in report.serviceBreakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text(s.serviceName, style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 2, child: Text('${s.count}', style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 2, child: Text(Money.symbolDecimal(s.revenue), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow('Total Service Revenue', Money.symbolDecimal(report.servicesTotalValue), bold: true),
            ],
          ],
        ),
      ),
      if (report.servicesByPaymentMethod.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.credit_card_outlined, 'Payment Methods'),
              const SizedBox(height: AppSpacing.s8),
              for (final e in report.servicesByPaymentMethod.entries)
                _statRow(e.key, Money.symbolDecimal(e.value)),
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
            const SizedBox(height: AppSpacing.s4),
            Text('System-tracked - only products with movement today, or watch-listed products, are shown.',
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (report.productMovement.isEmpty)
              _emptyState('No product movement today.')
            else ...[
              _tableHeaderRow(['Product', 'Unit', 'Opening', 'Added', 'Adjusted', 'Sold', 'Expected Closing'], [4, 2, 2, 2, 2, 2, 3]),
              const Divider(height: 1),
              for (final p in report.productMovement)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  decoration: p.isWatchlisted
                      ? BoxDecoration(
                          color: context.colors.accent.withValues(alpha: AppAlpha.a05),
                          borderRadius: BorderRadius.circular(AppRadius.r6),
                        )
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            if (p.isWatchlisted) ...[
                              Icon(Icons.star, size: AppIconSize.i14, color: context.colors.accent.withValues(alpha: AppAlpha.a85)),
                              const SizedBox(width: AppSpacing.s4),
                            ],
                            Flexible(child: Text(p.name, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.medium))),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(p.unit.isEmpty ? '-' : p.unit, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint))),
                      Expanded(flex: 2, child: Text('${p.opening}', style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 2, child: Text('${p.added}', style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(
                        flex: 2,
                        child: Tooltip(
                          message: p.adjustmentDetail ?? '',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.adjustment == 0 ? '-' : '${p.adjustment > 0 ? '+' : ''}${p.adjustment}',
                                style: TextStyle(
                                    fontSize: AppFontSize.f13,
                                    color: p.adjustment == 0 ? null : context.colors.warningStrong,
                                    fontWeight: p.adjustment == 0 ? AppFontWeight.regular : AppFontWeight.semibold),
                              ),
                              if (p.adjustmentDetail != null) ...[
                                const SizedBox(width: AppSpacing.s3),
                                Icon(Icons.info_outline, size: AppIconSize.i12, color: context.colors.textHint),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: Text('${p.sold}', style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 3, child: Text('${p.expectedClosing}', style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
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
            const SizedBox(height: AppSpacing.s4),
            Text('Watch-listed products only.', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.medium))),
              Expanded(flex: 2, child: Text('${p.expectedClosing}', style: const TextStyle(fontSize: AppFontSize.f13))),
              Expanded(flex: 2, child: Text('${p.physicalCount ?? '-'}', style: const TextStyle(fontSize: AppFontSize.f13))),
              Expanded(
                flex: 2,
                child: Text(hasVariance ? '${variance > 0 ? '+' : ''}$variance' : '0',
                    style: TextStyle(fontSize: AppFontSize.f13, color: hasVariance ? context.colors.dangerStrong : context.colors.textPrimary, fontWeight: AppFontWeight.semibold)),
              ),
              Expanded(
                flex: 2,
                child: hasVariance
                    ? Row(children: [Icon(Icons.warning_amber_rounded, size: AppIconSize.i14, color: context.colors.dangerStrong), const SizedBox(width: AppSpacing.s3), Text('Variance', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.dangerStrong))])
                    : Row(children: [Icon(Icons.check_circle_outline, size: AppIconSize.i14, color: context.colors.success), const SizedBox(width: AppSpacing.s3), Text('Match', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.successStrong))]),
              ),
            ],
          ),
          if (hasVariance && (p.varianceReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text('Reason: ${p.varianceReason}', style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted, fontStyle: FontStyle.italic)),
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
            const SizedBox(height: AppSpacing.s10),
            _statRow('New debt today', Money.symbolDecimal(report.newDebtValue)),
            _statRow('Repayments collected', Money.symbolDecimal(report.repaymentsValue)),
            _statRow('Outstanding change', Money.symbolDecimal(report.outstandingChange), bold: true),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.receipt_long_outlined, 'By Customer'),
            const SizedBox(height: AppSpacing.s8),
            if (report.clientDebtEntries.isEmpty)
              _emptyState('No debt activity today.')
            else ...[
              _tableHeaderRow(['Customer', 'Opening', 'New Debt', 'Repayment', 'Closing'], [3, 2, 2, 2, 2]),
              const Divider(height: 1),
              for (final c in report.clientDebtEntries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(c.clientName, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.medium))),
                      Expanded(flex: 2, child: Text(Money.decimal(c.openingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.decimal(c.newDebt), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.decimal(c.repayment), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.decimal(c.closingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
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
            const SizedBox(height: AppSpacing.s8),
            if (report.expenseLineItems.isEmpty)
              _emptyState('No expenses recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Description', 'Category', 'Amount'], [2, 4, 3, 2]),
              const Divider(height: 1),
              for (final e in report.expenseLineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppDateFormat.time24.format(e.time), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 4, child: Text(e.description, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 3, child: Text(e.category, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.decimal(e.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow('Total Expenses', Money.symbolDecimal(report.totalExpenses), bold: true),
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
            const SizedBox(height: AppSpacing.s4),
            Text('Income and expenses recorded directly, separate from sales and service revenue.',
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (combined.isEmpty)
              _emptyState('No transactions recorded today.')
            else ...[
              _tableHeaderRow(['Time', 'Description', 'Category', 'Type', 'Amount'], [2, 3, 2, 2, 2]),
              const Divider(height: 1),
              for (final entry in combined)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppDateFormat.time24.format(entry.item.time), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 3, child: Text(entry.item.description, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(entry.item.category, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(
                        flex: 2,
                        child: Text(entry.isExpense ? 'Expense' : 'Other Income',
                            style: TextStyle(fontSize: AppFontSize.f12, color: entry.isExpense ? context.colors.dangerStrong : context.colors.successStrong)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${entry.isExpense ? '-' : '+'}${Money.decimal(entry.item.amount)}',
                            style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold, color: entry.isExpense ? context.colors.dangerStrong : context.colors.successStrong)),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow('Other Income', Money.symbolDecimal(report.totalOtherIncome)),
              _statRow('Expenses', Money.symbolDecimal(report.totalExpenses), bold: true),
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
      case 'transactions':
        return Icons.receipt_long;
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
        return context.colors.info;
      case 'products':
        return context.colors.success;
      case 'sales':
        return context.colors.accent;
      case 'services':
        return Colors.purple;
      case 'transactions':
        return Colors.indigo;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return context.colors.warning;
      case 'settings':
        return context.colors.textHint;
      case 'admin':
        return context.colors.danger;
      default:
        return context.colors.primary;
    }
  }

  Widget _buildActivityLogTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.history, 'Activity Log'),
            const SizedBox(height: AppSpacing.s4),
            Text('Everything recorded today, in order.', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (!report.activityLogIncluded)
              _emptyState('Not included - this draft was generated by an assistant, who can only see their own '
                  'activity. Delete the draft and generate it again for the full log.')
            else if (report.activityLogEntries.isEmpty)
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(AppDateFormat.time24.format(entry.time), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_activityIcon(entry.actionType), size: AppIconSize.i14, color: color),
                const SizedBox(width: AppSpacing.s6),
                Flexible(child: Text(entry.actionType, style: TextStyle(fontSize: AppFontSize.f12, color: color), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 4, child: Text(entry.description, style: const TextStyle(fontSize: AppFontSize.f12_5))),
          Expanded(flex: 2, child: Text(entry.userName, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted))),
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
    for (final entry in report.repaymentsByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in report.otherIncomeByPaymentMethod.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    final combinedTotal = combined.values.fold(0.0, (sum, v) => sum + v);

    Widget categoryCard(IconData icon, String title, Map<String, double> byMethod, String emptyText) {
      return Expanded(
        child: _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(icon, title),
              const SizedBox(height: AppSpacing.s10),
              if (byMethod.isEmpty)
                _emptyState(emptyText)
              else
                for (final entry in byMethod.entries)
                  _statRow(entry.key, Money.symbolDecimal(entry.value)),
            ],
          ),
        ),
      );
    }

    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.credit_card_outlined, 'Combined - All Payment Methods'),
            const SizedBox(height: AppSpacing.s4),
            Text('Sales, services, debt repayments, and other income together, by how it was actually received.',
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (combined.isEmpty)
              _emptyState('No payments recorded today.')
            else ...[
              for (final entry in combined.entries) _statRow(entry.key, Money.symbolDecimal(entry.value)),
              const Divider(height: 18),
              _statRow('Total', Money.symbolDecimal(combinedTotal), bold: true),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoryCard(Icons.shopping_cart_outlined, 'Sales', report.salesByPaymentMethod, 'No sales today.'),
            const SizedBox(width: AppSpacing.s16),
            categoryCard(Icons.medical_services_outlined, 'Services', report.servicesByPaymentMethod, 'No services today.'),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoryCard(Icons.people_alt_outlined, 'Debt Repayments', report.repaymentsByPaymentMethod, 'No repayments today.'),
            const SizedBox(width: AppSpacing.s16),
            categoryCard(Icons.savings_outlined, 'Other Income', report.otherIncomeByPaymentMethod, 'No other income today.'),
          ],
        ),
      ),
    ]);
  }
}
