import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../initials_avatar.dart';

// PH5a R6 (docs/design/phone_list_pattern.md): one record on a phone. Two
// lines, at least 64 high: a 40 px round leading, the person and the amount,
// then the supporting text and a status chip that shows text as well as
// colour. No buttons inside: a tap opens the details page (R7).

/// A status as a chip: its text, and the role it is drawn in.
class RecordStatus {
  final String label;
  final Color color;

  const RecordStatus(this.label, this.color);
}

/// The chart role a name gets, the same one every time.
Color leadingColorFor(AppColors colors, String seed) {
  final roles = [
    colors.chart1,
    colors.chart2,
    colors.chart3,
    colors.chart4,
    colors.chart5,
    colors.chart6,
    colors.chart7,
    colors.chart8,
    colors.chart9,
  ];
  final hash = seed.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return roles[hash % roles.length];
}

class RecordTile extends StatelessWidget {
  /// Line 1: the person (or Walk-in) and the amount, already formatted.
  final String title;
  final String amount;

  /// Line 2: short pieces (an invoice number, a category, a time).
  final List<String> details;
  final RecordStatus? status;

  /// PH8b: a chip after the title in place of the amount (a team member's
  /// role), when there is no amount to show.
  final RecordStatus? titleStatus;

  /// PH8b: a small tag of the screen's own at the start of line 2 (a
  /// facility's type).
  final Widget? tag;

  /// The leading: [initialsOf]'s initials, or [icon] when it is null.
  final String? initialsOf;
  final IconData? icon;

  /// PH7a: a leading of the screen's own (a product's photo), 40 px, in
  /// place of the initials or icon.
  final Widget? leading;

  /// What picks the leading's colour (a client's name, a category).
  final String colorSeed;

  /// What a screen reader says for the whole row (R11).
  final String semanticsLabel;
  final VoidCallback? onTap;

  const RecordTile({
    super.key,
    required this.title,
    required this.amount,
    required this.details,
    required this.colorSeed,
    required this.semanticsLabel,
    this.status,
    this.titleStatus,
    this.tag,
    this.initialsOf,
    this.icon,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = leadingColorFor(colors, colorSeed);
    final secondary = TextStyle(fontSize: PhoneListMetrics.subtitle, color: colors.textMuted);
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PhoneListMetrics.rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PhoneListMetrics.pagePadding,
                vertical: PhoneListMetrics.rowPaddingV,
              ),
              child: Row(
                children: [
                  leading ?? _Leading(tint: tint, initialsOf: initialsOf, icon: icon),
                  const SizedBox(width: PhoneListMetrics.leadingGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: PhoneListMetrics.title,
                                  fontWeight: AppFontWeight.semibold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: PhoneListMetrics.partGap),
                            if (titleStatus != null)
                              Flexible(child: StatusChip(status: titleStatus!))
                            else
                              Text(
                                amount,
                                style: TextStyle(
                                  fontSize: PhoneListMetrics.title,
                                  fontWeight: AppFontWeight.semibold,
                                  color: colors.textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: PhoneListMetrics.lineGap),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: PhoneListMetrics.partGap,
                                children: [if (tag != null) tag!, for (final d in details) Text(d, style: secondary)],
                              ),
                            ),
                            if (status != null) ...[
                              const SizedBox(width: PhoneListMetrics.partGap),
                              // PH7a: a long label (Kiswahili at 360) wraps in the chip.
                              Flexible(child: StatusChip(status: status!)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  final Color tint;
  final String? initialsOf;
  final IconData? icon;

  const _Leading({required this.tint, required this.initialsOf, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: PhoneListMetrics.leading,
      height: PhoneListMetrics.leading,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.withValues(alpha: PhoneListMetrics.leadingAlpha), shape: BoxShape.circle),
      child: initialsOf != null
          ? Text(
              InitialsAvatar.initialsFor(initialsOf!),
              style: TextStyle(
                fontSize: PhoneListMetrics.leadingText,
                fontWeight: AppFontWeight.bold,
                color: colors.textPrimary,
              ),
            )
          : Icon(icon, size: PhoneListMetrics.leadingIcon, color: colors.textPrimary),
    );
  }
}

/// A status as text on a tint of its role: never colour alone (R11).
class StatusChip extends StatelessWidget {
  final RecordStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PhoneListMetrics.chipPaddingH,
        vertical: PhoneListMetrics.chipPaddingV,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: PhoneListMetrics.chipAlpha),
        borderRadius: BorderRadius.circular(PhoneListMetrics.chipRadius),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: PhoneListMetrics.chip, fontWeight: AppFontWeight.semibold, color: status.color),
      ),
    );
  }
}
