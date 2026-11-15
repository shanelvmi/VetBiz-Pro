import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// One page: the surface card, ONE header row at its top (UI7: the title at
/// the left; at the right the period in the muted role or, on the Sales
/// page, its legend, which names the period, so it is never said twice),
/// then the page's [body]. HUB4: the page is one Semantics node whose label
/// is [summary] (the chart itself is not read out); its buttons and rows
/// stay their own nodes. A tap no longer opens Insights: the taps show a
/// day's amount, open a product or pick a slice (Insights stays in the panel).
class HomeChartPage extends StatelessWidget {
  final String title;
  final String period;
  final String summary;
  final Widget body;

  /// The Sales page's "Previous n days": its header is measured with the
  /// legend, so the header keeps its rows when the legend appears as the
  /// data arrives. [legend] false (loading, nothing sold): the period in
  /// the legend's place, as no line is drawn to explain.
  final String? previous;
  final bool legend;

  const HomeChartPage({
    super.key,
    required this.title,
    required this.period,
    required this.summary,
    required this.body,
    this.previous,
    this.legend = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeChartMetrics.pageInset),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeChartMetrics.radius),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          label: summary,
          child: Padding(
            padding: const EdgeInsets.all(HomeChartMetrics.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(child: _header(context)),
                const SizedBox(height: HomeChartMetrics.headerGap),
                // The smallest region: the titles only, nothing cut.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => box.maxHeight < HomeChartMetrics.bodyMin ? const SizedBox.shrink() : body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// UI7: the title and, beside it, the period or the legend. Measured with
  /// TextPainter (the text scale included): when they do not fit on one line
  /// (long Kiswahili, 30 days, larger text) the right-hand content takes a
  /// second row under the title, so the title is never cut and nothing
  /// overlaps. The right-hand content is [HomeChartMetrics.legendRow] high
  /// (scaled) whichever is drawn, so the header never changes height.
  /// Measured in the builder's context: under the page's Material, whose
  /// text style the texts take.
  Widget _header(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _headerIn(context, box.maxWidth));

  Widget _headerIn(BuildContext context, double maxWidth) {
    final colors = context.colors;
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = TextStyle(
      fontSize: HomeChartMetrics.title,
      fontWeight: AppFontWeight.semibold,
      color: colors.textPrimary,
    );
    final muted = TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final previous = this.previous;
    final endWidth = previous == null
        ? width(period, muted)
        : HomeChartLegend.widthOf(width(period, muted), width(previous, muted));
    // Too wide even for a row of its own (Kiswahili, 30 days, larger text
    // at 360): the legend's two entries one under the other, never cut.
    final stacked = endWidth > maxWidth;
    final end = SizedBox(
      height: scaler.scale(HomeChartMetrics.legendRow) * (stacked ? 2 : 1),
      child: previous != null && legend
          ? HomeChartLegend(current: period, previous: previous, stacked: stacked)
          : Text(
              period,
              key: const ValueKey('home-chart-period'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
    );
    final titleText = Text(
      title,
      key: const ValueKey('home-chart-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    if (width(title, titleStyle) + HomeChartMetrics.headerSpace + endWidth <= maxWidth) {
      return ConstrainedBox(
        key: const ValueKey('home-chart-header'),
        constraints: const BoxConstraints(minHeight: HomeChartMetrics.headerRow),
        child: Row(
          children: [
            titleText,
            const SizedBox(width: HomeChartMetrics.headerSpace),
            Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: end)),
          ],
        ),
      );
    }
    return Column(
      key: const ValueKey('home-chart-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HomeChartMetrics.headerRow),
          child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: titleText),
        ),
        end,
      ],
    );
  }
}

/// The Sales legend: [current] ("Last 7 days", a solid swatch) and
/// [previous] ("Previous 7 days", dashed, muted). UI7: in the page header;
/// [stacked]: the two entries one under the other.
class HomeChartLegend extends StatelessWidget {
  final String current;
  final String previous;
  final bool stacked;

