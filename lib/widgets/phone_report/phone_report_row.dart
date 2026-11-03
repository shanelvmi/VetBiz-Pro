import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../phone_list/record_tile.dart';

// PH7b (docs/design/phone_reports.md): a report's rows on a phone. Two lines
// at least 56 high, text at least 14 on line 1 and 13 on line 2, nothing
// that scrolls sideways (R2); and a label beside its value (R4).

/// One short piece of line 2, in its own colour when it carries meaning
/// (an expense in the danger role, an adjustment in the warning one).
class ReportPart {
  final String text;
  final Color? color;

  const ReportPart(this.text, [this.color]);
}

class PhoneReportRow extends StatelessWidget {
  /// Line 1: the name (up to two lines) and the amount at the right.
  final String title;
  final String? amount;
  final Color? amountColor;

  /// Line 2: short pieces, wrapping onto a new line when they must.
  final List<ReportPart> details;

  /// A status as text and colour at the end of line 2 (never colour alone).
  final RecordStatus? status;

  /// A third line (a variance's reason).
  final String? note;

  /// An icon before line 1 (the Activity Log's type), in [iconColor].
  final IconData? icon;
  final Color? iconColor;

  /// Shown on a long press: what the tablet's tooltip shows on hover.
  final String? tooltip;

  const PhoneReportRow({
    super.key,
    required this.title,
    this.amount,
    this.amountColor,
    this.details = const [],
    this.status,
    this.note,
    this.icon,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final secondary = TextStyle(fontSize: PhoneReportMetrics.subtitle, color: colors.textMuted);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PhoneReportMetrics.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PhoneReportMetrics.pagePadding,
          vertical: PhoneReportMetrics.rowPaddingV,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: PhoneReportMetrics.icon, color: iconColor ?? colors.textSecondary),
                  const SizedBox(width: PhoneReportMetrics.partGap),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: PhoneReportMetrics.title,
                      fontWeight: AppFontWeight.semibold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: PhoneReportMetrics.partGap),
                  Text(
                    amount!,
                    style: TextStyle(
                      fontSize: PhoneReportMetrics.title,
                      fontWeight: AppFontWeight.semibold,
                      color: amountColor ?? colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
            if (details.isNotEmpty || status != null) ...[
              const SizedBox(height: PhoneReportMetrics.lineGap),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: PhoneReportMetrics.partGap,
                      children: [
                        for (final d in details) Text(d.text, style: d.color == null ? secondary : secondary.copyWith(color: d.color)),
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: PhoneReportMetrics.partGap),
                    Flexible(child: StatusChip(status: status!)),
                  ],
                ],
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: PhoneReportMetrics.lineGap),
              Text(note!, style: secondary.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
    if (tooltip != null) row = Tooltip(message: tooltip!, triggerMode: TooltipTriggerMode.longPress, child: row);
    return MergeSemantics(child: row);
  }
}

/// A label and its value on one row, at least 48 high (R4): the label
/// wraps, the value keeps its width. [bold] for a total.
class PhoneReportStat extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const PhoneReportStat({super.key, required this.label, required this.value, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final weight = bold ? AppFontWeight.bold : AppFontWeight.medium;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PhoneReportMetrics.statMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PhoneReportMetrics.pagePadding,
            vertical: PhoneReportMetrics.statPaddingV,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: PhoneReportMetrics.title, color: colors.textSoft, fontWeight: bold ? weight : null)),
              ),
              const SizedBox(width: PhoneReportMetrics.partGap),
              Text(
                value,
                style: TextStyle(
                  fontSize: PhoneReportMetrics.title,
                  fontWeight: weight,
                  color: valueColor ?? colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
