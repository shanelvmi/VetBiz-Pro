import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/press_scale.dart';
import 'hub_destinations.dart';

// HUB1: the action panel's parts (home_action_panel.dart): the grid of tiles
// and Find a feature. Measures from PhoneHomeMetrics (UI5's grid) and
// HomePanelMetrics, colours from context.colors roles only.

/// The tile's height: UI5's 84, scaled with the text, so the panel's
/// collapsed height is known before it is laid out.
double hubTileHeight(BuildContext context) => MediaQuery.textScalerOf(context).scale(PhoneHomeMetrics.gridTileHeight);

/// Rows of [columns] equal tiles (PhoneHomeMetrics.gridColumns by default),
/// [PhoneHomeMetrics.gridGap] apart (UI5's grid); a short last row stays
/// left-aligned. A tile shows a spinner while its action runs (Record Payment
/// first finds who owes) and the grid ignores taps meanwhile.
class HubTileGrid extends StatefulWidget {
  final List<HubTile> tiles;
  final Future<void> Function(HubTile tile) onTile;
  final int columns;

  const HubTileGrid({super.key, required this.tiles, required this.onTile, this.columns = PhoneHomeMetrics.gridColumns});

  @override
  State<HubTileGrid> createState() => _HubTileGridState();
}

class _HubTileGridState extends State<HubTileGrid> {
  HubTile? _busy;

  Future<void> _run(HubTile tile) async {
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
    final columns = widget.columns;
    final tiles = widget.tiles;
    final rows = (tiles.length / columns).ceil();
    return Column(
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
                      ? HubTileView(
                          tile: tiles[r * columns + c],
                          busy: _busy == tiles[r * columns + c],
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

/// UI5's monochrome tile (the owner's sleek option): a neutral fill, a 1 px
/// soft border, an icon in the text colour over two reserved label lines, so
/// every icon shares one top.
class HubTileView extends StatelessWidget {
  final HubTile tile;
  final bool busy;
  final VoidCallback onTap;

  const HubTileView({super.key, required this.tile, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final label = hubTileLabel(context.l10n, tile);
    const lineHeight = PhoneHomeMetrics.tileLabelLineHeight;
    final text = SizedBox(
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
    final icon = SizedBox.square(
      dimension: PhoneHomeMetrics.gridIcon,
      child: busy
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.s2),
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.textPrimary),
            )
          : Icon(hubTileIcon(tile), size: PhoneHomeMetrics.gridIcon, color: colors.textPrimary),
    );
    return Semantics(
      key: ValueKey('hub-tile-${tile.name}'),
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PhoneHomeMetrics.gridRadius),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: hubTileHeight(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PhoneHomeMetrics.gridTilePaddingH,
                  PhoneHomeMetrics.gridTilePaddingTop,
                  PhoneHomeMetrics.gridTilePaddingH,
                  0,
                ),
                child: Column(children: [icon, const SizedBox(height: PhoneHomeMetrics.gridIconGap), text]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Find a feature (MR1's field): rounded, 48 high, a search icon and, while
/// it has text, a clear button.
class HubSearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const HubSearchField({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(HomePanelMetrics.searchRadius),
      borderSide: BorderSide(color: colors.border),
    );
    return TextField(
      key: const ValueKey('hub-search'),
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: HomePanelMetrics.searchText, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: context.l10n.more_findFeature,
        hintStyle: TextStyle(fontSize: HomePanelMetrics.searchText, color: colors.textSecondary),
        prefixIcon: Icon(Icons.search, size: HomePanelMetrics.searchIcon, color: colors.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('hub-search-clear'),
                tooltip: context.l10n.common_clear,
                icon: Icon(Icons.close, size: HomePanelMetrics.searchIcon, color: colors.textSecondary),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        fillColor: colors.surface,
        constraints: const BoxConstraints(minHeight: HomePanelMetrics.searchHeight),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary)),
      ),
    );
  }
}
