import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_safe_area.dart';
import 'hub_destinations.dart';
import 'hub_tiles.dart';

/// HUB1: the action panel docked at the bottom of the phone Home (the owner's
/// hub: no bottom bar, no "+", no More page). Collapsed it shows exactly two
/// rows of four tiles (hubCollapsedTilesFor); dragged up, or its handle
/// tapped, it fills the body under the top bar with Find a feature and the
/// named groups (hubGroupsFor). A tile collapses it and runs [onTile]. Escape
/// and the system Back collapse it before they leave Home. It holds no data,
/// so it is not part of Home's reveal: it shows at once.
///
/// It must fill the body (a DraggableScrollableSheet sizes itself as a share
/// of its parent); Home pads its end by [collapsedHeightOf].
class HomeActionPanel extends StatefulWidget {
  final bool isAdmin;
  final bool isPlatformAdmin;
  final Future<void> Function(HubTile tile) onTile;

  const HomeActionPanel({super.key, required this.isAdmin, this.isPlatformAdmin = false, required this.onTile});

  /// The collapsed panel's height: the handle, the two rows, the room under
  /// them and the home indicator.
  static double collapsedHeightOf(BuildContext context) =>
      HomePanelMetrics.handleArea +
      HomePanelMetrics.collapsedRows * hubTileHeight(context) +
      (HomePanelMetrics.collapsedRows - 1) * PhoneHomeMetrics.gridGap +
      HomePanelMetrics.bottomPadding +
      AppSafeArea.bottomOf(context);

  @override
  State<HomeActionPanel> createState() => _HomeActionPanelState();
}

class _HomeActionPanelState extends State<HomeActionPanel> {
  final _sheet = DraggableScrollableController();
  final _query = TextEditingController();
  ScrollController? _scroll;
  bool _expanded = false;

