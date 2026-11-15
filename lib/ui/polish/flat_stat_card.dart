import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL1, owner rule 4: a stat or summary card is a flat surface with a
/// hairline border. No gradient, no glow, no shadow, no coloured icon tile.
/// The value is the one large thing; the label and the hint are secondary.
/// [selected] (a card that is also a filter) marks it with the primary
/// border, the one accent meaning "chosen".
class FlatStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final VoidCallback? onTap;
  final bool selected;

  const FlatStatCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PolishMetrics.cardRadius),
      side: BorderSide(color: selected ? colors.primary : colors.border, width: PolishMetrics.hairline),
    );
    final secondary = TextStyle(fontSize: PolishMetrics.statLabel, color: colors.textSecondary);
    return Material(
      color: colors.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PolishMetrics.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
              const SizedBox(height: PolishMetrics.statLineGap),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: PolishMetrics.statValue,
                  fontWeight: AppFontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: PolishMetrics.statLineGap),
                Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
