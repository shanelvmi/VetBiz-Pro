import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/money.dart';
import '../../constants/product_categories.dart';
import '../../l10n/l10n.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../services/product_catalog_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/phone_list/phone_filter_sheet.dart';
import '../../widgets/phone_list/phone_list_scaffold.dart';
import '../../widgets/phone_list/phone_summary_sheet.dart';
import '../../widgets/phone_list/record_tile.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/reveal/reveal_image.dart';
import 'stock_alerts_screen.dart';

// PH7a (docs/design/phone_list_pattern.md): what Products and Stock Store
// share on a phone: a product's photo as a row's leading, and its details
// page, built from the wide card's content and actions (the two screens
// have no details panel: the card holds everything).

/// The stored stock statuses the side panel filters by, in its order: the
/// phone's quick chips (R3).
const kProductStatusChips = ['All', 'Active', 'Low Stock', 'Reorder Soon', 'Depleted', 'Expired'];

/// A quick chip's label: the side panel's.
String productStatusChipLabel(AppLocalizations l10n, String status) => switch (status) {
      'All' => l10n.common_all,
      'Active' => l10n.products_statusInStock,
      'Low Stock' => l10n.products_statusLowStock,
      'Reorder Soon' => l10n.products_statusReorderSoon,
      'Depleted' => l10n.products_statusDepleted,
      'Expired' => l10n.products_statusExpired,
      _ => status,
    };

/// A product's 40 px leading on a phone row (R6): its photo fading in over the
/// initials (RevealImage), or the name's initials on a tint when it has no
/// photo or the photo fails.
class ProductLeading extends StatelessWidget {
  final Product product;

  const ProductLeading({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = PhoneListMetrics.leading;
    final radius = BorderRadius.circular(PhoneListMetrics.productThumbRadius);
    Widget initials() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: leadingColorFor(colors, product.name).withValues(alpha: PhoneListMetrics.leadingAlpha),
            borderRadius: radius,
          ),
          child: Text(
            InitialsAvatar.initialsFor(product.name),
            style: TextStyle(
              fontSize: PhoneListMetrics.leadingText,
              fontWeight: AppFontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        );
    final url = product.imageUrl;
    return SizedBox(
      key: ValueKey('productLeading-${product.id}'),
      width: size,
      height: size,
      child: url == null || url.isEmpty
          ? initials()
          : ClipRRect(
              borderRadius: radius,
              // RV2b: the initials at once, the photo fading in over them.
              child: RevealImage(url: url, width: size, height: size, placeholder: initials()),
            ),
    );
  }
}

/// One action of a product's details page: a full-width button at least 48
/// high (the primary one filled).
class ProductPageAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  const ProductPageAction({required this.label, required this.icon, required this.onPressed, this.primary = false});
}

/// Opens a product's details page (R7): a full page over the list, the
/// card's content under an app bar with the product's name. The product is
/// read live from the products already loaded (no new listener), so an edit
/// shows at once; [actions] and [barActions] are built for it each time.
Future<void> pushProductDetailsPage(
  BuildContext context, {
  required String productId,
  required Widget Function(BuildContext pageContext, Product product) body,
  required List<Widget> Function(BuildContext pageContext, Product product) barActions,
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (pageContext) => Consumer<ProductProvider>(
      builder: (pageContext, provider, _) {
        final product = provider.products.where((p) => p.id == productId).firstOrNull;
        return Scaffold(
          key: const ValueKey('phoneList-details'),
          backgroundColor: pageContext.colors.background,
          appBar: AppBar(
            title: Text(product?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: product == null ? null : barActions(pageContext, product),
          ),
          // Gone (moved to Trash elsewhere): an empty page; Back leaves.
          body: product == null ? const SizedBox.shrink() : body(pageContext, product),
        );
      },
    ),
  ));
}

/// The card's content, one column on a phone: the photo, the name, the
/// category and type, the chips, the two key figures, the other lines, then
/// the actions.
class ProductDetailsBody extends StatelessWidget {
  final Product product;
  final RecordStatus status;
  final List<Widget> chips;
  final List<(String label, String value)> figures;
  final List<String> lines;
  final List<ProductPageAction> actions;

  const ProductDetailsBody({
    super.key,
    required this.product,
    required this.status,
    required this.chips,
    required this.figures,
    required this.lines,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    const gap = SizedBox(height: PhoneListMetrics.detailsGap);
    final text = TextStyle(fontSize: PhoneListMetrics.detailsText, color: colors.textSoft);
    return ListView(
      padding: const EdgeInsets.all(PhoneListMetrics.pagePadding),
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ProductThumbnail(
            imageUrl: product.imageUrl,
            width: constraints.maxWidth,
            height: PhoneListMetrics.detailsImageHeight,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            backgroundColor: colors.primary.withValues(alpha: AppAlpha.a10),
            iconColor: colors.primary,
          ),
        ),
        gap,
        Text(
          product.name,
          style: TextStyle(fontSize: PhoneListMetrics.detailsTitle, fontWeight: AppFontWeight.bold, color: colors.textPrimary),
        ),
        Text(
          '${l10n.productCategoryLabel(product.category)} • ${l10n.productTypeLabel(product.type)}',
          style: TextStyle(fontSize: PhoneListMetrics.detailsText, color: colors.textMuted),
        ),
        gap,
        Wrap(
          spacing: PhoneListMetrics.chipGap,
          runSpacing: PhoneListMetrics.chipGap,
          children: [StatusChip(status: status), ...chips],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in figures)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: PhoneListMetrics.detailLabel, color: colors.textMuted)),
                    Text(
                      value,
                      style: TextStyle(fontSize: PhoneListMetrics.detailsValue, fontWeight: AppFontWeight.bold, color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        gap,
        for (final line in lines) Text(line, style: text),
        const SizedBox(height: PhoneListMetrics.pagePadding),
        for (final a in actions) ...[
          SizedBox(
            width: double.infinity,
            child: a.primary
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.minTapTarget)),
                    onPressed: a.onPressed,
                    icon: Icon(a.icon),
                    label: Text(a.label),
                  )
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.minTapTarget)),
                    onPressed: a.onPressed,
                    icon: Icon(a.icon),
                    label: Text(a.label),
                  ),
          ),
          const SizedBox(height: PhoneListMetrics.chipGap),
        ],
      ],
    );
  }
}

