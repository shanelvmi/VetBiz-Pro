import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../firestore_error_view.dart';
import 'group_by_day.dart';

// PH5a: the pieces PhoneListScaffold puts together (phone_list_scaffold.dart,
// docs/design/phone_list_pattern.md).

/// An entry of the app bar's overflow menu (R1).
class PhoneListMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  const PhoneListMenuItem({required this.label, required this.icon, required this.onSelected});
}

/// The primary action: the floating button (R2), and the empty state's
/// button (R9).
class PhoneListAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const PhoneListAction({required this.label, required this.icon, required this.onPressed});
}

/// An applied filter, shown as a chip that removes it (R3).
class PhoneAppliedFilter {
  final String label;
  final VoidCallback onRemove;

  const PhoneAppliedFilter(this.label, this.onRemove);
}

/// Above the rows: the banner, the quick chips with the Filter button (a dot
/// when a filter is on), the applied filters, the summary line (R3, R4).
class PhoneListHeader extends StatelessWidget {
  final Widget? banner;
  final Widget quickChips;
  final bool filtersActive;

  /// Null: no Filter button.
  final VoidCallback? onFilter;
  final List<PhoneAppliedFilter> appliedFilters;
  final String? summaryLine;
  final VoidCallback onSummary;

  const PhoneListHeader({
    super.key,
    required this.banner,
    required this.quickChips,
    required this.filtersActive,
    required this.onFilter,
    required this.appliedFilters,
    required this.summaryLine,
    required this.onSummary,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final filterIcon = Icon(Icons.tune, color: colors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) banner!,
        Row(
          children: [
            Expanded(child: quickChips),
            if (onFilter != null)
              Semantics(
                value: filtersActive ? l10n.phoneList_filtersOn : null,
                child: IconButton(
                  tooltip: l10n.facilityPicker_filter,
                  onPressed: onFilter,
                  icon: filtersActive
                      ? Badge(
                          key: const ValueKey('phoneList-filterDot'),
                          smallSize: PhoneListMetrics.filterDot,
                          backgroundColor: colors.primary,
                          child: filterIcon,
                        )
                      : filterIcon,
                ),
              ),
          ],
        ),
        if (appliedFilters.isNotEmpty)
          Padding(
            key: const ValueKey('phoneList-appliedChips'),
            padding: const EdgeInsets.symmetric(horizontal: PhoneListMetrics.pagePadding),
            child: Wrap(
              spacing: PhoneListMetrics.chipGap,
              children: [
                for (final f in appliedFilters)
                  InputChip(label: Text(f.label), onDeleted: f.onRemove, deleteButtonTooltipMessage: l10n.common_remove),
              ],
            ),
          ),
        if (summaryLine != null)
          Padding(
            padding: const EdgeInsets.only(left: PhoneListMetrics.pagePadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summaryLine!,
                    key: const ValueKey('phoneList-summaryLine'),
                    style: TextStyle(fontSize: PhoneListMetrics.summaryLine, color: colors.textSecondary),
                  ),
                ),
                TextButton(
                  key: const ValueKey('phoneList-summaryLink'),
                  onPressed: onSummary,
                  child: Text(l10n.common_summary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A day's header, pinned while its day scrolls (R5): the day, and its total
/// once the day is fully loaded.
class PhoneDayHeader extends SliverPersistentHeaderDelegate {
  final DateTime day;
  final double? total;
  final AppLocalizations l10n;

  PhoneDayHeader(this.day, this.total, this.l10n);

  @override
  double get minExtent => PhoneListMetrics.dayHeaderHeight;
  @override
  double get maxExtent => PhoneListMetrics.dayHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.colors;
    final style = TextStyle(fontSize: PhoneListMetrics.dayHeader, fontWeight: AppFontWeight.semibold, color: colors.textSecondary);
    final key = dayKey(day);
    return Semantics(
      header: true,
      child: Container(
        key: ValueKey('phoneList-day-$key'),
        color: colors.background,
        padding: const EdgeInsets.symmetric(horizontal: PhoneListMetrics.pagePadding),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(child: Text(dayHeaderLabel(l10n, day), style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (total != null) Text(Money.format(total!), key: ValueKey('phoneList-dayTotal-$key'), style: style),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(PhoneDayHeader oldDelegate) =>
      oldDelegate.day != day || oldDelegate.total != total || oldDelegate.l10n != l10n;
}

/// R9: nothing to show: an icon, one plain line, the primary action.
class PhoneListEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  final PhoneListAction? action;

  const PhoneListEmpty({super.key, required this.icon, required this.text, required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(PhoneListMetrics.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: PhoneListMetrics.emptyIcon, color: colors.textDisabled),
          const SizedBox(height: PhoneListMetrics.headerGap),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFontSize.f15, color: colors.textMuted)),
          if (action != null) ...[
            const SizedBox(height: PhoneListMetrics.pagePadding),
            FilledButton.icon(onPressed: action!.onPressed, icon: Icon(action!.icon), label: Text(action!.label)),
          ],
        ],
      ),
    );
  }
}

/// R9: the first page failed: the message and Retry.
class PhoneListError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const PhoneListError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FirestoreErrorView(error: error),
        OutlinedButton(onPressed: onRetry, child: Text(context.l10n.common_retry)),
      ],
    );
  }
}

/// R10: the fallback under the last row while more pages exist.
class PhoneListLoadMore extends StatelessWidget {
  final bool loading;
  final VoidCallback onLoadMore;

  const PhoneListLoadMore({super.key, required this.loading, required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PhoneListMetrics.pagePadding),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: onLoadMore,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppSizes.minTapTarget)),
                child: Text(context.l10n.reports_loadMore),
              ),
      ),
    );
  }
}
