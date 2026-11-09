import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/reveal/skeleton_box.dart';
import 'more_screen.dart';
import 'record_sheet.dart';

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
