import 'package:flutter/material.dart';

import '../../config/app_ranges.dart';
import '../../l10n/l10n.dart';
import '../../models/debt.dart';
import '../../models/product.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../products/stock_alerts_screen.dart';

/// Where a Needs attention row leads.
enum AttentionTarget { stockAlerts, debtors }

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
  final int count;
  final VoidCallback onTap;

  const _AttentionRow({required this.icon, required this.text, required this.count, required this.onTap});

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
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