  // The collapsed share of the body, and the body's height (for a drag on
  // the handle), from the last layout.
  double _min = 0;
  double _maxHeight = 1;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _sheet.dispose();
    _query.dispose();
    super.dispose();
  }

  // Escape folds the panel while Home is the screen showing (not under a
  // pushed one or a dialog).
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape || !_expanded) return false;
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    _collapse();
    return true;
  }

  void _snapTo(double size) {
    if (!_sheet.isAttached) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.jumpTo(size);
    } else {
      _sheet.animateTo(size, duration: AppMotion.panelSnap, curve: Curves.easeOutCubic);
    }
  }

  void _expand() => _snapTo(1);

  void _collapse() {
    FocusManager.instance.primaryFocus?.unfocus();
    _query.clear();
    if (_scroll?.hasClients ?? false) _scroll!.jumpTo(0);
    _snapTo(_min);
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  // A drag on the handle moves the panel with the finger (or the mouse, which
  // a scroll view would not follow on the web), then snaps.
  void _dragUpdate(DragUpdateDetails details) {
    if (!_sheet.isAttached) return;
    _sheet.jumpTo((_sheet.size - details.delta.dy / _maxHeight).clamp(_min, 1.0));
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -HomePanelMetrics.flingVelocity) return _expand();
    if (velocity > HomePanelMetrics.flingVelocity) return _collapse();
    if (_sheet.isAttached && _sheet.size - _min > (1 - _min) / 2) return _expand();
    _collapse();
  }

  bool _onExtent(DraggableScrollableNotification n) {
    final open = n.extent > n.minExtent + 0.001;
    if (open != _expanded) setState(() => _expanded = open);
    return false;
  }

  Future<void> _tap(HubTile tile) async {
    if (_expanded) _collapse();
    await widget.onTile(tile);
  }

  Widget _expandedBody(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final groups = [
      for (final g in hubGroupsFor(isAdmin: widget.isAdmin, isPlatformAdmin: widget.isPlatformAdmin))
        (group: g.group, tiles: [for (final t in g.tiles) if (hubTileMatches(l10n, t, _query.text)) t]),
    ].where((g) => g.tiles.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubSearchField(controller: _query, onChanged: () => setState(() {})),
        for (final g in groups) ...[
          const SizedBox(height: HomePanelMetrics.groupGap),
          Text(
            hubGroupTitle(l10n, g.group),
            key: ValueKey('hub-group-${g.group.name}'),
            style: TextStyle(
              fontSize: HomePanelMetrics.groupTitle,
              fontWeight: AppFontWeight.semibold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: HomePanelMetrics.groupTitleGap),
          HubTileGrid(tiles: g.tiles, onTile: _tap),
        ],
        if (groups.isEmpty)
          Padding(
            key: const ValueKey('hub-no-match'),
            padding: const EdgeInsets.only(top: HomePanelMetrics.groupGap),
            child: Text(
              l10n.more_noMatch,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: HomePanelMetrics.noMatchText, color: colors.textSecondary),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final collapsed = HomeActionPanel.collapsedHeightOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      _maxHeight = constraints.maxHeight;
      _min = (collapsed / _maxHeight).clamp(0.0, 1.0);
      return PopScope(
        // Open, Back folds it; folded, Back is Home's (it leaves the app).
        canPop: !_expanded,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _collapse();
        },
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: _onExtent,
          child: DraggableScrollableSheet(
            key: const ValueKey('hub-panel'),
            controller: _sheet,
            initialChildSize: _min,
            minChildSize: _min,
            snap: true,
            snapAnimationDuration: still ? AppMotion.panelSnapStill : AppMotion.panelSnap,
            builder: (context, scroll) {
              _scroll = scroll;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(HomePanelMetrics.radius)),
                  border: Border.all(color: colors.divider, width: HomePanelMetrics.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: HomePanelMetrics.shadowAlpha),
                      blurRadius: HomePanelMetrics.shadowBlur,
                      offset: const Offset(0, HomePanelMetrics.shadowOffsetY),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _Handle(
                      expanded: _expanded,
                      onToggle: _toggle,
                      onExpand: _expand,
                      onCollapse: _collapse,
                      onDragUpdate: _dragUpdate,
                      onDragEnd: _dragEnd,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: HomePanelMetrics.padding),
                      // Folded, only the two rows exist: nothing else can
                      // take focus or be read out.
                      child: _expanded
                          ? _expandedBody(context)
                          : HubTileGrid(
                              key: const ValueKey('hub-collapsed'),
                              tiles: hubCollapsedTilesFor(isAdmin: widget.isAdmin),
                              onTile: _tap,
                            ),
                    ),
                    SizedBox(height: HomePanelMetrics.bottomPadding + AppSafeArea.bottomOf(context)),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

/// The drag handle: a 36 x 4 bar in a full-width 48 px button. A tap
/// toggles; a drag moves the panel. Read out as a button with its state and
/// an action to open or fold the panel.
class _Handle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _Handle({
    required this.expanded,
    required this.onToggle,
    required this.onExpand,
    required this.onCollapse,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      key: const ValueKey('hub-handle'),
      container: true,
      button: true,
      expanded: expanded,
      label: expanded ? l10n.hub_showFewerActions : l10n.hub_showAllActions,
      onTap: onToggle,
      onExpand: expanded ? null : onExpand,
      onCollapse: expanded ? onCollapse : null,
      customSemanticsActions: {
        if (expanded)
          CustomSemanticsAction(label: l10n.hub_showFewerActions): onCollapse
        else
          CustomSemanticsAction(label: l10n.hub_showAllActions): onExpand,
      },
      excludeSemantics: true,
      child: GestureDetector(
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        child: InkWell(
          onTap: onToggle,
          child: SizedBox(
            height: HomePanelMetrics.handleArea,
            width: double.infinity,
            child: Center(
              child: Container(
                width: HomePanelMetrics.handleWidth,
                height: HomePanelMetrics.handleHeight,
                decoration: BoxDecoration(
                  color: context.colors.borderStrong,
                  borderRadius: BorderRadius.circular(HomePanelMetrics.handleHeight),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
