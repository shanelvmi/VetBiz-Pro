import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'dashboard_figures.dart';

/// The one Today card: Sales large, the period chip, then Collected, Owed and
/// (admins only, as the Net Profit card's masking today) Net profit.
class TodayCard extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAllDetails;

  const TodayCard({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onAllDetails,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    String money(double v) => figures.loading ? '—' : Money.format(v);
    final stats = [
      (l10n.sales_collected, money(figures.collected)),
      (l10n.home_owed, Money.format(figures.owed)),
      if (isAdmin) (l10n.home_netProfit, money(figures.netProfit)),
    ];
    return Container(
      padding: const EdgeInsets.all(PhoneHomeMetrics.cardPadding),
      decoration: BoxDecoration(
        color: colors.brandSurface,
        borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.nav_sales,
                  style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.onBrandSurfaceMuted),
                ),
              ),
              _PeriodChip(period: period, onChanged: onPeriodChanged),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(figures.sales),
              style: TextStyle(
                fontSize: PhoneHomeMetrics.salesValue,
                fontWeight: AppFontWeight.bold,
                color: colors.onBrandSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: PhoneHomeMetrics.statGap),
                Expanded(child: _Stat(label: stats[i].$1, value: stats[i].$2)),
              ],
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAllDetails,
              style: TextButton.styleFrom(
                foregroundColor: colors.onBrandSurface,
                minimumSize: const Size(PhoneHomeMetrics.linkHeight, PhoneHomeMetrics.linkHeight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.home_allDetails, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                  const Icon(Icons.chevron_right, size: PhoneHomeMetrics.rowIcon),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurfaceMuted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: PhoneHomeMetrics.statValue,
                fontWeight: AppFontWeight.bold,
                color: colors.onBrandSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The date chip: today's period picker (Today, This Week, This Month, This
/// Year), 36 high in a 48 target.
class _PeriodChip extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const _PeriodChip({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return PopupMenuButton<String>(
      tooltip: l10n.dashboard_changePeriod,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final p in dashboardPeriods) PopupMenuItem(value: p, child: Text(dashboardPeriodLabel(l10n, p))),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.linkHeight),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: PhoneHomeMetrics.chipHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            decoration: BoxDecoration(
              color: colors.onBrandSurface.withValues(alpha: PhoneHomeMetrics.circleAlpha),
              borderRadius: BorderRadius.circular(PhoneHomeMetrics.chipHeight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: PhoneHomeMetrics.chipIcon, color: colors.onBrandSurface),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  dashboardPeriodLabel(l10n, period),
                  style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.onBrandSurface),
                ),
                Icon(Icons.arrow_drop_down, size: PhoneHomeMetrics.rowIcon, color: colors.onBrandSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