  const HomeChartLegend({super.key, required this.current, required this.previous, this.stacked = false});

  /// Its width on one line, given its two texts' widths.
  static double widthOf(double current, double previous) =>
      2 * (HomeChartMetrics.legendSwatchWidth + AppSpacing.s4) + AppSpacing.s12 + current + previous;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(Color color, String label, {required bool dashed}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: ValueKey(dashed ? 'home-chart-legend-dashed' : 'home-chart-legend-solid'),
          width: HomeChartMetrics.legendSwatchWidth,
          height: HomeChartMetrics.legendSwatchHeight,
          // UI6: each dash has its own height; under the Row's loose height
          // a bare ColoredBox was drawn 0 px high and the dashes vanished.
          child: dashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < HomeChartMetrics.legendDashes; i++)
                      SizedBox(
                        key: ValueKey('home-chart-legend-dash-$i'),
                        width: HomeChartMetrics.legendDash,
                        height: HomeChartMetrics.legendSwatchHeight,
                        child: DecoratedBox(decoration: BoxDecoration(color: color)),
                      ),
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
    if (stacked) {
      return Column(
        key: const ValueKey('home-chart-legend'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: item(colors.primary, current, dashed: false)),
          Expanded(child: item(colors.textMuted, previous, dashed: true)),
        ],
      );
    }
    return SizedBox(
      key: const ValueKey('home-chart-legend'),
      height: HomeChartMetrics.legendRow,
      child: Row(
        // UI7: as wide as its entries, so the header can set it at its end.
        mainAxisSize: MainAxisSize.min,
        // UI7: only the second entry may give way (two Flexibles split the
        // room in halves and cut "Previous ..." though the whole fitted).
        children: [
          item(colors.primary, current, dashed: false),
          const SizedBox(width: AppSpacing.s12),
          Flexible(child: item(colors.textMuted, previous, dashed: true)),
        ],
      ),
    );
  }
}

/// A page with nothing to draw: one muted line and, when given, a small text
/// button (Record a sale, Add a product, Record a visit) that runs through
/// the record guard. [behind] is drawn under them (the Sales page's faint
/// guide lines, the Visit page's empty ring).
class HomeChartEmpty extends StatelessWidget {
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final Widget? behind;

  const HomeChartEmpty({super.key, required this.message, this.action, this.onAction, this.behind});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final front = LayoutBuilder(
      builder: (context, box) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              message,
              key: const ValueKey('home-chart-empty'),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted),
            ),
          ),
          // Below the button's room (the smallest region) the line alone.
          if (action != null && onAction != null && box.maxHeight >= HomeChartMetrics.target + HomeChartMetrics.legendRow)
            TextButton(
              key: const ValueKey('home-chart-empty-action'),
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(HomeChartMetrics.target, HomeChartMetrics.target),
                textStyle: const TextStyle(fontSize: HomeChartMetrics.axisLabel, fontWeight: AppFontWeight.semibold),
              ),
              child: Text(action!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      ),
    );
    return behind == null ? front : Stack(fit: StackFit.expand, children: [behind!, front]);
  }
}

/// The top of a chart's scale: the next "nice" value (1, 2 or 5 times a
/// power of ten) at or above [max], so the guide labels are round.
double homeChartNiceMax(double max) {
  if (max <= 0) return 1;
  final power = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
  for (final step in HomeChartMetrics.niceSteps) {
    if (step * power >= max) return step * power;
  }
  return 10 * power;
}

/// HUB4: the guide lines' values, bottom up: 0, half and the top.
List<double> homeChartGuides(double top) => [0, top / 2, top];

/// HUB4: whether day [i] of [span] gets a label under the plot: every day
/// of a week (its initial); for 30 days every [HomeChartMetrics.dayLabelEvery]th
/// counting back from today, so today is always labelled.
bool homeChartDayLabelled(int i, int span) =>
    span <= HomeChartMetrics.weekDays || (span - 1 - i) % HomeChartMetrics.dayLabelEvery == 0;
