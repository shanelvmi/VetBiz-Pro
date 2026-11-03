import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_safe_area.dart';
import 'collapsing_fab.dart';
import 'group_by_day.dart';
import 'phone_list_parts.dart';
import 'phone_list_skeleton.dart';

export 'phone_list_parts.dart' show PhoneAppliedFilter, PhoneListAction, PhoneListMenuItem;

// PH5a (docs/design/phone_list_pattern.md): the standard phone list. A screen
// gives its texts, its filters' state and callbacks, its records and a tile;
// this draws the rest the same way everywhere: the app bar with search in
// place and one overflow menu (R1), the floating primary action (R2), the
// header (R3, R4), the rows under pinned day headers (R5), pull to refresh
// (R8), the loading, empty and error states (R9) and paging (R10). The list
// keeps its scroll position while a details page covers it (R7).

class PhoneListScaffold<T> extends StatefulWidget {
  final String title;

  /// A tab of the phone shell: no back arrow (it would pop the shell).
  final bool asTab;
  final List<PhoneListMenuItem> menu;

  /// PH7a: a dot on the menu's button (Products' and Stock Store's stock
  /// alerts, the old bell's dot).
  final bool menuBadge;

  /// Search: the screen's own controller, called on each change and when
  /// the search is closed (which clears it).
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClosed;

  /// Whether the bar starts as the search field; null: when the search
  /// holds text. PH5b: Payments for one client keeps its title although
  /// the search starts with the client's name.
  final bool? startSearching;

  final Widget quickChips;
  final bool filtersActive;

  /// Null: no Filter button (PH5b: a list whose toolbar has no filter
  /// beyond the quick chips, or none at all).
  final VoidCallback? onFilter;
  final List<PhoneAppliedFilter> appliedFilters;

  /// The summary line (null while it has no figures) and its sheet.
  final String? summaryLine;
  final VoidCallback onSummary;

  /// Shown above the rows (the "new records - Refresh" banner).
  final Widget? banner;

  final List<T> items;
  final String Function(T item) idOf;
  final DateTime Function(T item) dateOf;
  final double Function(T item) amountOf;

  /// [grouped] false (search results come in name order): one plain list,
  /// and the tile gives the date itself.
  final bool grouped;
  final Widget Function(BuildContext context, T item, {required bool grouped}) tileBuilder;

  /// The first page has not arrived yet.
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyText;

  /// The floating button (null: none, as on Sales) and the empty state's.
  final PhoneListAction? fab;
  final PhoneListAction? emptyAction;

  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;

  const PhoneListScaffold({
    super.key,
    required this.title,
    required this.asTab,
    required this.menu,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onSearchClosed,
    required this.quickChips,
    required this.filtersActive,
    required this.onFilter,
    required this.appliedFilters,
    required this.summaryLine,
    required this.onSummary,
    required this.items,
    required this.idOf,
    required this.dateOf,
    required this.amountOf,
    required this.grouped,
    required this.tileBuilder,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyText,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onRefresh,
    this.banner,
    this.fab,
    this.emptyAction,
    this.startSearching,
    this.menuBadge = false,
  });

  @override
  State<PhoneListScaffold<T>> createState() => _PhoneListScaffoldState<T>();
}

class _PhoneListScaffoldState<T> extends State<PhoneListScaffold<T>> {
  late bool _searching = widget.startSearching ?? widget.searchController.text.isNotEmpty;
  bool _fabExtended = true;

