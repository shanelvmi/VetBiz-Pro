import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/reveal/skeleton_box.dart';
import 'more_screen.dart';
import 'record_sheet.dart';

/// The Go to row, in phone_shell.md section 4's order. No item has a role
/// gate today (the sidebar shows every module to an assistant; the gates are
/// inside the screens), so both roles get all eight.
enum GoToItem { products, clients, debtors, reports, transactions, stockStore, services, payments }

/// UI2 (the owner): Transactions moves to the end of the row.
List<GoToItem> goToItemsFor({required bool isAdmin}) =>
    [...GoToItem.values.where((i) => i != GoToItem.transactions), GoToItem.transactions];

/// The text style of a round shortcut's label (Go to and Quick access).
TextStyle _labelStyle(BuildContext context) => TextStyle(fontSize: PhoneHomeMetrics.label, color: context.colors.textPrimary);

/// UI2: Transactions' cell is as wide as its label on one line (measured in
/// the label's own style and text size), within the fitted bounds; the other
/// cells keep the uniform width.
double _goToCellWidth(BuildContext context, GoToItem item, String label) {
  if (item != GoToItem.transactions) return PhoneHomeMetrics.goToItemWidth;
  final painter = TextPainter(
    text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.merge(_labelStyle(context))),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble() + 2 * AppSpacing.s4;
  painter.dispose();
  return width.clamp(PhoneHomeMetrics.goToFittedMin, PhoneHomeMetrics.goToFittedMax);
}

/// The More page's item for a shortcut; Products is the Products tab instead.
MoreItem? goToMoreItem(GoToItem item) => switch (item) {
      GoToItem.products => null,
      GoToItem.clients => MoreItem.clients,
      GoToItem.debtors => MoreItem.debtors,
      GoToItem.reports => MoreItem.reports,
      GoToItem.transactions => MoreItem.transactions,
      GoToItem.stockStore => MoreItem.stockStore,
      GoToItem.services => MoreItem.services,
      GoToItem.payments => MoreItem.payments,
    };

String goToLabel(BuildContext context, GoToItem item) {
  final more = goToMoreItem(item);
  return more == null ? context.l10n.nav_products : moreItemLabel(context, more);
}

IconData _goToIcon(GoToItem item) => switch (item) {
      GoToItem.products => AppIcons.products.outlined,
      GoToItem.clients => AppIcons.clients.filled,
      GoToItem.debtors => AppIcons.debtors.filled,
      GoToItem.reports => AppIcons.reports.filled,
      GoToItem.transactions => AppIcons.transactions.filled,
      GoToItem.stockStore => AppIcons.stockStore.filled,
      GoToItem.services => AppIcons.services.filled,
      GoToItem.payments => AppIcons.payments.filled,
    };

/// The four big tiles (the "+" sheet's four). Record Payment finds who owes
/// first, so a tile shows a spinner while its action runs and ignores taps.
class QuickAccessTiles extends StatefulWidget {
  final Future<void> Function(RecordAction action) onAction;

  /// RV1: drawn as Home's skeleton (the same tiles, no taps).
  final bool skeleton;

  const QuickAccessTiles({super.key, required this.onAction, this.skeleton = false});

  @override
  State<QuickAccessTiles> createState() => _QuickAccessTilesState();
}

class _QuickAccessTilesState extends State<QuickAccessTiles> {
  RecordAction? _busy;

