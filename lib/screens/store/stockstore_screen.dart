import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/product_catalog_side_panel.dart';
import '../../widgets/shell/page_header.dart';
import '../../widgets/list_page_bar.dart';
import '../../config/app_limits.dart';
import '../../config/app_timeouts.dart';
import '../../navigation/app_destinations.dart';
import '../../widgets/product_thumbnail.dart';
import '../../services/product_catalog_service.dart';
import '../products/add_edit_product_screen.dart';
import '../products/add_batch_screen.dart';
import '../products/view_batches_screen.dart';
import '../products/move_expired_to_stock_dialog.dart';
import '../products/stock_alerts_screen.dart';
import '../dashboard/notification_bell.dart';
import 'release_to_shop_flow.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../services/trash_service.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_layout.dart';
import '../../widgets/phone_list/phone_list_scaffold.dart';
import '../../widgets/phone_list/phone_quick_chips.dart';
import '../../widgets/phone_list/record_tile.dart';
import '../products/product_phone_parts.dart';
import '../../utils/app_clock.dart';
import '../../ui/polish/app_status.dart';
import '../../ui/polish/flat_stat_card.dart';
import '../../theme/polish_metrics.dart';

class StockStoreScreen extends StatefulWidget {
  const StockStoreScreen({super.key});

  @override
  State<StockStoreScreen> createState() => _StockStoreScreenState();
}