/// A chip of text and an icon on a tint (the card's Restock Shelf), at 12.
class ProductInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const ProductInfoChip({super.key, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PhoneListMetrics.chipPaddingH, vertical: PhoneListMetrics.chipPaddingV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: PhoneListMetrics.chipAlpha),
        borderRadius: BorderRadius.circular(PhoneListMetrics.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.i14, color: color),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(label, style: TextStyle(fontSize: PhoneListMetrics.chip, fontWeight: AppFontWeight.semibold, color: color)),
          ),
        ],
      ),
    );
  }
}

/// The stock alerts (the old bell's dropdown, StockAlertsScreen's compact
/// view with its own header, Close and View all) as a bottom sheet on a
/// phone: the dropdown never showed on a phone (it is for 900 px and wider).
Future<void> showStockAlertsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r12))),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * AppSheetMetrics.sheetMaxHeightFactor),
    builder: (_) => const SafeArea(top: false, child: StockAlertsScreen(isDropdown: true)),
  );
}

/// The Filter sheet of a product list (R3): the side panel's categories and
/// the sort menu, applied to [query]. Returns the new query, or null when
/// the sheet was closed without Apply.
Future<ProductCatalogQuery?> showProductFilterSheet(
  BuildContext context, {
  required ProductCatalogQuery query,
  required Set<String> categoriesInData,
}) async {
  final l10n = context.l10n;
  final values = await showPhoneFilterSheet(context, fields: {
    'category': PhoneFilterField(
      title: l10n.common_category,
      // The side panel's categories, group by group, with any in use that
      // the list does not know.
      options: [
        'All',
        for (final g in kProductCategoryGroups.keys)
          ...{...kProductCategoryGroups[g]!, ...categoriesInData.where((c) => groupOfCategory(c) == g)},
      ],
      label: (v) => v == 'All' ? l10n.products_allProducts : l10n.productCategoryLabel(v),
      defaultValue: 'All',
    ),
    'sort': PhoneFilterField(
      title: l10n.phoneList_sort,
      options: [for (final s in ProductSortOption.values) s.name],
      label: (v) => ProductSortOption.values.byName(v).label,
      defaultValue: ProductSortOption.nameAsc.name,
    ),
  }, values: {
    'category': query.selectedCategory,
    'sort': query.sortOption.name,
  });
  if (values == null) return null;
  final category = values['category']!;
  return query.copyWith(
    // As the side panel: a category selects its group too.
    selectedGroup: category == 'All' ? 'All' : groupOfCategory(category),
    selectedCategory: category,
    sortOption: ProductSortOption.values.byName(values['sort']!),
    page: 1,
  );
}

/// Whether [query] has a filter the Filter sheet set.
bool productFiltersActive(ProductCatalogQuery query) =>
    query.selectedCategory != 'All' || query.sortOption != ProductSortOption.nameAsc;

/// The Filter sheet's choices as removable chips; [onChanged] gets the query
/// without the removed one.
List<PhoneAppliedFilter> productAppliedFilters(
  AppLocalizations l10n,
  ProductCatalogQuery query,
  ValueChanged<ProductCatalogQuery> onChanged,
) =>
    [
      if (query.selectedCategory != 'All')
        PhoneAppliedFilter(
          l10n.common_filterValue(l10n.common_category, l10n.productCategoryLabel(query.selectedCategory)),
          () => onChanged(query.copyWith(selectedGroup: 'All', selectedCategory: 'All', page: 1)),
        ),
      if (query.sortOption != ProductSortOption.nameAsc)
        PhoneAppliedFilter(
          l10n.common_filterValue(l10n.phoneList_sort, query.sortOption.label),
          () => onChanged(query.copyWith(sortOption: ProductSortOption.nameAsc, page: 1)),
        ),
    ];

/// The five cards as the Summary sheet's rows (R4); [valueLabel] names the
/// last card (the shelf's or the store's stock value).
void showProductSummarySheet(
  BuildContext context, {
  required int totalCount,
  required Map<String, int> statusCounts,
  required String valueLabel,
  required double stockValue,
}) {
  final l10n = context.l10n;
  showPhoneSummarySheet(context, rows: [
    (l10n.products_totalProducts, '$totalCount'),
    // 'Unknown' (no expiry) is in stock too, as on the cards.
    (l10n.products_statusInStock, '${(statusCounts['Active'] ?? 0) + (statusCounts['Unknown'] ?? 0)}'),
    (l10n.products_statusLowStock, '${statusCounts['Low Stock'] ?? 0}'),
    (l10n.products_statusDepleted, '${statusCounts['Depleted'] ?? 0}'),
    (valueLabel, Money.format(stockValue)),
  ]);
}
