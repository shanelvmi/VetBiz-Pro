import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_date_format.dart';
import '../../config/app_ranges.dart';
import '../../config/money.dart';
import '../../data/home_chart_range.dart';
import '../../l10n/l10n.dart';
import '../../services/home_chart_data.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../utils/app_clock.dart';
import '../../widgets/reveal/reveal.dart';
import 'home_chart_page.dart';

/// HUB4 (1): the Sales page: the period's sales as a line (barely smoothed,
/// so it cannot invent a hill between a day with sales and one without), a
/// soft area under it and a marker on each day with a value; the period
/// before as a thin dashed line; three faint dotted guides (0, half and a
/// clean top) labelled in a left column; the days under the plot (a week's
/// initials, every 5th date of 30 days). A tap or a press on a day shows its
/// date and amount. While [hidden], the shape and the guides only: no
/// labels, no tooltip, a summary without amounts. Every value zero: the
/// guides and days, one muted line and, when given, Record a sale.
class HomeChartSalesPage extends StatefulWidget {
  final Future<HomeChartDays> future;
  final HomeChartRange range;

  /// Today's live sales (the card's Today total); null keeps the read's.
  final double? today;
  final bool hidden;

  /// Record a sale on the empty page (null: not offered to this person).
  final VoidCallback? onRecordSale;

  const HomeChartSalesPage({
    super.key,
    required this.future,
    required this.range,
    required this.hidden,
    this.today,
    this.onRecordSale,
  });

  @override
  State<HomeChartSalesPage> createState() => _HomeChartSalesPageState();
}

class _HomeChartSalesPageState extends State<HomeChartSalesPage> {
  HomeChartDays? _days;
  bool _answered = false;

  // The day whose exact amount is shown (a tap or a press), or none.
  int? _shown;
  double _plotLeft = 0;
  double _plotWidth = 1;

  @override
  void initState() {
    super.initState();
    widget.future.then(
      (d) {
        if (mounted) {
          setState(() {
            _days = d;
            _answered = true;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _answered = true);
      },
    );
  }

  HomeChartDays? get _live => _days?.withToday(sales: widget.today);

  int _dayAt(Offset local, int span) =>
      ((local.dx - _plotLeft) / _plotWidth * (span - 1)).round().clamp(0, span - 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final span = widget.range.days;
    final days = _live;
    final values = days?.currentSales ?? List<double>.filled(span, 0);
    final empty = values.every((v) => v == 0);
    final total = values.fold<double>(0, (a, b) => a + b);
    final best = empty ? 0 : values.indexOf(values.reduce(math.max));
    final summary = widget.hidden || days == null || empty
        ? l10n.home_chartSalesSummaryHidden(span)
        : l10n.home_chartSalesSummary(span, Money.format(total), AppDateFormat.dateShort.format(days.currentDays[best]));
    final body = LateSlot(
      ready: _answered,
      child: empty
          ? HomeChartEmpty(
              message: l10n.home_chartNoSales(span),
              action: widget.onRecordSale == null ? null : l10n.home_chartRecordSale,
              onAction: widget.onRecordSale,
              behind: ExcludeSemantics(child: _chart(context, null, values, span)),
            )
          : ExcludeSemantics(child: _touchable(context, days!, values, span)),
    );
    // UI7: the legend sits in the header and names the period there.
    return HomeChartPage(
      title: l10n.dashboard_sales,
      period: span == HomeChartRange.month.days ? l10n.services_last30 : l10n.services_last7,
      previous: l10n.home_chartPreviousDays(span),
      legend: !empty,
      summary: summary,
      body: body,
    );
  }

  Widget _touchable(BuildContext context, HomeChartDays days, List<double> values, int span) {
    if (widget.hidden) return _chart(context, days, values, span);
    return LayoutBuilder(
      builder: (context, box) {
        _plotLeft = HomeChartMetrics.axisReserved;
        _plotWidth = math.max(1, box.maxWidth - _plotLeft);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final i = _dayAt(d.localPosition, span);
            setState(() => _shown = _shown == i ? null : i);
          },
          onLongPressStart: (d) => setState(() => _shown = _dayAt(d.localPosition, span)),
          onLongPressMoveUpdate: (d) => setState(() => _shown = _dayAt(d.localPosition, span)),
          onLongPressEnd: (_) => setState(() => _shown = null),
          child: _chart(context, days, values, span),
        );
      },
    );
  }