  Future<void> _run(RecordAction action) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await widget.onAction(action);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = MediaQuery.textScalerOf(context).scale(PhoneHomeMetrics.tileHeight);
    return Row(
      children: [
        for (var i = 0; i < quickAccessActions.length; i++) ...[
          if (i > 0) const SizedBox(width: PhoneHomeMetrics.tileGap),
          Expanded(
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.skeleton ? null : () => _run(quickAccessActions[i]),
                child: SizedBox(
                  height: height,
                  child: _RoundLabel(
                    icon: recordActionIcon(quickAccessActions[i]),
                    label: recordActionLabel(context, quickAccessActions[i]),
                    circle: PhoneHomeMetrics.tileCircle,
                    iconSize: PhoneHomeMetrics.tileIcon,
                    busy: _busy == quickAccessActions[i],
                    center: true,
                    reserveTwoLines: true,
                    skeleton: widget.skeleton,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A round icon over a label of at most two lines.
class _RoundLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double circle;
  final double iconSize;
  final bool busy;
  final bool center;
  final bool skeleton;

  /// UI2 (Quick access): the label always takes two lines' room, so every
  /// tile's icon sits at the same top whether its label wraps or not.
  final bool reserveTwoLines;

  const _RoundLabel({
    required this.icon,
    required this.label,
    required this.circle,
    required this.iconSize,
    this.busy = false,
    this.center = false,
    this.skeleton = false,
    this.reserveTwoLines = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const lineHeight = PhoneHomeMetrics.tileLabelLineHeight;
    Widget text = Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: _labelStyle(context),
      strutStyle: reserveTwoLines
          ? const StrutStyle(fontSize: PhoneHomeMetrics.label, height: lineHeight, forceStrutHeight: true)
          : null,
    );
    if (reserveTwoLines) {
      text = SizedBox(
        height: MediaQuery.textScalerOf(context).scale(PhoneHomeMetrics.label) * lineHeight * 2,
        child: Align(alignment: Alignment.topCenter, child: text),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
      child: Column(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              color: skeleton ? colors.surfaceMuted : colors.primary.withValues(alpha: PhoneHomeMetrics.circleAlpha),
              shape: BoxShape.circle,
            ),
            child: skeleton
                ? null
                : busy
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                      )
                    : Icon(icon, size: iconSize, color: colors.primary),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (skeleton) SkeletonOf(child: text) else text,
        ],
      ),
    );
  }
}

/// The sideways row of round shortcuts, faded at the trailing edge so it
/// shows there is more.
class GoToRow extends StatelessWidget {
  final List<GoToItem> items;
  final ValueChanged<GoToItem> onGoTo;

  /// RV1: drawn as Home's skeleton (the same shortcuts, no taps).
  final bool skeleton;

  const GoToRow({super.key, required this.items, required this.onGoTo, this.skeleton = false});

  @override
  Widget build(BuildContext context) {
    // Only the mask's alpha counts (dstIn): any opaque role will do.
    final opaque = context.colors.surface;
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(PhoneHomeMetrics.goToHeight),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [opaque, opaque, opaque.withValues(alpha: 0)],
          stops: [0, 1 - PhoneHomeMetrics.goToFade / bounds.width, 1],
        ).createShader(bounds),
        child: ListView(
          key: const ValueKey('phone-home-go-to'),
          scrollDirection: Axis.horizontal,
          children: [
            for (final item in items)
              SizedBox(
                width: _goToCellWidth(context, item, goToLabel(context, item)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  onTap: skeleton ? null : () => onGoTo(item),
                  child: _RoundLabel(
                    icon: _goToIcon(item),
                    label: goToLabel(context, item),
                    circle: PhoneHomeMetrics.goToCircle,
                    iconSize: PhoneHomeMetrics.goToIcon,
                    skeleton: skeleton,
                  ),
                ),
              ),
            // Room to scroll the last shortcut out of the fade.
            const SizedBox(width: PhoneHomeMetrics.goToFade),
          ],
        ),
      ),
    );
  }
}

/// UI5: the eight tiles of Home's action grid, in order: the record actions
/// (the "+" sheet's four), then the places (their existing screens). Products
/// and Sales are not here: the bottom bar has them.
enum HomeTile { recordSale, recordVisit, recordPayment, addClient, debtors, stockStore, reports, transactions }

/// UI5: the tiles the role may use, in order. The gates are today's: Quick
/// access and Go to showed every one of these to both roles (the gates are
/// inside the screens), so an assistant has all eight too. A tile the role
/// may not use is left out and the rest keep their order.
List<HomeTile> homeTilesFor({required bool isAdmin}) => HomeTile.values;

/// The tile's record action, or null for a place.
RecordAction? homeTileAction(HomeTile tile) => switch (tile) {
      HomeTile.recordSale => RecordAction.recordSale,
      HomeTile.recordVisit => RecordAction.recordVisit,
      HomeTile.recordPayment => RecordAction.recordPayment,
      HomeTile.addClient => RecordAction.addClient,
      _ => null,
    };

/// The tile's place (opened as More opens it), or null for a record action.
MoreItem? homeTilePlace(HomeTile tile) => switch (tile) {
      HomeTile.debtors => MoreItem.debtors,
      HomeTile.stockStore => MoreItem.stockStore,
      HomeTile.reports => MoreItem.reports,
      HomeTile.transactions => MoreItem.transactions,
      _ => null,
    };

/// The app's existing label: the record action's, or the screen's title as
/// More shows it.
String homeTileLabel(BuildContext context, HomeTile tile) {
  final action = homeTileAction(tile);
  return action != null ? recordActionLabel(context, action) : moreItemLabel(context, homeTilePlace(tile)!);
}

IconData homeTileIcon(HomeTile tile) => switch (tile) {
      HomeTile.debtors => AppIcons.debtors.outlined,
      HomeTile.stockStore => AppIcons.stockStore.outlined,
      HomeTile.reports => AppIcons.reports.outlined,
      HomeTile.transactions => AppIcons.transactions.outlined,
      _ => recordActionIcon(homeTileAction(tile)!),
    };

/// UI5: Home's action grid: rows of [PhoneHomeMetrics.gridColumns] equal
/// tiles, [PhoneHomeMetrics.gridGap] apart, each about
/// [PhoneHomeMetrics.gridTileHeight] high (scaled with the text). The tile is
/// monochrome (the owner's sleek option): a neutral fill, a 1 px soft border,
/// an icon in the text colour, no coloured circle; two label lines are
/// reserved in every tile so the icons share one top. A short last row stays
/// left-aligned. A tile shows a spinner while its action runs (Record Payment
/// first finds who owes) and ignores taps meanwhile.
class HomeActionGrid extends StatefulWidget {
  final List<HomeTile> tiles;
  final Future<void> Function(HomeTile tile) onTile;

