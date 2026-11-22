import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// LAY6a: the page bar under a paged record list (the range shown, the page
/// size, previous / page / next), one widget for the record screens. It was
/// a Row copied into each screen and overflowed a narrow list (LAYOUT_DEFECTS
/// #13, #15): the range and the controls now share a line while they fit and
/// the controls wrap under the range when they do not. Clients and Debtors
/// use it now; the other lists adopt it in their own blocks.
class ListPageBar extends StatelessWidget {
  const ListPageBar({
    super.key,
    required this.emptyText,
    required this.itemCount,
    required this.pageSize,
    required this.currentPage,
    required this.hasPreviousPage,
    required this.hasNextPage,
    required this.isLoading,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    this.rangeText,
    this.pageText,
    this.extra,
    this.showLoadingSpinner = true,
  });

  /// Shown when the page holds nothing.
  final String emptyText;
  final int itemCount;
  final int pageSize;
  final int currentPage;
  final bool hasPreviousPage;
  final bool hasNextPage;
  final bool isLoading;
  final ValueChanged<int> onPageSize;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// LAY6c: a screen's own range and page wording (the Sales archive says
  /// "of N+" and "Page 1 of 3"); null: the common "Showing a to b" and
  /// "Page n", as before.
  final String? rangeText;
  final String? pageText;

  /// UX6: an extra control between the range and the page controls (the
  /// Notifications page's Load older); null: nothing, as before.
  final Widget? extra;

  /// PAGE1: false where the list itself shows the loading (PagedListBody's
  /// skeleton or dimmed page): Next is only disabled, no spinner.
  final bool showLoadingSpinner;

  /// The page sizes offered (as the screens offered them).
  static const pageSizes = [10, 25, 50];

  @override
  Widget build(BuildContext context) {
    final pageStart = itemCount == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final pageEnd = (currentPage - 1) * pageSize + itemCount;

    return Container(
      // Full width, as the Row was (the top border spans the list; the Wrap
      // needs the width to space the range and the controls apart).
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.s8,
        children: [
          Text(
            itemCount == 0 ? emptyText : rangeText ?? context.l10n.common_showingRange(pageStart, pageEnd),
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
          if (extra != null) extra!,
          // The controls wrap too (the page size above the arrows) on the
          // narrowest list at large text.
          Wrap(
            spacing: AppSpacing.s16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: pageSize,
                  items: pageSizes.map((n) => DropdownMenuItem(value: n, child: Text(context.l10n.common_perPage(n)))).toList(),
                  onChanged: (val) {
                    if (val != null) onPageSize(val);
                  },
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: hasPreviousPage ? onPrevious : null,
              ),
              Text(pageText ?? context.l10n.common_page(currentPage), style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: isLoading && showLoadingSpinner
                    ? const SizedBox(width: AppSpacing.s16, height: AppSpacing.s16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: hasNextPage && !isLoading ? onNext : null,
              ),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
