import 'package:flutter/material.dart';

import '../../config/app_ranges.dart';
import '../../l10n/l10n.dart';
import '../../models/debt.dart';
import '../../models/product.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/press_scale.dart';
import '../products/stock_alerts_screen.dart';

/// Where a Needs attention row leads.
enum AttentionTarget { stockAlerts, debtors, team }

/// What the phone home's Needs attention strip counts (phone_shell.md D2 and
/// section 2). Worked out only from what the app already holds in memory:
/// ProductProvider.products (the stock alerts' own list, through
/// StockAlertsScreen.currentAlerts) and DebtProvider.debts, with the
/// facility's debtOverdueDays. No read of its own.
class AttentionCounts {
  /// Products low or out of stock.
  final int stock;

  /// Products on hand that expired or expire within the stock alerts' window.
  final int expiry;

  /// Clients whose oldest unpaid debt is at least [overdueDays] old (the rule
  /// of Debtors' "Overdue" filter: oldestUnpaidDebtDate <= now - days).
  final int overdueDebtors;
  final int overdueDays;

  const AttentionCounts({this.stock = 0, this.expiry = 0, this.overdueDebtors = 0, this.overdueDays = 30});

  bool get isEmpty => stock == 0 && expiry == 0 && overdueDebtors == 0;
}

AttentionCounts attentionCountsFor({
  required List<Product> products,
  required List<Debt> debts,
  required int overdueDays,
  DateTime? now,
}) {
  final stock = <String>{};
  final expiry = <String>{};
  for (final alert in StockAlertsScreen.currentAlerts(products)) {
    switch (alert.kind) {
      case StockAlertKind.depleted:
      case StockAlertKind.lowStock:
        stock.add(alert.product.id);
      case StockAlertKind.expired:
      case StockAlertKind.expiringSoon:
        expiry.add(alert.product.id);
      case StockAlertKind.restockShelf:
        break;
    }
  }
  final oldest = <String, DateTime>{};
  for (final d in debts) {
    if (d.amountOwed <= 0) continue;
    final seen = oldest[d.clientId];
    if (seen == null || d.timestamp.isBefore(seen)) oldest[d.clientId] = d.timestamp;
  }
  final cutoff = (now ?? DateTime.now()).subtract(AppRanges.day * overdueDays);
  final overdue = oldest.values.where((t) => !t.isAfter(cutoff)).length;
  return AttentionCounts(stock: stock.length, expiry: expiry.length, overdueDebtors: overdue, overdueDays: overdueDays);
}

/// The strip: drawn only when something needs attention, up to three rows
/// of 56 (icon, one line, a count chip, a chevron) on warningBannerFill.
class NeedsAttentionStrip extends StatelessWidget {
  final AttentionCounts counts;
  final ValueChanged<AttentionTarget> onOpen;

