import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../config/app_defaults.dart';
import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The dashboard's Sales & Revenue Overview card: the period's total
/// revenue, its trend, and sales, collections and services per day. The
/// series are null until they have loaded; [isLoading] is true during the
/// first load. [period] is the stored choice ('Last 7 days' or 'Last 30
/// days'), shown through [periodLabel]; the chart starts on [start] and
/// covers [days] days.
class SalesRevenueChart extends StatelessWidget {
  final List<double>? salesByDay;
  final List<double>? collectionsByDay;
  final List<double>? servicesByDay;
  final double? otherIncomeTotal;
  final double? previousTotal;
  final bool isLoading;
  final String period;
  final String Function(String) periodLabel;
  final ValueChanged<String> onPeriodChanged;
  final DateTime start;
  final int days;

  const SalesRevenueChart({
    super.key,
    required this.salesByDay,
    required this.collectionsByDay,
    required this.servicesByDay,
    required this.otherIncomeTotal,
    required this.previousTotal,
    required this.isLoading,
    required this.period,
    required this.periodLabel,
    required this.onPeriodChanged,
    required this.start,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final salesByDay = this.salesByDay;
    final collectionsByDay = this.collectionsByDay;
    final servicesByDay = this.servicesByDay;
    final hasData = salesByDay != null && collectionsByDay != null && servicesByDay != null;

    // Total Revenue = Sales + Services + Other Income - not just Sales
    // alone. Collections stays out of this figure deliberately: it's
    // debt being repaid, not new revenue coming in.
    final currentTotal = hasData
        ? salesByDay.fold<double>(0, (a, b) => a + b) +
            servicesByDay.fold<double>(0, (a, b) => a + b) +
            (otherIncomeTotal ?? 0.0)
        : 0.0;
    final previousTotal = this.previousTotal;
    double? trendPercent;
    if (previousTotal != null && previousTotal > 0) {
      trendPercent = ((currentTotal - previousTotal) / previousTotal) * 100;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, size: AppIconSize.i18, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Text(context.l10n.dashboard_salesRevenueOverview, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14_5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: period,
                    items: const ['Last 7 days', 'Last 30 days']
                        .map((p) => DropdownMenuItem(value: p, child: Text(periodLabel(p), style: const TextStyle(fontSize: AppFontSize.f13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) onPeriodChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
          if (!hasData && isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Money.format(currentTotal),
                        style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f22, color: context.colors.textPrimary)),
                    Text(context.l10n.reports_totalRevenue, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                  ],
                ),
                if (trendPercent != null) ...[
                  const SizedBox(width: AppSpacing.s12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: Row(
                      children: [
                        Icon(trendPercent >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            size: AppIconSize.i14, color: trendPercent >= 0 ? context.colors.success : context.colors.danger),
                        Text(context.l10n.dashboard_vsLastPeriod(trendPercent.abs().toStringAsFixed(1)),
                            style: TextStyle(
                                fontSize: AppFontSize.f12,
                                fontWeight: AppFontWeight.semibold,
                                color: trendPercent >= 0 ? context.colors.success : context.colors.danger)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              height: 220,
              child: !hasData || (salesByDay.every((v) => v == 0) && collectionsByDay.every((v) => v == 0))
                  ? Center(child: Text(context.l10n.dashboard_noActivityInPeriod, style: TextStyle(color: context.colors.textMuted)))
                  : LineChart(
                      LineChartData(
                        // None of these three (sales, collections,
                        // services) are ever actually negative - this
                        // is the floor that keeps the curve/shaded
                        // area from visually dipping below the zero
                        // line at all, on top of
                        // preventCurveOverShooting below (which stops
                        // the smoothing itself from overshooting past
                        // a point, the more common cause of the dip -
                        // a sharp rise immediately followed by a steep
                        // drop, where the curve swings past the lower
                        // point before coming back up to the next
                        // one).
                        minY: 0,
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: true, border: Border.all(color: context.colors.border)),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final day = start.add(Duration(days: spot.x.toInt()));
                                final label = switch (spot.barIndex) {
                                  0 => context.l10n.dashboard_sales,
                                  1 => context.l10n.dashboard_collections,
                                  _ => context.l10n.dashboard_services,
                                };
                                return LineTooltipItem(
                                  '${AppDateFormat.dateShort.format(day)}\n${context.l10n.common_filterValue(label, Money.format(spot.y))}',
                                  TextStyle(color: context.colors.onChartTooltip, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) =>
                                  Text(Money.format(value), style: const TextStyle(fontSize: AppFontSize.f9)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: days > 7 ? 5 : 1,
                              getTitlesWidget: (value, meta) {
                                final day = start.add(Duration(days: value.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                                  child: Text(AppDateFormat.dateShort.format(day), style: const TextStyle(fontSize: AppFontSize.f9)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (int i = 0; i < salesByDay.length; i++) FlSpot(i.toDouble(), salesByDay[i])],
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: context.colors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: context.colors.primary.withValues(alpha: AppAlpha.a10)),
                          ),
                          LineChartBarData(
                            spots: [for (int i = 0; i < collectionsByDay.length; i++) FlSpot(i.toDouble(), collectionsByDay[i])],
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: context.colors.accent,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: context.colors.accent.withValues(alpha: AppAlpha.a10)),
                          ),
                          LineChartBarData(
                            spots: [for (int i = 0; i < servicesByDay.length; i++) FlSpot(i.toDouble(), servicesByDay[i])],
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: context.colors.chartService1,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: context.colors.chartService1.withValues(alpha: AppAlpha.a10)),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                _legendItem(context, context.colors.primary,
                    context.l10n.dashboard_seriesWithCurrency(context.l10n.dashboard_sales, AppDefaults.currencySymbol)),
                const SizedBox(width: AppSpacing.s20),
                _legendItem(context, context.colors.accent,
                    context.l10n.dashboard_seriesWithCurrency(context.l10n.dashboard_collections, AppDefaults.currencySymbol)),
                const SizedBox(width: AppSpacing.s20),
                _legendItem(context, context.colors.chartService1,
                    context.l10n.dashboard_seriesWithCurrency(context.l10n.dashboard_services, AppDefaults.currencySymbol)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AppSpacing.s6),
        Text(label, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft)),
      ],
    );
  }
}
