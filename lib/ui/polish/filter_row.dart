import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL1: the single filter row. Text segments, each with its count; the
/// chosen one in primary with a thin underline, the others in secondary
/// text. Never a rainbow. Each segment holds a STORED value and shows its
/// label, so a screen compares the stored value, never the label. It
/// scrolls sideways when the segments do not fit (phones), and sits on a
/// hairline that runs the row's full width.
class FilterRow extends StatelessWidget {
  /// Stored values, in order.
  final List<String> values;
  final String selected;
  final String Function(String value) label;

  /// The count shown after a segment's label; null shows none.
  final int? Function(String value)? count;
  final ValueChanged<String> onSelected;

  /// When set, each segment is keyed '[keyPrefix][value]' (tests).
  final String? keyPrefix;

  /// Around the segments (the page's side padding by default).
  final EdgeInsetsGeometry padding;

  const FilterRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.count,
    this.keyPrefix,
    this.padding = const EdgeInsets.symmetric(horizontal: PolishMetrics.pagePadding),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: PolishMetrics.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [for (final v in values) _segment(context, v)],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, String value) {
    final colors = context.colors;
    final isSelected = value == selected;
    final ink = isSelected ? colors.primary : colors.textSecondary;
    final n = count?.call(value);
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        key: keyPrefix == null ? null : ValueKey('$keyPrefix$value'),
        onTap: () => onSelected(value),
        child: Container(
          constraints: const BoxConstraints(minHeight: PolishMetrics.filterHeight),
          padding: const EdgeInsets.symmetric(horizontal: PolishMetrics.filterPaddingH),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? colors.primary : Colors.transparent,
                width: PolishMetrics.filterUnderline,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(value),
                style: TextStyle(
                  fontSize: PolishMetrics.filterText,
                  fontWeight: isSelected ? AppFontWeight.semibold : AppFontWeight.regular,
                  color: ink,
                ),
              ),
              if (n != null) ...[
                const SizedBox(width: PolishMetrics.filterCountGap),
                Text(
                  '$n',
                  key: keyPrefix == null ? null : ValueKey('$keyPrefix$value-count'),
                  style: TextStyle(fontSize: PolishMetrics.filterText, color: ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
