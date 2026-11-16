import 'package:flutter/material.dart';

import '../config/app_timeouts.dart';
import '../l10n/l10n.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/polish_metrics.dart';
import '../theme/theme_context.dart';
import '../ui/polish/app_status.dart';
import '../ui/polish/status_pill.dart';

/// The result of comparing a KPI's current-period value against the
/// immediately preceding equivalent period, plus the business-meaning
/// context needed to color it correctly - a rising number isn't always
/// a good outcome (rising expenses or outstanding debt is the opposite
/// of rising sales or profit), so this carries [higherIsBetter] rather
/// than SummaryCard guessing from the raw sign alone.
class KpiTrend {
  final double currentValue;
  final double previousValue;
  final bool higherIsBetter;

  /// e.g. "vs Yesterday", "vs Last Week", "vs Last Month", "vs Last Year".
  final String comparisonLabel;

  /// Formats an absolute delta the same way the card's own `value` is
  /// formatted (e.g. "Tsh 45,000" for money, "3" for a plain count) -
  /// passed in rather than guessed, since SummaryCard has no way to
  /// know which formatting a given KPI uses on its own.
  final String Function(double) formatChange;

  /// The previous-period fetch is still in flight - the trend is
  /// suppressed entirely while this is true, rather than briefly
  /// showing an incorrect comparison against a default/zero value
  /// before the real one arrives.
  final bool isLoading;

  const KpiTrend({
    required this.currentValue,
    required this.previousValue,
    required this.higherIsBetter,
    required this.comparisonLabel,
    required this.formatChange,
    this.isLoading = false,
  });

  double get absoluteChange => currentValue - previousValue;

  // Previous period had genuinely nothing to compare against - shown
  // as "New" rather than a nonsensical infinite percentage, and rather
  // than crashing on the division by zero a naive percentage
  // calculation would hit here.
  bool get isNewActivity => previousValue == 0 && currentValue != 0;

  // Both periods were exactly zero - nothing meaningfully changed,
  // shown as no indicator at all rather than a technically-true but
  // meaningless "0% change".
  bool get hasNoChange => previousValue == 0 && currentValue == 0;

  double get percent => previousValue == 0 ? 0 : (absoluteChange / previousValue) * 100;

  bool get isPositive => higherIsBetter ? absoluteChange >= 0 : absoluteChange <= 0;
}

class SummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  /// Until POL2 the icon circle's and the glow's colour; no longer drawn
  /// (owner rule 2: a figure's kind is never coloured). Kept so callers
  /// need not change.
  final Color color;
  /// Until POL2 a higher elevation; the card is flat now (owner rule 4).
  final bool shadow;
  final String? subtitle; // optional small caption, e.g. a period label
  // or "as of now" - lets a card clarify what the figure means without
  // needing a second widget.
  final bool isLoading; // shows a small spinner in place of the value

  // Null (the default) shows no trend at all - existing callers
  // (transactions_screen.dart) that don't pass this keep working
  // exactly as before.
  final KpiTrend? trend;

  // Optional extra content shown below the trend pill - null (the
  // default) for every existing caller. Lets one card (e.g. Net Profit's
  // realized/pending breakdown) add its own small footer without needing
  // a separate, parallel widget that duplicates this card's whole layout.
  final Widget? footer;

  // False (the default) keeps every existing card's layout exactly as
  // before - the trend pill stacked below the value. True moves it
  // inline with the title instead, top-right of the card, matching a
  // card (Net Profit) that wants the percentage change visible at a
  // glance without competing with the headline figure for attention.
  final bool trendOnTitleRow;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.shadow = false, // default false
    this.subtitle,
    this.isLoading = false,
    this.trend,
    this.footer,
    this.trendOnTitleRow = false,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  // POL2 (owner rule 4): no glow. The card used to flash a glow in its
  // colour when a loaded value changed; the new figure is the signal now.

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
        // POL2: flat, the surface with a hairline border (no elevation, so
        // no shadow); [SummaryCard.shadow] no longer changes the drawing.
        elevation: AppElevation.e0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          side: BorderSide(color: colors.border, width: PolishMetrics.hairline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale down based on the card's OWN rendered width - this way
            // it stays readable whether it's in a 2-column grid on a small
            // phone or a 4-column grid on a desktop, without the parent
            // screen needing to know anything about it.
            final isCompact = constraints.maxWidth < AppBreakpoints.summaryCardCompact;
            final avatarRadius = isCompact ? 16.0 : 20.0;
            final titleSize = isCompact ? AppFontSize.f11 : AppFontSize.f12;
            final valueSize = isCompact ? AppFontSize.f12 : AppFontSize.f14;

        return Padding(
              padding: EdgeInsets.all(isCompact ? AppSpacing.s8 : AppSpacing.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // POL2 (owner rule 2): the icon is neutral, in the
                      // avatar's slot, with no coloured circle.
                      SizedBox.square(
                        dimension: avatarRadius * 2,
                        child: Icon(widget.icon, color: colors.textSecondary, size: avatarRadius),
                      ),
                      SizedBox(width: isCompact ? AppSpacing.s8 : AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: titleSize,
                                    ),
                                  ),
                                ),
                                if (widget.trendOnTitleRow &&
                                    !widget.isLoading &&
                                    widget.trend != null &&
                                    !widget.trend!.isLoading &&
                                    !widget.trend!.hasNoChange) ...[
                                  const SizedBox(width: AppSpacing.s6),
                                  Flexible(child: _TrendPill(trend: widget.trend!)),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            if (widget.isLoading)
                              SizedBox(
                                height: valueSize + 4,
                                width: valueSize + 4,
                                // POL2: the theme's own (primary), not the card's colour.
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              // FittedBox instead of ellipsis for the value: a
                              // truncated money figure ("Tsh 12,345,6...") could be
                              // dangerously misleading - shrinking it to fit is safer
                              // than cutting characters off.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.value,
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: context.colors.textStrong,
                                    fontWeight: AppFontWeight.bold,
                                    fontSize: valueSize,
                                  ),
                                ),
                              ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                textAlign: TextAlign.start,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isCompact ? AppFontSize.f9 : AppFontSize.f10,
                                  color: context.colors.textMuted,
                                ),
                              ),
                            if (!widget.trendOnTitleRow &&
                                !widget.isLoading &&
                                widget.trend != null &&
                                !widget.trend!.isLoading &&
                                !widget.trend!.hasNoChange) ...[
                              SizedBox(height: isCompact ? AppSpacing.s3 : AppSpacing.s4),
                              _TrendPill(trend: widget.trend!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isLoading && widget.footer != null) ...[
                    SizedBox(height: isCompact ? AppSpacing.s2 : AppSpacing.s4),
                    widget.footer!,
                  ],
                ],
              ),
            );
          },
        ),
    );
  }
}

/// The KPI's trend at a glance: the direction and percentage, with the
/// comparison period and exact absolute change in the tooltip. POL2: the one
/// StatusPill (owner rule 3) in the four states only: a good change success,
/// a bad one danger (by [KpiTrend.higherIsBetter], as before), new activity
/// neutral; the arrow and the figure carry the direction. The arrow no
/// longer floats (a decoration, and never still under reduced motion).
class _TrendPill extends StatelessWidget {
  final KpiTrend trend;
  const _TrendPill({required this.trend});

  @override
  Widget build(BuildContext context) {
    final status = trend.isNewActivity
        ? AppStatus.neutral
        : (trend.isPositive ? AppStatus.success : AppStatus.danger);
    final arrowIcon = trend.isNewActivity
        ? Icons.fiber_new_rounded
        : (trend.absoluteChange >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    final label = trend.isNewActivity ? context.l10n.summary_trendNew : '${trend.percent.abs().toStringAsFixed(1)}%';

    final changeText = trend.absoluteChange >= 0
        ? '+${trend.formatChange(trend.absoluteChange)}'
        : '-${trend.formatChange(trend.absoluteChange.abs())}';

    return Tooltip(
      message: '${trend.comparisonLabel}: $changeText',
      waitDuration: AppTimeouts.tooltipDelay,
      child: StatusPill(status: status, label: label, icon: arrowIcon),
    );
  }
}
