import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// One page: the surface card, a small title line at its top left (and
/// [trailing] at its right), the chart in the rest; a tap opens Insights.
class HomeChartPage extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget body;
  final VoidCallback onOpen;
  final GestureLongPressStartCallback? onPressStart;
  final GestureLongPressMoveUpdateCallback? onPressMove;
  final VoidCallback? onPressEnd;

  const HomeChartPage({
    super.key,
    required this.title,
    required this.body,
    required this.onOpen,
    this.trailing,
    this.onPressStart,
    this.onPressMove,
    this.onPressEnd,
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
          button: true,
          label: title,
          hint: context.l10n.insights_title,
          excludeSemantics: true,
          onTap: onOpen,
          child: InkWell(
            onTap: onOpen,
            child: GestureDetector(
              onLongPressStart: onPressStart,
              onLongPressMoveUpdate: onPressMove,
              onLongPressEnd: onPressEnd == null ? null : (_) => onPressEnd!(),
              child: Padding(
                padding: const EdgeInsets.all(HomeChartMetrics.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
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
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: HomeChartMetrics.titleGap),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one muted line of a page with nothing to draw this week.
class HomeChartEmpty extends StatelessWidget {
  const HomeChartEmpty({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      context.l10n.home_chartNoData,
      key: const ValueKey('home-chart-empty'),
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: context.colors.textMuted),
    ),
  );
}

/// The top of a chart's scale: the next "nice" value (1, 2, 2.5 or 5 times a
/// power of ten) at or above [max], so the two guide labels are round.
double homeChartNiceMax(double max) {
  if (max <= 0) return 1;
  final power = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
  for (final step in HomeChartMetrics.niceSteps) {
    if (step * power >= max) return step * power;
  }
  return 10 * power;
}