  bool _onScroll(ScrollNotification n) {
    // The list's own scrolling only, not the chips' sideways row.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse && _fabExtended) setState(() => _fabExtended = false);
      if (n.direction == ScrollDirection.forward && !_fabExtended) setState(() => _fabExtended = true);
    }
    if (n.metrics.extentAfter < PhoneListMetrics.loadMoreExtent && widget.hasMore && !widget.loadingMore) {
      widget.onLoadMore();
    }
    return false;
  }

  void _closeSearch() {
    setState(() => _searching = false);
    widget.onSearchClosed();
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return AppBar(
      automaticallyImplyLeading: !widget.asTab,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: AppElevation.e1,
      title: _searching
          ? TextField(
              key: const ValueKey('phoneList-searchField'),
              controller: widget.searchController,
              autofocus: true,
              decoration: InputDecoration(hintText: widget.searchHint, border: InputBorder.none),
              style: TextStyle(fontSize: AppFontSize.f16, color: colors.textPrimary),
              onChanged: widget.onSearchChanged,
            )
          : Text(widget.title, style: const TextStyle(fontWeight: AppFontWeight.bold)),
      actions: [
        _searching
            ? IconButton(tooltip: l10n.common_close, icon: const Icon(Icons.close), onPressed: _closeSearch)
            : IconButton(
                tooltip: l10n.common_search,
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
        if (widget.menu.isNotEmpty)
          PopupMenuButton<int>(
            icon: widget.menuBadge
                ? Badge(
                    key: const ValueKey('phoneList-menuDot'),
                    smallSize: PhoneListMetrics.filterDot,
                    backgroundColor: colors.danger,
                    child: const Icon(Icons.more_vert),
                  )
                : null,
            onSelected: (i) => widget.menu[i].onSelected(),
            itemBuilder: (context) => [
              for (var i = 0; i < widget.menu.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    Icon(widget.menu[i].icon, color: colors.textSecondary),
                    const SizedBox(width: PhoneListMetrics.leadingGap),
                    Text(widget.menu[i].label),
                  ]),
                ),
            ],
          ),
      ],
    );
  }

  List<Widget> _rows(BuildContext context) {
    if (widget.error != null && widget.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PhoneListError(key: const ValueKey('phoneList-error'), error: widget.error, onRetry: widget.onRetry),
        ),
      ];
    }
    if (widget.loading && widget.items.isEmpty) {
      return [const SliverToBoxAdapter(child: PhoneListSkeleton(key: ValueKey('phoneList-skeleton')))];
    }
    if (widget.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PhoneListEmpty(
            key: const ValueKey('phoneList-empty'),
            icon: widget.emptyIcon,
            text: widget.emptyText,
            action: widget.emptyAction,
          ),
        ),
      ];
    }
    Widget tile(T item) => KeyedSubtree(
          key: ValueKey('phoneList-row-${widget.idOf(item)}'),
          child: widget.tileBuilder(context, item, grouped: widget.grouped),
        );
    if (!widget.grouped) {
      return [SliverList.list(children: [for (final item in widget.items) tile(item)])];
    }
    final groups = groupByDay(widget.items,
        dateOf: widget.dateOf, amountOf: widget.amountOf, complete: !widget.hasMore && !widget.loadingMore);
    return [
      for (final g in groups)
        SliverMainAxisGroup(slivers: [
          SliverPersistentHeader(pinned: true, delegate: PhoneDayHeader(g.day, g.total, context.l10n)),
          SliverList.list(children: [for (final item in g.items) tile(item)]),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final fab = widget.fab;
    final showMore = widget.items.isNotEmpty && (widget.hasMore || widget.loadingMore);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _appBar(context),
      floatingActionButton: fab == null || keyboardOpen
          ? null
          : CollapsingFab(
              key: const ValueKey('phoneList-fab'),
              label: fab.label,
              icon: fab.icon,
              extended: _fabExtended,
              onPressed: fab.onPressed,
            ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            key: const ValueKey('phoneList-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: PhoneListHeader(
                  banner: widget.banner,
                  quickChips: widget.quickChips,
                  filtersActive: widget.filtersActive,
                  onFilter: widget.onFilter,
                  appliedFilters: widget.appliedFilters,
                  summaryLine: widget.summaryLine,
                  onSummary: widget.onSummary,
                ),
              ),
              ..._rows(context),
              if (showMore)
                SliverToBoxAdapter(
                  child: PhoneListLoadMore(
                    key: const ValueKey('phoneList-loadMore'),
                    loading: widget.loadingMore,
                    onLoadMore: widget.onLoadMore,
                  ),
                ),
              // Room under the last row: the floating button never covers it,
              // nor, on a tab, the shell's raised "+" above the bar.
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: (fab == null ? PhoneListMetrics.pagePadding : PhoneListMetrics.fabClearance) +
                      (widget.asTab ? PhoneShellMetrics.recordRaise : 0) +
                      AppSafeArea.bottomOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
