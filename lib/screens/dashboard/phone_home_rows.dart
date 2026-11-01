import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import 'more_screen.dart';
import 'record_sheet.dart';

/// The Go to row, in phone_shell.md section 4's order. No item has a role
/// gate today (the sidebar shows every module to an assistant; the gates are
/// inside the screens), so both roles get all eight.
enum GoToItem { products, clients, debtors, reports, transactions, stockStore, services, payments }

List<GoToItem> goToItemsFor({required bool isAdmin}) => GoToItem.values;

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
      GoToItem.products => Icons.inventory_2_outlined,
      GoToItem.clients => Icons.people,
      GoToItem.debtors => Icons.money_off,
      GoToItem.reports => Icons.summarize_outlined,
      GoToItem.transactions => Icons.receipt_long,
      GoToItem.stockStore => Icons.store,
      GoToItem.services => Icons.design_services,
      GoToItem.payments => Icons.payments,
    };

/// The four big tiles (the "+" sheet's four). Record Payment finds who owes
/// first, so a tile shows a spinner while its action runs and ignores taps.
class QuickAccessTiles extends StatefulWidget {
  final Future<void> Function(RecordAction action) onAction;

  const QuickAccessTiles({super.key, required this.onAction});

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
                onTap: () => _run(quickAccessActions[i]),
                child: SizedBox(
                  height: height,
                  child: _RoundLabel(
                    icon: recordActionIcon(quickAccessActions[i]),
                    label: recordActionLabel(context, quickAccessActions[i]),
                    circle: PhoneHomeMetrics.tileCircle,
                    iconSize: PhoneHomeMetrics.tileIcon,
                    busy: _busy == quickAccessActions[i],
                    center: true,
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

  const _RoundLabel({
    required this.icon,
    required this.label,
    required this.circle,
    required this.iconSize,
    this.busy = false,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
      child: Column(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: PhoneHomeMetrics.circleAlpha),
              shape: BoxShape.circle,
            ),
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                  )
                : Icon(icon, size: iconSize, color: colors.primary),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.textPrimary),
          ),
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

  const GoToRow({super.key, required this.items, required this.onGoTo});

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
                width: PhoneHomeMetrics.goToItemWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  onTap: () => onGoTo(item),
                  child: _RoundLabel(
                    icon: _goToIcon(item),
                    label: goToLabel(context, item),
                    circle: PhoneHomeMetrics.goToCircle,
                    iconSize: PhoneHomeMetrics.goToIcon,
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
