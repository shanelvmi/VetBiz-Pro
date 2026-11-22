import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// UX7 (owner, 2026-11-22): the one template of the PC/tablet Settings
/// pages. The page header, then the body at the full content width with the
/// page padding (PageCardList); cards are PageCards; these lay them out.

/// Two columns of cards from [AppBreakpoints.medium] of the content, one
/// below it (left, then right). Each column stacks its cards with the gap
/// between groups.
class PageColumns extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;

  const PageColumns({super.key, required this.left, required this.right});

  static bool twoColumns(double width) => width >= AppBreakpoints.medium;

  Widget _stack(List<Widget> cards) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: PolishMetrics.gapBetweenGroups),
            c,
          ],
        ],
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!twoColumns(constraints.maxWidth)) return _stack([...left, ...right]);
          return Row(
            key: const ValueKey('pageColumns-two'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(key: const ValueKey('pageColumns-left'), child: _stack(left)),
              const SizedBox(width: PolishMetrics.gapBetweenGroups),
              Expanded(key: const ValueKey('pageColumns-right'), child: _stack(right)),
            ],
          );
        },
      );
}

/// Cards in a grid: two per row from [AppBreakpoints.medium] of the content,
/// one below it, in reading order.
class PageGrid extends StatelessWidget {
  final List<Widget> children;

  const PageGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = PageColumns.twoColumns(constraints.maxWidth) ? 2 : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i += columns) ...[
                if (i > 0) const SizedBox(height: PolishMetrics.gapBetweenGroups),
                // Top-aligned, not IntrinsicHeight (a past crash in a scrolling
                // column, CLAUDE.md).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: PolishMetrics.gapBetweenGroups),
                      Expanded(child: j < children.length ? children[j] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      );
}

/// One row of a Settings table (and its header row): the main cell takes the
/// room left; an optional [middle] cell (Category) a share of it; the Date
/// cell and the actions cell are fixed widths, so each sits at one x on every
/// row. Hairline dividers come from the caller (between rows); no shadow.
class PageTableRow extends StatelessWidget {
  final Widget main;
  final Widget? middle;
  final Widget date;
  final Widget? actions;

  const PageTableRow({super.key, required this.main, this.middle, required this.date, this.actions});

  /// The header row: the column titles in secondary text.
  factory PageTableRow.header(BuildContext context,
      {Key? key, required String main, String? middle, required String date, String? actions}) {
    Text cell(String s) => Text(s,
        style: TextStyle(
            fontSize: PolishMetrics.tableHeaderText, fontWeight: AppFontWeight.semibold, color: context.colors.textSecondary));
    return PageTableRow(
      key: key,
      main: cell(main),
      middle: middle == null ? null : cell(middle),
      date: cell(date),
      actions: actions == null ? null : Align(alignment: Alignment.centerRight, child: cell(actions)),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: PolishMetrics.cardPadding, vertical: PolishMetrics.tableRowPaddingV),
        child: Row(
          children: [
            Expanded(flex: 3, child: main),
            if (middle != null) ...[
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: middle!),
            ],
            const SizedBox(width: AppSpacing.s12),
            SizedBox(key: const ValueKey('pageTable-date'), width: PolishMetrics.tableDateColumn, child: date),
            if (actions != null) ...[
              const SizedBox(width: AppSpacing.s12),
              SizedBox(width: PolishMetrics.tableActionsColumn, child: actions),
            ],
          ],
        ),
      );
}