  const NeedsAttentionStrip({super.key, required this.counts, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.home_needsAttention,
          style: TextStyle(
            fontSize: PhoneHomeMetrics.sectionTitle,
            fontWeight: AppFontWeight.semibold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Material(
          color: colors.warningBannerFill,
          borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (counts.stock > 0)
                _AttentionRow(
                  icon: AppIcons.products.outlined,
                  text: l10n.home_attentionStock,
                  count: counts.stock,
                  onTap: () => onOpen(AttentionTarget.stockAlerts),
                ),
              if (counts.expiry > 0)
                _AttentionRow(
                  icon: Icons.event_busy_outlined,
                  text: l10n.home_attentionExpiry,
                  count: counts.expiry,
                  onTap: () => onOpen(AttentionTarget.stockAlerts),
                ),
              if (counts.overdueDebtors > 0)
                _AttentionRow(
                  icon: AppIcons.debtors.outlined,
                  text: l10n.home_attentionDebts(counts.overdueDays),
                  count: counts.overdueDebtors,
                  onTap: () => onOpen(AttentionTarget.debtors),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  /// The count chip; null (UI5's sheet, the count is in the text): none.
  final int? count;
  final VoidCallback onTap;

  const _AttentionRow({required this.icon, required this.text, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding),
            child: Row(
              children: [
                Icon(icon, size: PhoneHomeMetrics.rowIcon, color: colors.warningBannerText),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.textPrimary),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PhoneHomeMetrics.countChipPadding,
                      vertical: AppSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: PhoneHomeMetrics.rowLabel,
                        fontWeight: AppFontWeight.bold,
                        color: colors.warningBannerText,
                      ),
                    ),
                  ),
                ],
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// UI5: one kind of thing that needs attention, in the owner's priority
/// order (the most urgent first).
enum AttentionKind { expired, outOfStock, overdueDebts, expiringSoon, lowStock, pendingApprovals }

/// UI5: a kind and how many need it; the strip shows the first, the sheet
/// every one.
@immutable
class AttentionItem {
  final AttentionKind kind;
  final int count;

  const AttentionItem(this.kind, this.count);

  @override
  bool operator ==(Object other) => other is AttentionItem && other.kind == kind && other.count == count;

  @override
  int get hashCode => Object.hash(kind, count);

  @override
  String toString() => '${kind.name} $count';
}

/// UI5: what needs attention now, most urgent first, kinds with nothing
/// left out. Only from what the app already holds: the products (the stock
/// alerts' own rule, StockAlertsScreen.currentAlerts), the debts (overdue as
/// Debtors defines it, by the facility's [overdueDays]; one item counting
/// clients, never one per debt) and, for admins, the pending members the
/// dashboard's bell already watches ([pendingApprovals]).
List<AttentionItem> attentionItemsFor({
  required List<Product> products,
  required List<Debt> debts,
  required int overdueDays,
  required bool isAdmin,
  int pendingApprovals = 0,
  DateTime? now,
}) {
  final byKind = <StockAlertKind, Set<String>>{};
  for (final alert in StockAlertsScreen.currentAlerts(products)) {
    byKind.putIfAbsent(alert.kind, () => <String>{}).add(alert.product.id);
  }
  int stock(StockAlertKind kind) => byKind[kind]?.length ?? 0;
  final overdue = attentionCountsFor(products: const [], debts: debts, overdueDays: overdueDays, now: now).overdueDebtors;
  final counts = {
    AttentionKind.expired: stock(StockAlertKind.expired),
    AttentionKind.outOfStock: stock(StockAlertKind.depleted),
    AttentionKind.overdueDebts: overdue,
    AttentionKind.expiringSoon: stock(StockAlertKind.expiringSoon),
    AttentionKind.lowStock: stock(StockAlertKind.lowStock),
    AttentionKind.pendingApprovals: isAdmin ? pendingApprovals : 0,
  };
  return [
    for (final kind in AttentionKind.values)
      if (counts[kind]! > 0) AttentionItem(kind, counts[kind]!),
  ];
}

/// UI5: the item's line, its count in the sentence ("Out of stock: 1 product").
String attentionItemText(AppLocalizations l, AttentionItem item) => switch (item.kind) {
      AttentionKind.expired => l.home_attentionExpired(item.count),
      AttentionKind.outOfStock => l.home_attentionOutOfStock(item.count),
      AttentionKind.overdueDebts => l.home_attentionOverdue(item.count),
      AttentionKind.expiringSoon => l.home_attentionExpiring(item.count),
      AttentionKind.lowStock => l.home_attentionLowStock(item.count),
      AttentionKind.pendingApprovals => l.home_attentionPending(item.count),
    };

IconData attentionItemIcon(AttentionKind kind) => switch (kind) {
      AttentionKind.expired => Icons.event_busy_outlined,
      AttentionKind.outOfStock => AppIcons.products.outlined,
      AttentionKind.overdueDebts => AppIcons.debtors.outlined,
      AttentionKind.expiringSoon => Icons.hourglass_bottom_outlined,
      AttentionKind.lowStock => Icons.inventory_outlined,
      AttentionKind.pendingApprovals => Icons.how_to_reg_outlined,
    };

/// UI5: where an item leads: Product Alerts with its kind's chip, Debtors
/// with Overdue, Team Members with Pending.
AttentionTarget attentionItemTarget(AttentionKind kind) => switch (kind) {
      AttentionKind.overdueDebts => AttentionTarget.debtors,
      AttentionKind.pendingApprovals => AttentionTarget.team,
      _ => AttentionTarget.stockAlerts,
    };

/// UI5: the Product Alerts chip an item preselects (null: not a stock item).
StockAlertKind? attentionStockKind(AttentionKind kind) => switch (kind) {
      AttentionKind.expired => StockAlertKind.expired,
      AttentionKind.outOfStock => StockAlertKind.depleted,
      AttentionKind.expiringSoon => StockAlertKind.expiringSoon,
      AttentionKind.lowStock => StockAlertKind.lowStock,
      _ => null,
    };

/// UI5: Needs attention as ONE strip, always [PhoneHomeMetrics.attentionStripHeight]
/// high: the most urgent item's line with its count, a "+N" badge when more
/// kinds need attention, a chevron. A tap opens the sheet of every item. The
/// caller draws it only when [items] is not empty. On the amber fill an
/// amber text would miss 4.5:1 in Light (3.2 for warningBannerText, 3.5 for
/// warningDeep): the text and the badge are textPrimary, the icon and the
/// chevron the deep amber (3:1 or more, an icon's threshold).
class AttentionStrip extends StatelessWidget {
  final List<AttentionItem> items;
  final VoidCallback onTap;

  const AttentionStrip({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final first = items.first;
    final more = items.length - 1;
    final text = attentionItemText(l10n, first);
    return Semantics(
      button: true,
      label: more > 0 ? '$text. ${l10n.home_attentionMoreLabel(more)}' : text,
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          key: const ValueKey('phone-home-attention'),
          color: colors.warningBannerFill,
          borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: PhoneHomeMetrics.attentionStripHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding),
                child: Row(
                  children: [
                    Icon(attentionItemIcon(first.kind), size: PhoneHomeMetrics.rowIcon, color: colors.warningDeep),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: PhoneHomeMetrics.cardLine,
                          fontWeight: AppFontWeight.semibold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (more > 0) ...[
                      const SizedBox(width: AppSpacing.s8),
                      AttentionCountBadge(count: more),
                    ],
                    Icon(Icons.chevron_right, color: colors.warningDeep),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// UI5: the small "+N" badge: the text colour on the page's surface, a pill.
class AttentionCountBadge extends StatelessWidget {
  final int count;

  const AttentionCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.countChipPadding, vertical: AppSpacing.s2),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppRadius.r12)),
      child: Text(
        context.l10n.home_attentionMoreBadge(count),
        style: TextStyle(
          fontSize: PhoneHomeMetrics.label,
          fontWeight: AppFontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

/// UI5: the "Needs attention" sheet: every item as a row (icon, its line
/// with the count, a chevron); a tap closes the sheet and opens the item's
/// screen through [onOpen].
Future<void> showAttentionSheet(
  BuildContext context, {
  required List<AttentionItem> items,
  required ValueChanged<AttentionItem> onOpen,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.home_needsAttention,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          _AttentionRow(
            icon: attentionItemIcon(item.kind),
            text: attentionItemText(sheetContext.l10n, item),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onOpen(item);
            },
          ),
      ],
    ),
  );
}
