import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/user_role_provider.dart';
import '../../config/money.dart';
import '../../config/payment_methods.dart';
import '../../config/app_date_format.dart';
import '../../theme/activity_type_style.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../l10n/l10n.dart';
import 'report_activity_log_loader.dart';

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

  // The English names are the values (compared below); _tabLabel is what
  // the tab shows.
  String _tabLabel(String tab) => switch (tab) {
        'Summary' => context.l10n.common_summary,
        'Sales' => context.l10n.payments_typeSales,
        'Services' => context.l10n.payments_typeServices,
        'Products' => context.l10n.reports_tabProducts,
        'Stock Reconciliation' => context.l10n.reports_tabStock,
        'Debt' => context.l10n.reports_tabDebt,
        'Expenses' => context.l10n.transactions_expenses,
        'Transactions' => context.l10n.transactions_title,
        'Activity Log' => context.l10n.export_activityLog,
        'Payment Methods' => context.l10n.reports_paymentMethods,
        _ => tab,
      };

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
            tabs: _tabTitles.map((t) => Tab(text: _tabLabel(t))).toList(),
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
      _summaryTile(context.l10n.reports_totalSales, Money.format(report.salesTotalValue), Icons.shopping_cart_outlined, context.colors.info),
      _summaryTile(context.l10n.reports_serviceRevenue, Money.format(report.servicesTotalValue), Icons.medical_services_outlined, context.colors.success),
      _summaryTile(context.l10n.payments_typeDebtRepayments, Money.format(report.repaymentsValue), Icons.people_alt_outlined, context.colors.chart4),
      _summaryTile(context.l10n.transactions_expenses, Money.format(report.totalExpenses), Icons.receipt_long_outlined, context.colors.danger),
      _summaryTile(context.l10n.payments_typeOtherIncome, Money.format(report.totalOtherIncome), Icons.savings_outlined, context.colors.primary),
    ];
    final row2 = [
      _summaryTile(context.l10n.reports_outstandingNewDebt, Money.format(report.newDebtValue), Icons.warning_amber_outlined, context.colors.warning),
      _summaryTile(context.l10n.transactions_title, '$transactionsCount', Icons.sync_alt_outlined, context.colors.chart5),
      _summaryTile(context.l10n.reports_servicesPerformed, '${report.servicesCount}', Icons.build_outlined, context.colors.chart6),
      _summaryTile(context.l10n.reports_productsSold, context.l10n.reports_unitsCount(productsSoldUnits), Icons.inventory_2_outlined, context.colors.accent.withValues(alpha: AppAlpha.a85)),
      _summaryTile(context.l10n.reports_totalRevenueToday, Money.format(revenue), Icons.trending_up_outlined, context.colors.primary),
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
                _sectionHeader(Icons.dashboard_outlined, context.l10n.reports_dailySummary),
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
          Text(context.l10n.reports_generatedAtBy(AppDateFormat.dateNoPadTime12Short.format(report.generatedAt), report.generatedByName),
              style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
          if (report.submittedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(context.l10n.reports_submittedAt(AppDateFormat.dateNoPadTime12Short.format(report.submittedAt!)),
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
                child: Text(context.l10n.subscription_viewAll, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
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
      title: context.l10n.payments_typeSales,
      onViewAll: () => _goToTab(_salesTabIndex),
      content: preview.isEmpty
          ? _emptyState(context.l10n.reports_noSalesToday)
          : Column(
              children: [
                for (final s in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.customerName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.format(s.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
      title: context.l10n.reports_vetServices,
      onViewAll: () => _goToTab(_servicesTabIndex),
      content: preview.isEmpty
          ? _emptyState(context.l10n.reports_noServicesToday)
          : Column(
              children: [
                for (final s in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(s.serviceName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.format(s.revenue), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
      title: context.l10n.reports_productMovement,
      onViewAll: () => _goToTab(_productsTabIndex),
      content: preview.isEmpty
          ? _emptyState(context.l10n.reports_noMovementToday)
          : Column(
              children: [
                for (final p in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(context.l10n.reports_soldCount(p.sold), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
      title: context.l10n.reports_debtActivity,
      onViewAll: () => _goToTab(_debtTabIndex),
      content: preview.isEmpty
          ? _emptyState(context.l10n.reports_noDebtActivity)
          : Column(
              children: [
                for (final c in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(c.clientName, style: const TextStyle(fontSize: AppFontSize.f12_5), overflow: TextOverflow.ellipsis)),
                        Text(Money.format(c.closingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
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
            _sectionHeader(Icons.shopping_cart_outlined, context.l10n.payments_typeSales),
            const SizedBox(height: AppSpacing.s8),
            if (report.salesLineItems.isEmpty)
              _emptyState(context.l10n.reports_noSalesToday)
            else ...[
              _tableHeaderRow([
                context.l10n.reports_colTime,
                context.l10n.reports_colReceipt,
                context.l10n.receipt_customer,
                context.l10n.reports_colItems,
                context.l10n.common_amount,
                context.l10n.reports_colPayment,
              ], [2, 2, 3, 1, 2, 2]),
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
                      Expanded(flex: 2, child: Text(Money.plain(s.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
                      Expanded(flex: 2, child: Text(context.l10n.paymentMethodLabel(s.paymentMethod), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow(context.l10n.reports_totalSales, Money.format(report.salesTotalValue), bold: true),
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
              _sectionHeader(Icons.credit_card_outlined, context.l10n.reports_paymentMethods),
              const SizedBox(height: AppSpacing.s8),
              for (final e in PaymentMethod.mergeShown(report.salesByPaymentMethod).entries)
                _statRow(context.l10n.paymentMethodLabel(e.key), Money.format(e.value)),
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
            _sectionHeader(Icons.medical_services_outlined, context.l10n.reports_vetServices),
            const SizedBox(height: AppSpacing.s8),
            if (report.serviceBreakdown.isEmpty)
              _emptyState(context.l10n.reports_noServicesToday)
            else ...[
              _tableHeaderRow([context.l10n.reports_colService, context.l10n.reports_colNumber, context.l10n.reports_colRevenue], [4, 2, 2]),
              const Divider(height: 1),
              for (final s in report.serviceBreakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text(s.serviceName, style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 2, child: Text('${s.count}', style: const TextStyle(fontSize: AppFontSize.f13))),
                      Expanded(flex: 2, child: Text(Money.format(s.revenue), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow(context.l10n.reports_totalServiceRevenue, Money.format(report.servicesTotalValue), bold: true),
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
              _sectionHeader(Icons.credit_card_outlined, context.l10n.reports_paymentMethods),
              const SizedBox(height: AppSpacing.s8),
              for (final e in PaymentMethod.mergeShown(report.servicesByPaymentMethod).entries)
                _statRow(context.l10n.paymentMethodLabel(e.key), Money.format(e.value)),
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
            _sectionHeader(Icons.inventory_2_outlined, context.l10n.reports_productMovement),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.reports_systemTracked,
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (report.productMovement.isEmpty)
              _emptyState(context.l10n.reports_noMovementToday)
            else ...[
              _tableHeaderRow([
                context.l10n.reports_colProduct,
                context.l10n.reports_colUnit,
                context.l10n.reports_colOpening,
                context.l10n.reports_colAdded,
                context.l10n.reports_colAdjusted,
                context.l10n.reports_colSold,
                context.l10n.reports_colExpectedClosing,
              ], [4, 2, 2, 2, 2, 2, 3]),
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
              _statRow(context.l10n.reports_totalUnitsSold, '${report.productMovement.fold(0, (sum, p) => sum + p.sold)}', bold: true),
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
            _sectionHeader(Icons.fact_check_outlined, context.l10n.reports_expectedVsPhysical),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.reports_watchlistedOnly, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (watchlisted.isEmpty)
              _emptyState(context.l10n.reports_noWatchlisted)
            else if (!isSubmitted)
              _emptyState(context.l10n.reports_countsNotSubmitted)
            else ...[
              _tableHeaderRow([
                context.l10n.reports_colProduct,
                context.l10n.reports_colExpected,
                context.l10n.reports_colPhysical,
                context.l10n.reports_colDifference,
                context.l10n.common_status,
              ], [3, 2, 2, 2, 2]),
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
                    ? Row(children: [Icon(Icons.warning_amber_rounded, size: AppIconSize.i14, color: context.colors.dangerStrong), const SizedBox(width: AppSpacing.s3), Text(context.l10n.reports_variance, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.dangerStrong))])
                    : Row(children: [Icon(Icons.check_circle_outline, size: AppIconSize.i14, color: context.colors.success), const SizedBox(width: AppSpacing.s3), Text(context.l10n.reports_match, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.successStrong))]),
              ),
            ],
          ),
          if (hasVariance && (p.varianceReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(context.l10n.reports_reasonValue('${p.varianceReason}'), style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted, fontStyle: FontStyle.italic)),
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
            _sectionHeader(Icons.people_alt_outlined, context.l10n.reports_debtActivity),
            const SizedBox(height: AppSpacing.s10),
            _statRow(context.l10n.reports_newDebtTodayLower, Money.format(report.newDebtValue)),
            _statRow(context.l10n.reports_repaymentsCollected, Money.format(report.repaymentsValue)),
            _statRow(context.l10n.reports_outstandingChange, Money.format(report.outstandingChange), bold: true),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.receipt_long_outlined, context.l10n.reports_byCustomer),
            const SizedBox(height: AppSpacing.s8),
            if (report.clientDebtEntries.isEmpty)
              _emptyState(context.l10n.reports_noDebtActivity)
            else ...[
              _tableHeaderRow([
                context.l10n.receipt_customer,
                context.l10n.reports_colOpening,
                context.l10n.reports_colNewDebt,
                context.l10n.reports_colRepayment,
                context.l10n.reports_colClosing,
              ], [3, 2, 2, 2, 2]),
              const Divider(height: 1),
              for (final c in report.clientDebtEntries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(c.clientName, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.medium))),
                      Expanded(flex: 2, child: Text(Money.plain(c.openingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.plain(c.newDebt), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.plain(c.repayment), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.plain(c.closingDebt), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
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
            _sectionHeader(Icons.receipt_long_outlined, context.l10n.reports_expensesRecorded),
            const SizedBox(height: AppSpacing.s8),
            if (report.expenseLineItems.isEmpty)
              _emptyState(context.l10n.reports_noExpensesToday)
            else ...[
              _tableHeaderRow(
                  [context.l10n.reports_colTime, context.l10n.common_description, context.l10n.common_category, context.l10n.common_amount],
                  [2, 4, 3, 2]),
              const Divider(height: 1),
              for (final e in report.expenseLineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppDateFormat.time24.format(e.time), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 4, child: Text(e.description, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 3, child: Text(context.l10n.transactionCategoryLabel(e.category), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(Money.plain(e.amount), style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow(context.l10n.reports_totalExpenses, Money.format(report.totalExpenses), bold: true),
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
            _sectionHeader(Icons.sync_alt_outlined, context.l10n.reports_allTransactions),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.reports_transactionsNote,
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (combined.isEmpty)
              _emptyState(context.l10n.reports_noTransactionsToday)
            else ...[
              _tableHeaderRow([
                context.l10n.reports_colTime,
                context.l10n.common_description,
                context.l10n.common_category,
                context.l10n.common_type,
                context.l10n.common_amount,
              ], [2, 3, 2, 2, 2]),
              const Divider(height: 1),
              for (final entry in combined)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppDateFormat.time24.format(entry.item.time), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 3, child: Text(entry.item.description, style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(flex: 2, child: Text(context.l10n.transactionCategoryLabel(entry.item.category), style: const TextStyle(fontSize: AppFontSize.f12_5))),
                      Expanded(
                        flex: 2,
                        child: Text(entry.isExpense ? context.l10n.transactionType_expense : context.l10n.payments_typeOtherIncome,
                            style: TextStyle(fontSize: AppFontSize.f12, color: entry.isExpense ? context.colors.dangerStrong : context.colors.successStrong)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${entry.isExpense ? '-' : '+'}${Money.plain(entry.item.amount)}',
                            style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold, color: entry.isExpense ? context.colors.dangerStrong : context.colors.successStrong)),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              _statRow(context.l10n.payments_typeOtherIncome, Money.format(report.totalOtherIncome)),
              _statRow(context.l10n.transactions_expenses, Money.format(report.totalExpenses), bold: true),
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
  Widget _buildActivityLogTab() {
    return _tabScroll([
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.history, context.l10n.export_activityLog),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.reports_everythingToday, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (!report.activityLogIncluded)
              _emptyState(context.l10n.reports_activityNotIncluded)
            else
              // From the admin-only subdocument (E4c, a1); this tab is
              // built for admins only.
              ReportActivityLogLoader(
                report: report,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) return _emptyState(context.l10n.error_couldNotLoad);
                  final entries = snapshot.data;
                  if (entries == null) return _emptyState(context.l10n.reports_activityLogNotSaved);
                  if (entries.isEmpty) return _emptyState(context.l10n.reports_noActivityToday);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tableHeaderRow(
                          [context.l10n.reports_colTime, context.l10n.common_type, context.l10n.common_description, context.l10n.reports_colBy],
                          [1, 2, 4, 2]),
                      const Divider(height: 1),
                      for (final entry in entries) _buildActivityRow(entry),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildActivityRow(ActivityLogEntry entry) {
    final color = ActivityTypeStyle.color(entry.actionType, context.colors);
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
                Icon(ActivityTypeStyle.icon(entry.actionType), size: AppIconSize.i14, color: color),
                const SizedBox(width: AppSpacing.s6),
                Flexible(child: Text(context.l10n.activityTypeLabel(entry.actionType), style: TextStyle(fontSize: AppFontSize.f12, color: color), overflow: TextOverflow.ellipsis)),
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
    final combined = PaymentMethod.combineShown([
      report.salesByPaymentMethod,
      report.servicesByPaymentMethod,
      report.repaymentsByPaymentMethod,
      report.otherIncomeByPaymentMethod,
    ]);
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
                  _statRow(context.l10n.paymentMethodLabel(entry.key), Money.format(entry.value)),
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
            _sectionHeader(Icons.credit_card_outlined, context.l10n.reports_combinedAll),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.reports_combinedNote,
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s10),
            if (combined.isEmpty)
              _emptyState(context.l10n.reports_noPaymentsToday)
            else ...[
              for (final entry in combined.entries) _statRow(context.l10n.paymentMethodLabel(entry.key), Money.format(entry.value)),
              const Divider(height: 18),
              _statRow(context.l10n.common_total, Money.format(combinedTotal), bold: true),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoryCard(Icons.shopping_cart_outlined, context.l10n.payments_typeSales, PaymentMethod.mergeShown(report.salesByPaymentMethod),
                context.l10n.reports_noSalesShort),
            const SizedBox(width: AppSpacing.s16),
            categoryCard(Icons.medical_services_outlined, context.l10n.payments_typeServices, PaymentMethod.mergeShown(report.servicesByPaymentMethod),
                context.l10n.reports_noServicesShort),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoryCard(Icons.people_alt_outlined, context.l10n.payments_typeDebtRepayments, PaymentMethod.mergeShown(report.repaymentsByPaymentMethod),
                context.l10n.reports_noRepaymentsShort),
            const SizedBox(width: AppSpacing.s16),
            categoryCard(Icons.savings_outlined, context.l10n.payments_typeOtherIncome, PaymentMethod.mergeShown(report.otherIncomeByPaymentMethod),
                context.l10n.reports_noOtherIncomeShort),
          ],
        ),
      ),
    ]);
  }
}
