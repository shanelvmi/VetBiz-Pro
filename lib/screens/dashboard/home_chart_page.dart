import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// One page: the surface card, the title line at its top, the period text
/// on its own line under it (so nothing collides with the title), then the
/// page's [body]. HUB4: the page is one Semantics node whose label is
/// [summary] (the chart itself is not read out); its buttons and rows stay
/// their own nodes. A tap no longer opens Insights: the taps show a day's
/// amount, open a product or pick a slice (Insights stays in the panel).
class HomeChartPage extends StatelessWidget {
  final String title;
  final String period;
  final String summary;
  final Widget body;

  const HomeChartPage({
    super.key,
    required this.title,
    required this.period,
    required this.summary,
    required this.body,
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
                ExcludeSemantics(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: HomeChartMetrics.title,
                      fontWeight: AppFontWeight.semibold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    period,
                    key: const ValueKey('home-chart-period'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: HomeChartMetrics.titleGap),
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
