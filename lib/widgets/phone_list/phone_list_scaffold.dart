import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../config/app_timeouts.dart';
import '../../screens/dashboard/phone_shell.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_safe_area.dart';
import '../reveal/reveal.dart';
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

  /// RV2: the summary's figures are still loading. The reveal waits for
  /// them (within its 1200 ms), and the line keeps its slot until they come.
  final bool summaryPending;

  /// RV2: whether the first page has answered, for a screen whose provider
  /// knows (Products: `provider.loaded`). Null: answered once [loading] has
  /// been true and is false again, or on an error, or with rows.
  final bool? firstPageAnswered;

  /// RV2b: the rows show photos (RevealImage): the first screenful may hold
  /// the reveal for AppTimeouts.revealImageGrace, never past its 1200 ms.
  final bool imageGrace;

  /// Shown above the rows (the "new records - Refresh" banner).
  final Widget? banner;

  final List<T> items;
  final String Function(T item) idOf;
  final DateTime Function(T item) dateOf;
  final double Function(T item) amountOf;

  /// [grouped] false (search results come in name order): one plain list,
  /// and the tile gives the date itself.
  final bool grouped;

  /// PH7b: the groups are months, not days (Past Reports).
  final bool byMonth;

  /// PH8a: false for a list whose days have no amount (the Activity log): the
  /// day headers then show no total.
  final bool dayTotals;
  final Widget Function(BuildContext context, T item, {required bool grouped}) tileBuilder;

  /// The first page has not arrived yet.
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyText;

  /// The floating button (null: none) and the empty state's.
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
    this.byMonth = false,
    this.dayTotals = true,
    this.summaryPending = false,
    this.firstPageAnswered,
    this.imageGrace = false,
  });

  @override
  State<PhoneListScaffold<T>> createState() => _PhoneListScaffoldState<T>();
}

class _PhoneListScaffoldState<T> extends State<PhoneListScaffold<T>> {
  late bool _searching = widget.startSearching ?? widget.searchController.text.isNotEmpty;
  bool _fabExtended = true;

  // RV2 (docs/design/screen_reveal.md 8.1): the header and the rows arrive
  // as one piece, once per screen: the gate waits for the first page and the
  // summary's figures. Later loads (Load more, refresh, a filter, a search)
  // only change the in-list states, as before.
  bool _sawLoading = false;
  late final ValueNotifier<bool> _rowsAnswered = ValueNotifier(_rowsAnsweredNow());
  late final ValueNotifier<bool> _summaryAnswered = ValueNotifier(!widget.summaryPending);
  late final RevealGate _gate = RevealGate(primary: [
    ListenableRevealSource<bool>(_rowsAnswered, (v) => v),
    ListenableRevealSource<bool>(_summaryAnswered, (v) => v),
  ], imageGrace: widget.imageGrace ? AppTimeouts.revealImageGrace : null);

  // An empty list before any load was asked for is not an answer: a screen
  // whose controller starts its first read after the first frame would
  // otherwise flash its empty state.
  bool _rowsAnsweredNow() =>
      widget.firstPageAnswered ??
      (widget.error != null || (!widget.loading && (widget.items.isNotEmpty || _sawLoading)));

  @override
  void initState() {
    super.initState();
    _sawLoading = widget.loading;
    _gate; // made now, so data already held opens it before the first frame
  }

  @override
  void didUpdateWidget(PhoneListScaffold<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading) _sawLoading = true;
    if (!_rowsAnswered.value && _rowsAnsweredNow()) _rowsAnswered.value = true;
    if (!_summaryAnswered.value && !widget.summaryPending) _summaryAnswered.value = true;
  }

  @override
  void dispose() {
    _gate.dispose();
    _rowsAnswered.dispose();
    _summaryAnswered.dispose();
    super.dispose();
  }

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
                    // PH7a: a long label (Products' smart defaults) wraps.
                    Flexible(child: Text(widget.menu[i].label)),
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
        dateOf: widget.dateOf,
        amountOf: widget.amountOf,
        complete: !widget.hasMore && !widget.loadingMore,
        byMonth: widget.byMonth);
    return [
      for (final g in groups)
        SliverMainAxisGroup(slivers: [
          SliverPersistentHeader(pinned: true, delegate: PhoneDayHeader(g.day, widget.dayTotals ? g.total : null, context.l10n, month: widget.byMonth)),
          SliverList.list(children: [for (final item in g.items) tile(item)]),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final fab = widget.fab;
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
      // PH8a: as a tab of the phone shell, the subscription banner sits under
      // the app bar; a pushed screen has none.
      body: PhoneShell.bodyWithBanner(context, KeyedSubtree(
        key: const ValueKey('phoneList-revealGroup'),
        child: ScreenReveal(gate: _gate, skeleton: _skeleton(context), child: _list(context)),
      )),
    );
  }

  PhoneListHeader _header({bool skeleton = false}) => PhoneListHeader(
        banner: widget.banner,
        quickChips: widget.quickChips,
        filtersActive: widget.filtersActive,
        onFilter: widget.onFilter,
        appliedFilters: widget.appliedFilters,
        summaryLine: widget.summaryLine,
        summaryPending: widget.summaryPending,
        onSummary: widget.onSummary,
        skeleton: skeleton,
      );

  /// RV2: the header's parts and the six PH5a rows at their real sizes, from
  /// the list's top; it fills the page as the list does, never scrolls and
  /// is cut at the page's bottom.
  Widget _skeleton(BuildContext context) => SizedBox.expand(
        child: SingleChildScrollView(
          key: const ValueKey('phoneList-revealSkeleton'),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(skeleton: true),
              const PhoneListSkeleton(key: ValueKey('phoneList-skeleton'), pulse: false),
            ],
          ),
        ),
      );

  Widget _list(BuildContext context) {
    final fab = widget.fab;
    final showMore = widget.items.isNotEmpty && (widget.hasMore || widget.loadingMore);
    return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            key: const ValueKey('phoneList-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              ..._rows(context),
              if (showMore)
                SliverToBoxAdapter(
                  child: PhoneListLoadMore(
                    key: const ValueKey('phoneList-loadMore'),
                    loading: widget.loadingMore,
                    onLoadMore: widget.onLoadMore,
                  ),
                ),
              // Room under the last row: the floating button never covers it
              // (UI4: as a tab, nor does the shell's "+", which rises above
              // the bar over the middle of the page).
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: (fab == null ? PhoneListMetrics.pagePadding : PhoneListMetrics.fabClearance) +
                      AppSafeArea.bottomOf(context) +
                      PhoneShellInsets.overhangOf(context),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
