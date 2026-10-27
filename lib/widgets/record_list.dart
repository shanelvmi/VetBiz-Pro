import 'package:flutter/material.dart';


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

  /// Whether a window or pane this wide shows the table. (PH2b stub.)
  bool showsTable(double width) => throw UnimplementedError();

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