class _StockStoreScreenState extends State<StockStoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _bellKey = GlobalKey();

  // Grid (image cards) vs a more compact list view - matches Sellable
  // Products.
  bool _isGridView = true;

  // Everything the catalog view currently wants to see, in one place -
  // matches Sellable Products, same reasoning. Uses the service's own
  // default page size, so a small catalog never shows pagination
  // controls at all.
  ProductCatalogQuery _query = const ProductCatalogQuery(pageSize: kProductCatalogDefaultPageSize);

  // PAGE2: PC/tablet pages the shared catalogue with ListPageBar (10/25/50,
  // default 25); the phone keeps _query.pageSize for its scroll steps.
  int _widePageSize = AppLimits.pageSize;
  // PAGE2: the PC/tablet search applies 300 ms after typing stops.
  Timer? _searchDebounce;

  // PH7a (phones): how many pages the list shows (R10: every page reached
  // so far); back to one whenever the query changes.
  int _phonePages = 1;

  // Money formatter with thousand separator

  @override
  void initState() {
    super.initState();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      Provider.of<ProductProvider>(context, listen: false).listenToProducts(facilityId);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _manualRefresh() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null) {
      await Provider.of<ProductProvider>(context, listen: false).fetchProducts(facilityId);
    }
  }

  String _categoryOf(Product p) => p.category.isNotEmpty ? p.category : 'Uncategorized';

  // _getProductStatus's 'text' is also what the counts and the status filter
  // use, so it stays English; this is what a status dot shows.
  String _statusLabel(String status) => switch (status) {
        'Not Stocked' => context.l10n.products_statusNotStocked,
        'Depleted' => context.l10n.products_statusDepleted,
        'Expired' => context.l10n.products_statusExpired,
        'Low Stock' => context.l10n.products_statusLowStock,
        'Reorder Soon' => context.l10n.products_statusReorderSoon,
        'Unknown' => context.l10n.products_statusUnknown,
        'Expiring Soon' => context.l10n.products_statusExpiringSoon,
        'Active' => context.l10n.products_statusActive,
        _ => status,
      };

  Widget _buildSummaryMetrics({
    required int totalCount,
    required Map<String, int> statusCounts,
    required double totalStockValue,
  }) {
    // POL5 (owner note 1): five flat figure cards, as on Products; In stock
    // is neutral, no card is coloured. The counts are unchanged.
    final cards = [
      FlatStatCard(label: context.l10n.products_totalProducts, value: '$totalCount'),
      FlatStatCard(
        label: context.l10n.products_statusInStock,
        // 'Unknown' (no expiry set at all) is still genuinely in stock
        // and sellable - just missing expiry information - so it counts
        // here alongside 'Active' instead of vanishing from the summary.
        value: '${(statusCounts['Active'] ?? 0) + (statusCounts['Unknown'] ?? 0)}',
      ),
      FlatStatCard(label: context.l10n.products_statusLowStock, value: '${statusCounts['Low Stock'] ?? 0}'),
      FlatStatCard(label: context.l10n.products_statusDepleted, value: '${statusCounts['Depleted'] ?? 0}'),
      FlatStatCard(label: context.l10n.store_stockValue, value: Money.format(totalStockValue)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same smooth 2/3/4/5-column responsive progression as
        // products_screen.dart, so both screens' metric rows behave
        // identically across screen sizes. POL5: rows of the card's own
        // height (a fixed grid cell cut a flat card short).
        final perRow = (constraints.maxWidth / 160).floor().clamp(2, 5);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i += perRow) ...[
              if (i > 0) const SizedBox(height: PolishMetrics.gapInGroup),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = i; j < i + perRow; j++) ...[
                    if (j > i) const SizedBox(width: PolishMetrics.gapInGroup),
                    Expanded(child: j < cards.length ? cards[j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// POL5: the status as the one status style, the dot in the state of its
  /// STORED value (stockAppStatus), the word translated.
  Widget _statusDot(String stored) => StatusDot(status: stockAppStatus(stored), label: _statusLabel(stored));

  /// POL5 (owner note 3): Restock shelf is a NEUTRAL dot with its word, not
  /// a warning, until the owner decides the warehouse-versus-shelf low-stock
  /// rule. What raises the alert is unchanged.
  Widget _restockDot() => StatusDot(status: AppStatus.neutral, label: context.l10n.products_restockShelf);

  Map<String, dynamic> _getProductStatus(Product product) {
    // A brand-new product that's never carried any stock reads very
    // differently from one that genuinely ran out - shown neutrally
    // rather than as an alarming "Depleted", matching the agreed design.
    if (product.primaryStatus == ProductStockStatus.neverStocked) {
      return {
        'text': 'Not Stocked',
        'color': context.colors.textHint,
        'icon': Icons.inventory_2_outlined,
      };
    }

    // Nothing left anywhere - the most actionable state (needs
    // restocking), so it takes priority even over an old expiry date
    // still sitting on the record from whatever batch was last here.
    if (product.primaryStatus == ProductStockStatus.depleted) {
      return {
        'text': 'Depleted',
        'color': context.colors.danger,
        'icon': Icons.remove_shopping_cart_outlined,
      };
    }

    if (product.expiry != null && product.expiry!.isBefore(AppClock.now())) {
      return {
        'text': 'Expired',
        'color': context.colors.danger,
        'icon': Icons.warning,
      };
    }

    // Same primaryStatus every screen reads, so "Low Stock" (and now
    // "Reorder Soon") never mean something different depending on which
    // screen you're looking at.
    if (product.primaryStatus == ProductStockStatus.lowStock) {
      return {
        'text': 'Low Stock',
        'color': context.colors.warning,
        'icon': Icons.trending_down,
      };
    }

    // A real, separate signal from Low Stock - sales can continue
    // normally, but it's time to start planning a purchase. Distinct
    // color (amber, not orange) so it doesn't read as urgent as Low
    // Stock/Depleted at a glance.
    if (product.primaryStatus == ProductStockStatus.reorderSoon) {
      return {
        'text': 'Reorder Soon',
        'color': context.colors.warning,
        'icon': Icons.hourglass_bottom,
      };
    }

    if (product.expiry == null) {
      return {
        'text': 'Unknown',
        'color': context.colors.textHint,
        'icon': Icons.help_outline,
      };
    }

    final now = AppClock.now();
    final expiryDate = product.expiry!;

    if (expiryDate.difference(now).inDays <= 30) {
      return {
        'text': 'Expiring Soon',
        'color': context.colors.warning,
        'icon': Icons.schedule,
      };
    }

    return {
      'text': 'Active',
      'color': context.colors.success,
      'icon': Icons.check_circle,
    };
  }

  /// [onDeleted] (the phone's details page closing) runs once it is gone.
  Future<void> _deleteProduct(String productId, {VoidCallback? onDeleted}) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.products_confirmDeleteTitle,
            style: TextStyle(color: context.colors.primary)),
        content: Text(context.l10n.products_confirmDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
            ),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.background,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Read before the await: Undo may run after this screen is gone.
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    try {
      await provider.deleteProduct(context, productId);
      onDeleted?.call();
      // deleteProduct moves the product to Trash (a soft delete), so Undo
      // puts it back with the Trash screen's own restore, as on Products.
      AppFeedback.undo(
        L10n.current.products_movedToTrash,
        onUndo: () => _undoDeleteProduct(facilityId, productId),
      );
    } catch (e, st) {
      AppFeedback.error(L10n.current.products_deleteFailed, error: e, stackTrace: st);
    }
  }

  static Future<void> _undoDeleteProduct(String? facilityId, String productId) async {
    if (facilityId == null || facilityId.isEmpty) return;
    try {
      await TrashService.restoreById(
        facilityId: facilityId,
        trashCollection: Collections.trashProducts,
        liveCollection: Collections.products,
        id: productId,
      );
      AppFeedback.success(L10n.current.products_restored);
    } catch (e, st) {
      AppFeedback.error(L10n.current.products_restoreFailed, error: e, stackTrace: st);
    }
  }

  // The release flow itself (quantity prompt, expired-stock warning, the move)
  // lives in release_to_shop_flow.dart so Product Alerts' "Move to shelf"
  // button runs exactly the same thing.
  Future<void> _releaseToShop(Product product) => releaseProductToShop(context, product);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final allProducts = provider.products;

    // This screen's normal purpose is "something in the warehouse"
    // (stockQty > 0).
    bool belongsOnThisScreen(Product p) => p.stockQty > 0;
    bool productIsDepleted(Product p) => p.stockQty <= 0 && p.sellableQty <= 0;

    final baseProducts = allProducts.where((p) {
      if (productIsDepleted(p)) return true;
      return belongsOnThisScreen(p);
    }).toList();

    final categoriesInData = <String>{for (final p in baseProducts) _categoryOf(p)};

    final categoryCounts = <String, int>{};
    for (final p in baseProducts) {
      if (productIsDepleted(p)) continue;
      final cat = _categoryOf(p);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final statusCounts = <String, int>{};
    for (final p in baseProducts) {
      final status = _getProductStatus(p)['text'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    // What "All Products" / "All Status" actually displays - now
    // matches baseProducts.length exactly, since ProductCatalogService's
    // "All" genuinely means everything, Depleted included.
    final visibleProductCount = baseProducts.length;

    final result = ProductCatalogService.run(
      query: _query.copyWith(pageSize: _widePageSize),
      allProducts: allProducts,
      belongsOnThisScreen: belongsOnThisScreen,
      isDepleted: productIsDepleted,
      statusResolver: _getProductStatus,
    );

    final panel = ProductCatalogSidePanel(
      selectedGroup: _query.selectedGroup,
      selectedCategory: _query.selectedCategory,
      selectedStatus: _query.selectedStatus,
      onGroupChanged: (group) => setState(
          () => _query = _query.copyWith(selectedGroup: group, selectedCategory: 'All', page: 1)),
      onCategoryChanged: (category) =>
          setState(() => _query = _query.copyWith(selectedCategory: category, page: 1)),
      onStatusChanged: (status) => setState(() => _query = _query.copyWith(selectedStatus: status, page: 1)),
      extraCategoriesInData: categoriesInData,
      totalCount: visibleProductCount,
      categoryCounts: categoryCounts,
      statusCounts: statusCounts,
      primaryColor: context.colors.primary,
      accentColor: context.colors.accent,
    );

    final noFiltersActive = _query.searchQuery.isEmpty &&
        _query.selectedGroup == 'All' &&
        _query.selectedCategory == 'All' &&
        _query.selectedStatus == 'All';

    final totalStockValue = baseProducts.fold<double>(0, (sum, p) => sum + (p.stockQty * p.buyPrice));

    if (AppLayout.isPhone(context)) {
      return _buildPhone(
        provider: provider,
        belongsOnThisScreen: belongsOnThisScreen,
        isDepleted: productIsDepleted,
        categoriesInData: categoriesInData,
        statusCounts: statusCounts,
        totalCount: visibleProductCount,
        totalStockValue: totalStockValue,
        noFiltersActive: noFiltersActive,
      );
    }

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
          child: _buildSummaryMetrics(
            totalCount: visibleProductCount,
            statusCounts: statusCounts,
            totalStockValue: totalStockValue,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
          child: _buildToolbar(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              context.l10n.store_productsInStock(result.totalCount),
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: result.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: AppIconSize.i64, color: context.colors.textDisabled),
                      const SizedBox(height: AppSpacing.s16),
                      Text(
                        noFiltersActive
                            ? context.l10n.store_empty
                            // PAGE2: a search names what was searched.
                            : _query.searchQuery.isNotEmpty
                                ? context.l10n.catalogue_emptySearch(_query.searchQuery)
                                : context.l10n.products_noMatches,
                        style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: _manualRefresh,
                  child: _isGridView ? _buildProductsGrid(result.items) : _buildProductsListView(result.items),
                ),
        ),
        // PAGE2: the shared page bar (the catalogue is in memory, so the
        // range can say the total).
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, 0),
          child: _buildPageBar(result),
        ),
      ],
    );

    final isWide = context.screenWidth >= AppBreakpoints.medium;

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: isWide ? null : Drawer(width: 324, child: panel),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                panel,
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  // A responsive grid that scales smoothly with available width. No
  // upper cap on column count or overall width anymore - the side
  // panel now provides the page's own left-side structure, so the
  // grid expands naturally to fill whatever space remains to its
  // right. When there are fewer products than columns, they're still
  // centered at their natural card width via Wrap instead of
  // stretched into a mostly-empty grid row or left-pinned within it.
  // Same approach as Sellable Products, for consistency between the
  // two catalog screens. Widened from 360 to 460 to comfortably fit
  // the 130px-wide image alongside its info column.
  static const double _idealProductCardWidth = 460.0;

  Widget _buildProductsGrid(List<Product> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _idealProductCardWidth).floor().clamp(1, 999);

        if (products.length < columns) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              alignment: WrapAlignment.center,
              children: products
                  .map((p) => SizedBox(width: _idealProductCardWidth, child: _buildProductCard(p)))
                  .toList(),
            ),
          );
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.all(AppSpacing.s16),
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.s12,
          mainAxisSpacing: AppSpacing.s12,
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  // A denser, more scannable alternative to the image cards - matches
  // Sellable Products' own list row, with Stock (not Sellable) as the
  // primary value and Release (not Sell) as this screen's own action.
  Widget _buildProductsListView(List<Product> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) => _buildProductListRow(products[index]),
    );
  }

  Widget _buildProductListRow(Product p) {
    final status = _getProductStatus(p);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(PolishMetrics.cardRadius),
        border: Border.all(color: context.colors.border, width: PolishMetrics.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductThumbnail.square(
            imageUrl: p.imageUrl,
            size: 56,
            backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
            iconColor: context.colors.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14_5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${context.l10n.productCategoryLabel(p.category)} • ${context.l10n.productTypeLabel(p.type)}',
                    style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s4,
                  children: [
                    _statusDot(status['text'] as String),
                    if (p.hasRestockShelfAlert) _restockDot(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _labelValue(context.l10n.products_stock, '${p.stockQty} ${context.l10n.productUnitLabel(p.unit)}'),
          ),
          Expanded(
            flex: 2,
            child: _labelValue(context.l10n.products_price, Money.unitPrice(p.sellPrice)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin)
                IconButton(
                  onPressed: () {
                    showAddEditProductScreen(context, product: p);
                  },
                  icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: AppIconSize.i20),
                  tooltip: context.l10n.common_edit,
                ),
              if (isAdmin && p.stockQty > 0)
                IconButton(
                  onPressed: () => _releaseToShop(p),
                  icon: Icon(Icons.upload, color: context.colors.primary, size: AppIconSize.i20),
                  tooltip: context.l10n.products_release,
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.colors.primary),
                tooltip: context.l10n.common_moreActions,
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p, moveToStockAction: MoveToStockAction.removeFromSellable);
                  } else if (value == 'delete') {
                    _deleteProduct(p.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'add_batch', child: Text(context.l10n.products_addNewBatch)),
                  PopupMenuItem(value: 'view_batches', child: Text(context.l10n.products_viewBatches)),
                  if (isAdmin)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.common_delete, style: TextStyle(color: context.colors.dangerSoft)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasStockAlerts = StockAlertsScreen.hasAnyAlert(Provider.of<ProductProvider>(context).products);

    // UX1a: the shared PC/tablet header (title left, actions right). LAY5's
    // rule holds through PageHeader: no back arrow at the shell's top level;
    // below medium the drawer (the filter panel) gets its menu button, which
    // wins over a back arrow.
    return PageHeader(
      title: context.l10n.store_title,
      subtitle: context.l10n.store_subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.common_refresh,
          onPressed: _manualRefresh,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: _bellKey,
              icon: const Icon(Icons.notifications_none),
              tooltip: context.l10n.products_stockAlerts,
              onPressed: () async {
                final isWideScreen = context.screenWidth >= AppBreakpoints.medium;
                if (isWideScreen) {
                  // PH8a: the same anchored panel as the notifications bell.
                  // UX4: its View all opens in the shell (Stock Store highlighted).
                  await showAnchoredDropdown(context,
                      anchorKey: _bellKey,
                      child: StockAlertsScreen(
                          isDropdown: true,
                          onViewAll: StockAlertsScreen.viewAllFrom(context, highlight: AppDestination.stockStore)));
                } else {
                  await StockAlertsScreen.open(context, highlight: AppDestination.stockStore);
                }
              },
            ),
            if (hasStockAlerts)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: context.colors.danger, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.s4),
        // Creating a product is admin-only (owner decision, E4d-2); an
        // assistant still adds batches to existing products.
        if (Provider.of<UserRoleProvider>(context).isAdmin)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () => showAddEditProductScreen(context),
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: Text(context.l10n.products_addProduct),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
            ),
          ),
        ),
      ],
    );
  }

  void _onWideSearchChanged(String value) {
    setState(() {}); // the clear button
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppTimeouts.pagedSearchDebounce, () {
      if (mounted) setState(() => _query = _query.copyWith(searchQuery: value.trim(), page: 1));
    });
  }

  void _clearWideSearch() {
    _searchDebounce?.cancel();
    if (_searchController.text.isEmpty && _query.searchQuery.isEmpty) return;
    setState(() {
      _searchController.clear();
      _query = _query.copyWith(searchQuery: '', page: 1);
    });
  }

  Widget _buildPageBar(ProductCatalogResult result) {
    final start = (result.currentPage - 1) * _widePageSize + 1;
    final end = start + result.items.length - 1;
    return ListPageBar(
      emptyText: context.l10n.products_noMatches,
      rangeText: result.items.isEmpty ? null : context.l10n.products_showingRange(result.totalCount, start, end),
      itemCount: result.items.length,
      pageSize: _widePageSize,
      currentPage: result.currentPage,
      hasPreviousPage: result.currentPage > 1,
      hasNextPage: result.currentPage < result.totalPages,
      isLoading: false,
      showLoadingSpinner: false,
      onPageSize: (size) => setState(() {
        _widePageSize = size;
        _query = _query.copyWith(page: 1);
      }),
      onPrevious: () => setState(() => _query = _query.copyWith(page: result.currentPage - 1)),
      onNext: () => setState(() => _query = _query.copyWith(page: result.currentPage + 1)),
    );
  }

  Widget _buildToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    return Row(
      children: [
        Expanded(
          // PAGE2: Escape clears the search, as the clear button does.
          child: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clearWideSearch},
            child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.store_searchHint,
              hintStyle: const TextStyle(fontSize: AppFontSize.f13),
              prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
              filled: true,
              fillColor: context.colors.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
              border: border,
              enabledBorder: border,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: AppIconSize.i18),
                      onPressed: _clearWideSearch,
                    ),
            ),
            onChanged: _onWideSearchChanged,
          ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        _buildSortDropdown(),
        const SizedBox(width: AppSpacing.s10),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductSortOption>(
          value: _query.sortOption,
          icon: Icon(AppIcons.sort, size: AppIconSize.i18, color: context.colors.primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
          items: ProductSortOption.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _query = _query.copyWith(sortOption: value, page: 1));
          },
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleButton(Icons.grid_view_rounded, true),
          _viewToggleButton(Icons.view_list_rounded, false),
        ],
      ),
    );
  }

  Widget _viewToggleButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;
    return InkWell(
      onTap: () => setState(() => _isGridView = isGrid),
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.s4),
        padding: const EdgeInsets.all(AppSpacing.s6),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Icon(icon, size: AppIconSize.i18, color: isSelected ? context.colors.onPrimary : context.colors.textMuted),
      ),
    );
  }



  Widget _labelValue(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.s2),
        Text(
          value,
          style: TextStyle(
              fontSize: AppFontSize.f14, fontWeight: AppFontWeight.bold, color: valueColor ?? context.colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product p) {
    final status = _getProductStatus(p);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(PolishMetrics.cardRadius),
        border: Border.all(color: context.colors.border, width: PolishMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Image + info side by side - the image's fixed height
          // is sized to roughly match the info content alone (not the
          // actions below), since the actions row is now a separate,
          // full-width section underneath both rather than packed
          // into the same Row - this is what lets the image end right
          // where the buttons begin instead of running alongside them.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: ProductThumbnail(
                  imageUrl: p.imageUrl,
                  width: 140,
                  height: 175,
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                  iconColor: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${context.l10n.productCategoryLabel(p.category)} • ${context.l10n.productTypeLabel(p.type)}',
                      style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Wrap(
                      spacing: AppSpacing.s6,
                      runSpacing: AppSpacing.s4,
                      children: [
                        _statusDot(status['text'] as String),
                        if (p.hasRestockShelfAlert) _restockDot(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s10),
                    // Stock / Price - Stock (not Sellable) is this
                    // screen's own primary concern, since this is
                    // the warehouse side of the catalog.
                    Row(
                      children: [
                        Expanded(
                          child: _labelValue(context.l10n.products_stock, '${p.stockQty} ${context.l10n.productUnitLabel(p.unit)}'),
                        ),
                        Expanded(child: _labelValue(context.l10n.products_price, Money.unitPrice(p.sellPrice))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      context.l10n.products_sellableBatch('${p.sellableQty}', context.l10n.productUnitLabel(p.unit), p.batchNo ?? '-'),
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.products_buyPrice(Money.unitPrice(p.buyPrice)),
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                              ),
                              if (p.expiry != null)
                                Text(
                                  context.l10n.products_expiryDate(AppDateFormat.date.format(p.expiry!)),
                                  style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                                ),
                            ],
                          ),
                        ),
                        // Overflow menu - batches (Add New Batch /
                        // View Batches / Move to Stock when
                        // relevant) plus, for an admin, Delete.
                        // Sits up here with the product's own
                        // details rather than down with Edit/
                        // Release, since those two are this
                        // screen's primary actions and deserve
                        // their own row without a third, less-used
                        // control crowding it.
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: context.colors.primary),
                          tooltip: context.l10n.common_moreActions,
                          onSelected: (value) {
                            if (value == 'add_batch') {
                              showAddBatchScreen(context, product: p);
                            } else if (value == 'view_batches') {
                              showViewBatchesScreen(context, product: p, moveToStockAction: MoveToStockAction.removeFromSellable);
                            } else if (value == 'delete') {
                              _deleteProduct(p.id);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'add_batch', child: Text(context.l10n.products_addNewBatch)),
                            PopupMenuItem(value: 'view_batches', child: Text(context.l10n.products_viewBatches)),
                            if (isAdmin)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.l10n.common_delete, style: TextStyle(color: context.colors.dangerSoft)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              if (isAdmin)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showAddEditProductScreen(context, product: p);
                    },
                    icon: Icon(Icons.edit_outlined, size: AppIconSize.i16, color: context.colors.primary),
                    label: Text(context.l10n.common_edit, style: TextStyle(color: context.colors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40)),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
                    ),
                  ),
                ),
              if (isAdmin && p.stockQty > 0) ...[
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload, size: AppIconSize.i16),
                    label: Text(context.l10n.products_release),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: AppSpacing.s10)),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return Color.alphaBlend(
                              context.colors.onPrimary.withValues(alpha: PolishMetrics.buttonHoverAlpha), context.colors.primary);
                        }
                        return context.colors.primary;
                      }),
                      foregroundColor: WidgetStateProperty.all(context.colors.background),
                    ),
                    onPressed: () => _releaseToShop(p),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PHONE (PH7a) ====================

  // docs/design/phone_list_pattern.md: the same live products, query, cards
  // and card actions as the layout above, as the standard phone list (as on
  // Products). A row gives the stored quantity, the stored value and the
  // expiry; the details page is the card's content and actions. The bell's
  // dropdown (for 900 px and wider) is the menu's Stock Alerts sheet.

  void _setPhoneQuery(ProductCatalogQuery query) => setState(() {
        _query = query;
        _phonePages = 1;
      });

  /// The card's status, with 'Active' read as the In Stock chip it is
  /// filtered by.
  RecordStatus _phoneStatus(Product p) {
    final status = _getProductStatus(p);
    final text = status['text'] as String;
    return RecordStatus.state(text == 'Active' ? context.l10n.products_statusInStock : _statusLabel(text), stockAppStatus(text));
  }

  Future<void> _openPhoneDetails(Product product) {
    final l10n = context.l10n;
    // Edit, Release and Delete are admin-only, as on the card.
    final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;
    return pushProductDetailsPage(
      context,
      productId: product.id,
      barActions: (pageContext, p) => [
        if (isAdmin) ...[
          IconButton(
            tooltip: l10n.common_edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showAddEditProductScreen(context, product: p),
          ),
          IconButton(
            tooltip: l10n.common_delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteProduct(p.id, onDeleted: () => Navigator.of(pageContext).pop()),
          ),
        ],
      ],
      body: (pageContext, p) => ProductDetailsBody(
        product: p,
        status: _phoneStatus(p),
        chips: [
          if (p.hasRestockShelfAlert)
            // POL5 (owner note 3): neutral until the warehouse-versus-shelf rule is decided.
            ProductInfoChip(label: l10n.products_restockShelf, icon: Icons.move_up, color: context.colors.textSecondary),
        ],
        figures: [
          (l10n.products_stock, '${p.stockQty} ${l10n.productUnitLabel(p.unit)}'),
          (l10n.products_price, Money.unitPrice(p.sellPrice)),
        ],
        lines: [
          l10n.products_sellableBatch('${p.sellableQty}', l10n.productUnitLabel(p.unit), p.batchNo ?? '-'),
          l10n.products_buyPrice(Money.unitPrice(p.buyPrice)),
          if (p.expiry != null) l10n.products_expiryDate(AppDateFormat.date.format(p.expiry!)),
        ],
        actions: [
          if (isAdmin && p.stockQty > 0)
            ProductPageAction(label: l10n.products_release, icon: Icons.upload, primary: true, onPressed: () => _releaseToShop(p)),
          ProductPageAction(
              label: l10n.products_addNewBatch, icon: Icons.playlist_add, onPressed: () => showAddBatchScreen(context, product: p)),
          ProductPageAction(
            label: l10n.products_viewBatches,
            icon: Icons.inventory_2_outlined,
            onPressed: () => showViewBatchesScreen(context, product: p, moveToStockAction: MoveToStockAction.removeFromSellable),
          ),
        ],
      ),
    );
  }

  Widget _storeTile(Product p) {
    final l10n = context.l10n;
    final status = _phoneStatus(p);
    final quantity = '${p.stockQty} ${l10n.productUnitLabel(p.unit)}';
    final value = Money.format(p.stockQty * p.buyPrice);
    return RecordTile(
      title: p.name,
      amount: quantity,
      details: [
        value,
        if (p.expiry != null) l10n.products_expiryDate(AppDateFormat.date.format(p.expiry!)),
      ],
      status: status,
      leading: ProductLeading(product: p),
      colorSeed: p.name,
      semanticsLabel: l10n.phoneList_productRowSemantics(p.name, quantity, value, status.label),
      onTap: () => _openPhoneDetails(p),
    );
  }

  Widget _buildPhone({
    required ProductProvider provider,
    required bool Function(Product) belongsOnThisScreen,
    required bool Function(Product) isDepleted,
    required Set<String> categoriesInData,
    required Map<String, int> statusCounts,
    required int totalCount,
    required double totalStockValue,
    required bool noFiltersActive,
  }) {
    final l10n = context.l10n;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    final pageSize = _query.pageSize ?? kProductCatalogDefaultPageSize;
    final shown = ProductCatalogService.run(
      query: _query.copyWith(page: 1, pageSize: pageSize * _phonePages),
      allProducts: provider.products,
      belongsOnThisScreen: belongsOnThisScreen,
      isDepleted: isDepleted,
      statusResolver: _getProductStatus,
    );
    // Today's primary action, admin-only (E4d-2), through the guard.
    final add = isAdmin
        ? PhoneListAction(label: l10n.products_addProduct, icon: Icons.add, onPressed: () => showAddEditProductScreen(context))
        : null;
    return PhoneListScaffold<Product>(
          // RV2b: its rows show photos (RevealImage).
          imageGrace: true,
      title: l10n.store_title,
      menu: [
        PhoneListMenuItem(label: l10n.products_stockAlerts, icon: Icons.notifications_none, onSelected: () => showStockAlertsSheet(context)),
      ],
      menuBadge: StockAlertsScreen.hasAnyAlert(provider.products),
      searchController: _searchController,
      searchHint: l10n.store_searchHint,
      onSearchChanged: (val) => _setPhoneQuery(_query.copyWith(searchQuery: val.trim(), page: 1)),
      onSearchClosed: () {
        _searchController.clear();
        _setPhoneQuery(_query.copyWith(searchQuery: '', page: 1));
      },
      quickChips: PhoneQuickChips(
        key: const ValueKey('phoneList-quickChips'),
        values: kProductStatusChips,
        selected: _query.selectedStatus,
        label: (v) => productStatusChipLabel(l10n, v),
        onSelected: (v) => _setPhoneQuery(_query.copyWith(selectedStatus: v, page: 1)),
      ),
      filtersActive: productFiltersActive(_query),
      onFilter: () async {
        final query = await showProductFilterSheet(context, query: _query, categoriesInData: categoriesInData);
        if (query != null) _setPhoneQuery(query);
      },
      appliedFilters: productAppliedFilters(l10n, _query, _setPhoneQuery),
      summaryLine: l10n.phoneList_productsSummaryLine(totalCount, Money.format(totalStockValue)),
      onSummary: () => showProductSummarySheet(context,
          totalCount: totalCount, statusCounts: statusCounts, valueLabel: l10n.store_stockValue, stockValue: totalStockValue),
      items: shown.items,
      idOf: (p) => p.id,
      // Not grouped by day (R5): a product has no date of its own here.
      dateOf: (p) => p.updatedAt ?? DateTime(0),
      amountOf: (p) => 0,
      grouped: false,
      tileBuilder: (context, p, {required grouped}) => _storeTile(p),
      loading: !provider.loaded,
      firstPageAnswered: provider.loaded || provider.listenError != null,
      error: provider.listenError,
      onRetry: provider.retryListening,
      emptyIcon: Icons.inventory_2,
      emptyText: noFiltersActive ? l10n.store_empty : l10n.products_noMatches,
      fab: add,
      emptyAction: add,
      hasMore: shown.totalCount > shown.items.length,
      loadingMore: false,
      onLoadMore: () => setState(() => _phonePages++),
      // Pull to refresh (R8): today's Refresh (the list itself is live).
      onRefresh: _manualRefresh,
    );
  }
}