  /// [days] null: the empty page's faint frame (guides and days only).
  Widget _chart(BuildContext context, HomeChartDays? days, List<double> values, int span) {
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final previous = days?.previousSales ?? const <double>[];
    final top = homeChartNiceMax([...values, ...previous].reduce(math.max));
    final labels = days != null && !widget.hidden;
    final dates = days?.currentDays ??
        [for (var i = 0; i < span; i++) DateUtils.dateOnly(AppClock.now()).subtract(AppRanges.day * (span - 1 - i))];
    final axis = TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted);
    List<FlSpot> spots(List<double> v) => [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])];
    final current = LineChartBarData(
      show: days != null,
      spots: spots(values),
      isCurved: true,
      curveSmoothness: HomeChartMetrics.curveSmoothness,
      preventCurveOverShooting: true,
      color: colors.primary,
      barWidth: HomeChartMetrics.line,
      dotData: FlDotData(
        checkToShowDot: (spot, _) => spot.y > 0,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: HomeChartMetrics.marker,
          color: colors.primary,
          strokeWidth: HomeChartMetrics.guideLine,
          strokeColor: colors.surface,
        ),
      ),
      belowBarData: BarAreaData(show: true, color: colors.primary.withValues(alpha: HomeChartMetrics.areaAlpha)),
    );
    final bars = [
      if (previous.isNotEmpty)
        LineChartBarData(
          spots: spots(previous),
          isCurved: true,
          curveSmoothness: HomeChartMetrics.curveSmoothness,
          preventCurveOverShooting: true,
          color: colors.textMuted,
          barWidth: HomeChartMetrics.previousLine,
          dashArray: HomeChartMetrics.dash,
          dotData: const FlDotData(show: false),
        ),
      current,
    ];
    final shown = _shown;
    return Padding(
      // Room for the top guide's label, so it never reaches the header.
      padding: const EdgeInsets.only(top: HomeChartMetrics.titleGap),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (span - 1).toDouble(),
          minY: 0,
          maxY: top,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            for (final y in homeChartGuides(top))
              HorizontalLine(
                y: y,
                color: colors.border,
                strokeWidth: HomeChartMetrics.guideLine,
                dashArray: HomeChartMetrics.guideDash,
              ),
          ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels,
                reservedSize: HomeChartMetrics.axisReserved,
                interval: top / 2,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(Money.axis(value), key: ValueKey('home-chart-guide-${value.round()}'), style: axis),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: HomeChartMetrics.dayLabels,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= span || value != i || !homeChartDayLabelled(i, span)) return const SizedBox.shrink();
                  final text = span <= HomeChartMetrics.weekDays
                      ? DateFormat(AppDateFormat.weekdayInitialPattern, locale).format(dates[i])
                      : DateFormat(AppDateFormat.dayPattern, locale).format(dates[i]);
                  return SideTitleWidget(axisSide: meta.axisSide, space: 0, child: Text(text, style: axis));
                },
              ),
            ),
          ),
          lineBarsData: bars,
          showingTooltipIndicators: [
            if (shown != null && labels && shown < span)
              ShowingTooltipIndicators([LineBarSpot(current, bars.length - 1, current.spots[shown])]),
          ],
          lineTouchData: LineTouchData(
            enabled: false,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${AppDateFormat.dateShort.format(dates[s.x.toInt()])}\n${Money.format(s.y)}',
                    TextStyle(
                      color: colors.onChartTooltip,
                      fontWeight: AppFontWeight.bold,
                      fontSize: HomeChartMetrics.axisLabel,
                    ),
                  ),
              ],
            ),
          ),
        ),
        duration: Duration.zero,
      ),
    );
  }
}
