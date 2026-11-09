import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../services/dashboard_summary_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'hub_destinations.dart' show HubTile;
import 'phone_home.dart';

/// The screen a row opens. Today's cards open nothing, so each row opens the
/// list its figure comes from.
enum DetailsTarget { products, sales, payments, reports, transactions, debtors, clients, services }

/// Everything the eight dashboard cards show, as one value.
class AllDetailsFigures {
  final DashboardPeriodTotals totals;
  final double productValue;
  final double outstanding;
  final int clients;
  final bool loading;

  const AllDetailsFigures({
    required this.totals,
    required this.productValue,
    required this.outstanding,
    required this.clients,
    this.loading = false,
  });
}

/// One row: label left, value right; Net Profit adds Earned and Pending.
class DetailRow {
  final String label;
  final String value;
  final DetailsTarget target;
  final (String, String)? earned;
  final (String, String)? pending;

  const DetailRow(this.label, this.value, this.target, {this.earned, this.pending});
}

/// The eight cards as rows, with today's titles and the cards' role rule: an
/// assistant's Net Profit is masked, with no Earned and Pending (the card
/// masks the figure, its trend and its breakdown), and Total Expenses is
/// left out (PH4b, dashboardShowsFigure); every other row is shown to both
/// roles, as the cards are.
List<DetailRow> allDetailRows(AppLocalizations l, AllDetailsFigures f, {required bool isAdmin, required String period}) {
  final label = dashboardPeriodLabel(l, period);
  final t = f.totals;
  return [
    DetailRow(l.dashboard_totalProductValue, Money.format(f.productValue), DetailsTarget.products),
    DetailRow(l.dashboard_totalSales(label), Money.format(t.totalSales), DetailsTarget.sales),
    DetailRow(l.dashboard_totalCollected(label), Money.format(t.totalCollected), DetailsTarget.payments),
    isAdmin
        ? DetailRow(
            l.dashboard_netProfit(label),
            Money.format(t.netProfit),
            DetailsTarget.reports,
            earned: (l.dashboard_profitEarned, Money.format(t.totalRealizedProfit)),
            pending: (l.dashboard_profitPending, Money.format(t.totalUnrealizedProfit)),
          )
        : DetailRow(l.dashboard_netProfit(label), '*****', DetailsTarget.reports),
    if (dashboardShowsFigure(DashboardFigure.expenses, isAdmin: isAdmin))
      DetailRow(l.dashboard_totalExpenses(label), Money.format(t.totalExpenses), DetailsTarget.transactions),
    DetailRow(l.dashboard_outstandingPayment, Money.format(f.outstanding), DetailsTarget.debtors),
    DetailRow(l.clients_total, '${f.clients}', DetailsTarget.clients),
    DetailRow(l.dashboard_completedServices(label), '${t.completedServicesCount}', DetailsTarget.services),
  ];
}

/// The place a row opens (HUB1: as the action panel opens it). Every one is in
/// both roles' panel.
HubTile detailsTargetPlace(DetailsTarget target) => switch (target) {
      DetailsTarget.products => HubTile.products,
      DetailsTarget.sales => HubTile.sales,
      DetailsTarget.payments => HubTile.payments,
      DetailsTarget.reports => HubTile.reports,
      DetailsTarget.transactions => HubTile.transactions,
      DetailsTarget.debtors => HubTile.debtors,
      DetailsTarget.clients => HubTile.clients,
      DetailsTarget.services => HubTile.services,
    };

/// PH4 (phone_shell.md D4): All details, a full page over Home. The
/// period chip, the eight figures as a full-width list (titles wrap, never
/// truncate), then the chart and Recent Activity as the dashboard shows them.
///
/// The page is a pushed route, so it does not rebuild with the dashboard:
/// it rebuilds on [changes] (the dashboard's own state changes) and reads
/// the figures afresh through the getters each time.
class AllDetailsScreen extends StatelessWidget {
  final Listenable changes;
  final AllDetailsFigures Function() figures;
  final bool Function() isAdmin;
  final String Function() period;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<DetailsTarget> onOpen;
  final WidgetBuilder chart;
  final WidgetBuilder feed;

  const AllDetailsScreen({
    super.key,
    required this.changes,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onOpen,
    required this.chart,
    required this.feed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: AppElevation.e1,
        title: Text(l10n.home_allDetails, style: const TextStyle(fontWeight: AppFontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: changes,
        builder: (context, _) {
          final f = figures();
          final rows = allDetailRows(l10n, f, isAdmin: isAdmin(), period: period());
          return ListView(
            padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: l10n.dashboard_changePeriod,
                  onSelected: onPeriodChanged,
                  itemBuilder: (context) => [
                    for (final p in dashboardPeriods)
                      PopupMenuItem(value: p, child: Text(dashboardPeriodLabel(l10n, p))),
                  ],
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.linkHeight),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: PhoneHomeMetrics.chipIcon, color: colors.primary),
                        const SizedBox(width: AppSpacing.s6),
                        Text(
                          dashboardPeriodLabel(l10n, period()),
                          style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.primary),
                        ),
                        Icon(Icons.arrow_drop_down, color: colors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.borderStrong.withValues(alpha: PhoneHomeMetrics.circleAlpha)),
                      _DetailRowTile(row: rows[i], loading: f.loading, onTap: () => onOpen(rows[i].target)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: PhoneHomeMetrics.sectionGap),
              chart(context),
              const SizedBox(height: PhoneHomeMetrics.sectionGap),
              feed(context),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRowTile extends StatelessWidget {
  final DetailRow row;
  final bool loading;
  final VoidCallback onTap;

  const _DetailRowTile({required this.row, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.textMuted);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding, vertical: AppSpacing.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(row.label, style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.textPrimary)),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(
                      loading ? '—' : row.value,
                      style: TextStyle(
                        fontSize: PhoneHomeMetrics.rowValue,
                        fontWeight: AppFontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (row.earned != null && row.pending != null && !loading)
                  Wrap(
                    spacing: AppSpacing.s12,
                    children: [
                      Text('${row.earned!.$1}  ${row.earned!.$2}', style: small),
                      Text('${row.pending!.$1}  ${row.pending!.$2}', style: small),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
