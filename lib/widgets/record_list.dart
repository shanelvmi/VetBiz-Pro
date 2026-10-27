import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

// PH2b S5 (docs/design/phone_foundations.md): one list for the record
// screens. A table from AppBreakpoints.medium, cards below it. It never
// draws a details panel: it calls onOpen, and each screen decides (a page
// on phones, the side panel at AppBreakpoints.detailsSidePanel and wider).
// No screen uses it yet (PH5 moves the lists onto it).

/// One table column.
class RecordColumn<T> {
  final String label;
  final int flex;

  /// The table is shown only when every column gets at least this much;
  /// otherwise the cards are (never a sideways scroll).
  final double minWidth;
  final Widget Function(BuildContext context, T item) cell;
  final TextAlign align;

  const RecordColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.minWidth = 0,
    this.align = TextAlign.start,
  });
}

class RecordList<T> extends StatelessWidget {
  /// Null while the first page loads.
  final List<T>? items;
  final List<RecordColumn<T>> columns;

  /// One record as a card, below AppBreakpoints.medium.
  final Widget Function(BuildContext context, T item) cardBuilder;

  /// What a screen reader says for a row or card.
  final String Function(T item) semanticsLabel;
  final void Function(T item)? onOpen;

  /// The row or card drawn as chosen (its details are open).
  final bool Function(T item)? isSelected;

  final String emptyText;

  /// Set when loading failed: shown instead of the list, with [onRetry].
  final String? errorText;
  final VoidCallback? onRetry;

  /// More pages: a "Load more" button after the last record, a spinner
  /// while [loadingMore].
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;

  const RecordList({
    super.key,
    required this.items,
    required this.columns,
    required this.cardBuilder,
    required this.semanticsLabel,
    required this.emptyText,
    this.onOpen,
    this.isSelected,
    this.errorText,
    this.onRetry,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
  });

  /// Whether a window or pane this wide shows the table.
  bool showsTable(double width) {
    if (width < AppBreakpoints.medium) return false;
    final minimum = columns.fold<double>(0, (sum, c) => sum + c.minWidth) + AppSpacing.s16 * 2;
    return width >= minimum;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textPrimary),
      child: LayoutBuilder(builder: (context, constraints) {
        if (errorText != null) return _message(context, errorText!, retry: true);
        final list = items;
        if (list == null) {
          return Center(
            child: Semantics(label: context.l10n.common_loading, child: const CircularProgressIndicator()),
          );
        }
        if (list.isEmpty) return _message(context, emptyText);
        final table = showsTable(constraints.maxWidth);
        final count = list.length + (hasMore || loadingMore ? 1 : 0);
        final body = ListView.builder(
          itemCount: count,
          padding: table ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.s12),
          itemBuilder: (context, i) {
            if (i == list.length) return _more(context);
            final item = list[i];
            return table ? _row(context, item) : _card(context, item);
          },
        );
        if (!table) return body;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_header(context), Expanded(child: body)],
        );
      }),
    );
  }

  Widget _message(BuildContext context, String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: retry ? context.colors.danger : context.colors.textMuted),
            ),
            if (retry && onRetry != null) ...[
              const SizedBox(height: AppSpacing.s12),
              OutlinedButton(onPressed: onRetry, child: Text(context.l10n.common_retry)),
            ],
          ],
        ),
      ),
    );
  }

  /// The sticky header: it stays above the scrolling rows.
  Widget _header(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: Text(
                c.label,
                textAlign: c.align,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.f13,
                  fontWeight: AppFontWeight.semibold,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tappable(BuildContext context, T item, Widget child) {
    final selected = isSelected?.call(item) ?? false;
    return Semantics(
      button: onOpen != null,
      selected: selected,
      label: semanticsLabel(item),
      child: Material(
        color: selected ? context.colors.selectedCardFill : context.colors.surface,
        child: InkWell(
          onTap: onOpen == null ? null : () => onOpen!(item),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, T item) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.divider))),
      child: _tappable(
        context,
        item,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          child: Row(
            children: [
              for (final c in columns)
                Expanded(
                  flex: c.flex,
                  child: Align(
                    alignment: c.align == TextAlign.end ? Alignment.centerRight : Alignment.centerLeft,
                    child: c.cell(context, item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, T item) {
    final selected = isSelected?.call(item) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: selected ? context.colors.primary : context.colors.divider),
          ),
          child: _tappable(
            context,
            item,
            Padding(padding: const EdgeInsets.all(AppSpacing.s12), child: cardBuilder(context, item)),
          ),
        ),
      ),
    );
  }

  Widget _more(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Center(
        child: loadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: onLoadMore,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppSizes.minTapTarget)),
                child: Text(context.l10n.reports_loadMore),
              ),
      ),
    );
  }
}