  /// RV1: drawn as Home's skeleton (the same tiles, soft boxes, no taps).
  final bool skeleton;

  const HomeActionGrid({super.key, required this.tiles, required this.onTile, this.skeleton = false});

  @override
  State<HomeActionGrid> createState() => _HomeActionGridState();
}

class _HomeActionGridState extends State<HomeActionGrid> {
  HomeTile? _busy;

  Future<void> _run(HomeTile tile) async {
    if (_busy != null) return;
    setState(() => _busy = tile);
    try {
      await widget.onTile(tile);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const columns = PhoneHomeMetrics.gridColumns;
    final tiles = widget.tiles;
    final rows = (tiles.length / columns).ceil();
    return Column(
      key: const ValueKey('phone-home-grid'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: PhoneHomeMetrics.gridGap),
          Row(
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: PhoneHomeMetrics.gridGap),
                Expanded(
                  child: r * columns + c < tiles.length
                      ? _HomeTileView(
                          tile: tiles[r * columns + c],
                          busy: _busy == tiles[r * columns + c],
                          skeleton: widget.skeleton,
                          onTap: () => _run(tiles[r * columns + c]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _HomeTileView extends StatelessWidget {
  final HomeTile tile;
  final bool busy;
  final bool skeleton;
  final VoidCallback onTap;

  const _HomeTileView({required this.tile, required this.busy, required this.skeleton, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final label = homeTileLabel(context, tile);
    const lineHeight = PhoneHomeMetrics.tileLabelLineHeight;
    Widget text = SizedBox(
      height: scaler.scale(PhoneHomeMetrics.label) * lineHeight * 2,
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.textPrimary),
          strutStyle: const StrutStyle(fontSize: PhoneHomeMetrics.label, height: lineHeight, forceStrutHeight: true),
        ),
      ),
    );
    if (skeleton) text = SkeletonOf(child: text);
    final Widget icon = SizedBox.square(
      dimension: PhoneHomeMetrics.gridIcon,
      child: skeleton
          ? const SkeletonBox(height: PhoneHomeMetrics.gridIcon)
          : busy
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.textPrimary),
                )
              : Icon(homeTileIcon(tile), size: PhoneHomeMetrics.gridIcon, color: colors.textPrimary),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PhoneHomeMetrics.gridRadius),
      side: BorderSide(color: colors.border),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: colors.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: skeleton ? null : onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(PhoneHomeMetrics.gridTileHeight)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PhoneHomeMetrics.gridTilePaddingH,
                  PhoneHomeMetrics.gridTilePaddingTop,
                  PhoneHomeMetrics.gridTilePaddingH,
                  AppSpacing.s4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(height: PhoneHomeMetrics.gridIconGap), text],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
