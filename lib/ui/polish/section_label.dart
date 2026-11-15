import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL1: the small header over a group of rows ("New", "Earlier", a month).
/// Secondary text, one size; a header for screen readers.
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      PolishMetrics.pagePadding,
      PolishMetrics.sectionLabelPaddingTop,
      PolishMetrics.pagePadding,
      PolishMetrics.sectionLabelPaddingBottom,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: PolishMetrics.sectionLabel,
            fontWeight: AppFontWeight.semibold,
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
