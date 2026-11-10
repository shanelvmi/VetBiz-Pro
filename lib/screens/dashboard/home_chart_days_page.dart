import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../services/home_chart_data.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/reveal/reveal.dart';
import 'home_chart_page.dart';

/// Amounts in tabular figures, so digits do not shift as they change.
const _tabular = [FontFeature.tabularFigures()];

/// Sales (a line, the previous week dashed) or Vet services (bars) over the
/// last 7 days, from the shared 14-day read.
class HomeChartDaysPage extends StatefulWidget {
  final Future<HomeChartDays> future;
  final String title;
  final bool legend;
  final bool bars;
  final double? today;
  final List<double> Function(HomeChartDays) pick;
  final List<double> Function(HomeChartDays)? previous;
  final bool hidden;
  final VoidCallback onOpen;

  const HomeChartDaysPage({
    super.key,
    required this.future,
    required this.title,
    required this.pick,
    required this.hidden,
    required this.onOpen,
    this.legend = false,
    this.bars = false,
    this.today,
    this.previous,
  });

  @override
  State<HomeChartDaysPage> createState() => _HomeChartDaysPageState();
}

class _HomeChartDaysPageState extends State<HomeChartDaysPage> {
  HomeChartDays? _days;
  bool _answered = false;

  // The day whose exact amount is shown (a long press), or none.
  int? _pressed;
  double _chartLeft = 0;
  double _chartWidth = 1;

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

  HomeChartDays? get _live =>
      _days?.withToday(sales: widget.legend ? widget.today : null, services: widget.bars ? widget.today : null);

  void _press(Offset local) {
    if (widget.hidden || _live == null) return;
    final x = local.dx - HomeChartMetrics.padding - _chartLeft;
    final i = (x / _chartWidth * HomeChartDays.week).floor().clamp(0, HomeChartDays.week - 1);
    if (i != _pressed) setState(() => _pressed = i);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final days = _live;
    final values = days == null ? const <double>[] : widget.pick(days);
    final empty = values.every((v) => v == 0);
    Widget? trailing;
    if (widget.legend) {
      trailing = _Legend(current: l10n.home_chartThisWeek, previous: l10n.home_chartLastWeek);
    } else if (!widget.hidden && days != null && !empty) {
      trailing = Text(
        Money.format(values.fold<double>(0, (a, b) => a + b)),
        key: const ValueKey('home-chart-total'),
        style: TextStyle(
          fontSize: HomeChartMetrics.title,
          fontWeight: AppFontWeight.semibold,
          fontFeatures: _tabular,
          color: colors.textPrimary,
        ),
      );
    }
    final body = LayoutBuilder(
      builder: (context, constraints) {
        _chartLeft = widget.hidden ? 0 : HomeChartMetrics.axisReserved;
        _chartWidth = math.max(1, constraints.maxWidth - _chartLeft);
        return LateSlot(
          ready: _answered,
          child:
              days == null || empty
                  ? const HomeChartEmpty()
                  : (widget.bars ? _bars(context, days, values) : _line(context, days, values)),
        );
      },
    );
    return HomeChartPage(
      title: widget.title,
      trailing: trailing,
      body: body,
      onOpen: widget.onOpen,
      onPressStart: widget.hidden ? null : (d) => _press(d.localPosition),
      onPressMove: widget.hidden ? null : (d) => _press(d.localPosition),
      onPressEnd: widget.hidden ? null : () => setState(() => _pressed = null),
    );
  }

  AxisTitles _guides(BuildContext context, double top) => AxisTitles(
    sideTitles: SideTitles(
      showTitles: !widget.hidden,
      reservedSize: HomeChartMetrics.axisReserved,
      interval: top / HomeChartMetrics.guideCount,
      getTitlesWidget:
          (value, meta) =>
              value == 0 || value > top
                  ? const SizedBox.shrink()
                  : Text(
                    Money.axis(value),
                    style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: context.colors.textMuted),
                  ),
    ),
  );

  FlTitlesData _titles(BuildContext context, double top) => FlTitlesData(
    leftTitles: _guides(context, top),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );

  String _tooltip(HomeChartDays days, int i, double value) =>
      '${AppDateFormat.dateShort.format(days.thisWeekDays[i])}\n${Money.format(value)}';

  TextStyle _tooltipStyle(BuildContext context) => TextStyle(
    color: context.colors.onChartTooltip,
    fontWeight: AppFontWeight.bold,
    fontSize: HomeChartMetrics.axisLabel,
  );

  Widget _line(BuildContext context, HomeChartDays days, List<double> values) {
    final colors = context.colors;
    final previous = widget.previous?.call(days) ?? const <double>[];
    final top = homeChartNiceMax([...values, ...previous].reduce(math.max));
    List<FlSpot> spots(List<double> v) => [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])];
    final current = LineChartBarData(
      spots: spots(values),
      isCurved: true,
      preventCurveOverShooting: true,
      color: colors.primary,
      barWidth: HomeChartMetrics.line,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: colors.primary.withValues(alpha: HomeChartMetrics.areaAlpha)),
    );
    final bars = [
      if (previous.isNotEmpty)
        LineChartBarData(
          spots: spots(previous),
          isCurved: true,
          preventCurveOverShooting: true,
          color: colors.textMuted,
          barWidth: HomeChartMetrics.previousLine,
          dashArray: HomeChartMetrics.dash,
          dotData: const FlDotData(show: false),
        ),
      current,
    ];
    final pressed = _pressed;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (HomeChartDays.week - 1).toDouble(),
        minY: 0,
        maxY: top,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: colors.border))),
        titlesData: _titles(context, top),
        lineBarsData: bars,
        showingTooltipIndicators: [
          if (pressed != null && !widget.hidden)
            ShowingTooltipIndicators([LineBarSpot(current, bars.length - 1, current.spots[pressed])]),
        ],
        lineTouchData: LineTouchData(
          enabled: false,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems:
                (spots) => [
                  for (final s in spots) LineTooltipItem(_tooltip(days, s.x.toInt(), s.y), _tooltipStyle(context)),
                ],
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }

  Widget _bars(BuildContext context, HomeChartDays days, List<double> values) {
    final colors = context.colors;
    final top = homeChartNiceMax(values.reduce(math.max));
    final pressed = _pressed;
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: colors.border))),
        titlesData: _titles(context, top),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: [if (i == pressed && !widget.hidden) 0],
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: colors.primary,
                  width: math.max(
                    HomeChartMetrics.barMinWidth,
                    _chartWidth / HomeChartDays.week * HomeChartMetrics.barFill,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(HomeChartMetrics.barRadius)),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem:
                (group, _, rod, __) => BarTooltipItem(_tooltip(days, group.x, rod.toY), _tooltipStyle(context)),
          ),
        ),
      ),
      swapAnimationDuration: Duration.zero,
    );
  }
}

/// "This week" (a solid swatch) and "Last week" (dashed), one small line.
class _Legend extends StatelessWidget {
  final String current;
  final String previous;

  const _Legend({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(Color color, String label, {required bool dashed}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: HomeChartMetrics.swatch,
          height: HomeChartMetrics.line,
          child:
              dashed
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 2; i++)
                        SizedBox(width: HomeChartMetrics.swatch / 3, child: ColoredBox(color: color)),
                    ],
                  )
                  : ColoredBox(color: color),
        ),
        const SizedBox(width: AppSpacing.s4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted),
          ),
        ),
      ],
    );
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: item(colors.primary, current, dashed: false)),
          const SizedBox(width: AppSpacing.s8),
          Flexible(child: item(colors.textMuted, previous, dashed: true)),
        ],
      ),
    );
  }
}
