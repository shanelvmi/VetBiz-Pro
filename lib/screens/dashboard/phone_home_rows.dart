import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
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
