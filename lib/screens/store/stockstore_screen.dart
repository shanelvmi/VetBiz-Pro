import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/product_catalog_side_panel.dart';
import '../../widgets/product_thumbnail.dart';
import '../../services/product_catalog_service.dart';
import '../products/add_edit_product_screen.dart';
import '../products/add_batch_screen.dart';
import '../products/view_batches_screen.dart';
import '../products/stock_alerts_screen.dart';
import 'release_to_shop_flow.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../services/trash_service.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';

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

  /// Same anchored-dropdown pattern as the Dashboard's own bell and
  /// products_screen.dart - positioned relative to this bell's actual
  /// measured position, transparent barrier so it reads as a dropdown
  /// rather than a modal. Scoped to stock-only notifications throughout.
  Future<void> _showNotificationsDropdown(BuildContext context) async {
    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final bellPosition = renderBox.localToGlobal(Offset.zero);
    final bellSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    const panelWidth = 400.0;
    final left = (bellPosition.dx + panelWidth > screenSize.width - 16)
        ? screenSize.width - panelWidth - 16
        : bellPosition.dx;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: bellPosition.dy + bellSize.height + 8,
              left: left,
              child: Material(
                elevation: AppElevation.e8,
                borderRadius: BorderRadius.circular(AppRadius.r12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenSize.height * 0.75),
                    child: const StockAlertsScreen(isDropdown: true),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }

  String _categoryOf(Product p) => p.category.isNotEmpty ? p.category : 'Uncategorized';

  Widget _buildSummaryMetrics({
    required int totalCount,
    required Map<String, int> statusCounts,
    required double totalStockValue,
  }) {
    final metrics = [
      ('Total Products', '$totalCount', Icons.shopping_bag_outlined, context.colors.primary),
      (
        'In Stock',
        // 'Unknown' (no expiry set at all) is still genuinely in stock
        // and sellable - just missing expiry information - so it counts
        // here alongside 'Active' instead of vanishing from the summary.
        '${(statusCounts['Active'] ?? 0) + (statusCounts['Unknown'] ?? 0)}',
        Icons.check_circle_outline,
        context.colors.success,
      ),
      ('Low Stock', '${statusCounts['Low Stock'] ?? 0}', Icons.trending_down, context.colors.warning),
      ('Depleted', '${statusCounts['Depleted'] ?? 0}', Icons.remove_shopping_cart_outlined, context.colors.danger),
      ('Store Stock Value', Money.format(totalStockValue), Icons.account_balance_wallet_outlined, context.colors.accent),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same smooth 2/3/4/5-column responsive progression as
        // products_screen.dart, so both screens' metric rows behave
        // identically across screen sizes.
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 5);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount <= 2 ? 3.0 : 2.6,
          crossAxisSpacing: AppSpacing.s12,
          mainAxisSpacing: AppSpacing.s12,
          children: metrics.map((m) => _metricCard(m.$1, m.$2, m.$3, m.$4)).toList(),
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
        boxShadow: [
          BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: AppIconSize.i20),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f17)),
                ),
                Text(label,
                    style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

    if (product.expiry != null && product.expiry!.isBefore(DateTime.now())) {
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

    final now = DateTime.now();
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

  Future<void> _deleteProduct(String productId) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Delete',
            style: TextStyle(color: context.colors.primary)),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.background,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Read before the await: Undo may run after this screen is gone.
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    try {
      await provider.deleteProduct(context, productId);
      // deleteProduct moves the product to Trash (a soft delete), so Undo
      // puts it back with the Trash screen's own restore, as on Products.
      AppFeedback.undo(
        'Product moved to Trash',
        onUndo: () => _undoDeleteProduct(facilityId, productId),
      );
    } catch (e, st) {
      AppFeedback.error("Couldn't delete the product", error: e, stackTrace: st);
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
      AppFeedback.success('Product restored');
    } catch (e, st) {
      AppFeedback.error("Couldn't restore the product", error: e, stackTrace: st);
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
      query: _query,
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
              '${result.totalCount} product${result.totalCount == 1 ? '' : 's'} in stock',
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
                        noFiltersActive ? 'No products in stock store' : 'No products match your filters',
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
        if (result.needsPaginationControls)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s12),
            child: _buildPaginationControls(result),
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
    final statusColor = status['color'] as Color;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [
          BoxShadow(
              color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                Text('${p.category} \u2022 ${p.type}',
                    style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: AppAlpha.a10),
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                        border: Border.all(color: statusColor.withValues(alpha: AppAlpha.a40)),
                      ),
                      child: Text(status['text'] as String,
                          style: TextStyle(
                              color: statusColor, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold)),
                    ),
                    if (p.hasRestockShelfAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                        decoration: BoxDecoration(
                          color: context.colors.info.withValues(alpha: AppAlpha.a10),
                          borderRadius: BorderRadius.circular(AppRadius.r10),
                          border: Border.all(color: context.colors.info.withValues(alpha: AppAlpha.a40)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.move_up, size: 11, color: context.colors.infoStrong),
                            const SizedBox(width: AppSpacing.s3),
                            Text('Restock Shelf',
                                style: TextStyle(
                                    color: context.colors.infoStrong, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _labelValue('Stock', '${p.stockQty} ${p.unit}', valueColor: statusColor),
          ),
          Expanded(
            flex: 2,
            child: _labelValue('Price', Money.format(p.sellPrice)),
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
                  tooltip: 'Edit',
                ),
              if (isAdmin && p.stockQty > 0)
                IconButton(
                  onPressed: () => _releaseToShop(p),
                  icon: Icon(Icons.upload, color: context.colors.primary, size: AppIconSize.i20),
                  tooltip: 'Release',
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.colors.primary),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p, moveToStockLabel: 'Remove from Sellable');
                  } else if (value == 'delete') {
                    _deleteProduct(p.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'add_batch', child: Text('Add New Batch')),
                  const PopupMenuItem(value: 'view_batches', child: Text('View Batches')),
                  if (isAdmin)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: context.colors.dangerSoft)),
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

    return AppBar(
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Stock Store',
              style: TextStyle(
                  fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('Manage your inventory', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _manualRefresh,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: _bellKey,
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Stock Alerts',
              onPressed: () async {
                final isWideScreen = context.screenWidth >= AppBreakpoints.medium;
                if (isWideScreen) {
                  await _showNotificationsDropdown(context);
                } else {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StockAlertsScreen()));
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
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () => showAddEditProductScreen(context),
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: const Text('Add Product'),
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

  Widget _buildToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search stock, brand or batch...',
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
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = _query.copyWith(searchQuery: '', page: 1);
                      }),
                    ),
            ),
            onChanged: (val) => setState(() => _query = _query.copyWith(searchQuery: val.trim(), page: 1)),
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
          icon: Icon(Icons.swap_vert, size: AppIconSize.i18, color: context.colors.primary),
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

  Widget _buildPaginationControls(ProductCatalogResult result) {
    final pageSize = _query.pageSize ?? kProductCatalogDefaultPageSize;
    final start = (result.currentPage - 1) * pageSize + 1;
    final end = (start + result.items.length - 1).clamp(start, result.totalCount);

    const windowSize = 5;
    int windowStart = (result.currentPage - windowSize ~/ 2).clamp(1, result.totalPages);
    int windowEnd = (windowStart + windowSize - 1).clamp(1, result.totalPages);
    windowStart = (windowEnd - windowSize + 1).clamp(1, result.totalPages);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start to $end of ${result.totalCount} products',
          style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              child: const Icon(Icons.chevron_left, size: AppIconSize.i18),
              onTap: result.currentPage > 1
                  ? () => setState(() => _query = _query.copyWith(page: result.currentPage - 1))
                  : null,
            ),
            for (int i = windowStart; i <= windowEnd; i++)
              _pageButton(
                child: Text('$i'),
                isSelected: i == result.currentPage,
                onTap: () => setState(() => _query = _query.copyWith(page: i)),
              ),
            _pageButton(
              child: const Icon(Icons.chevron_right, size: AppIconSize.i18),
              onTap: result.currentPage < result.totalPages
                  ? () => setState(() => _query = _query.copyWith(page: result.currentPage + 1))
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageButton({required Widget child, VoidCallback? onTap, bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : context.colors.background,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(color: isSelected ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: onTap == null
                  ? context.colors.textDisabled
                  : (isSelected ? context.colors.onPrimary : context.colors.textPrimary),
              fontSize: AppFontSize.f13,
              fontWeight: AppFontWeight.semibold,
            ),
            child: IconTheme(
              data: IconThemeData(
                  color: onTap == null
                      ? context.colors.textDisabled
                      : (isSelected ? context.colors.onPrimary : context.colors.textPrimary)),
              child: child,
            ),
          ),
        ),
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
    final statusColor = status['color'] as Color;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        boxShadow: [
          BoxShadow(
              color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
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
                      '${p.category} \u2022 ${p.type}',
                      style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Wrap(
                      spacing: AppSpacing.s6,
                      runSpacing: AppSpacing.s4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: AppAlpha.a10),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            border: Border.all(color: statusColor.withValues(alpha: AppAlpha.a40)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(status['icon'] as IconData, size: AppIconSize.i12, color: statusColor),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                status['text'] as String,
                                style: TextStyle(
                                    color: statusColor, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold),
                              ),
                            ],
                          ),
                        ),
                        if (p.hasRestockShelfAlert)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: context.colors.info.withValues(alpha: AppAlpha.a10),
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                              border: Border.all(color: context.colors.info.withValues(alpha: AppAlpha.a40)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.move_up, size: AppIconSize.i12, color: context.colors.infoStrong),
                                const SizedBox(width: AppSpacing.s4),
                                Text(
                                  'Restock Shelf',
                                  style: TextStyle(
                                      color: context.colors.infoStrong, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s10),
                    // Stock / Price - Stock (not Sellable) is this
                    // screen's own primary concern, since this is
                    // the warehouse side of the catalog.
                    Row(
                      children: [
                        Expanded(
                          child: _labelValue('Stock', '${p.stockQty} ${p.unit}', valueColor: statusColor),
                        ),
                        Expanded(child: _labelValue('Price', Money.format(p.sellPrice))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'Sellable: ${p.sellableQty} ${p.unit} \u2022 Batch: ${p.batchNo ?? "-"}',
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
                                'Buy: ${Money.format(p.buyPrice)}',
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                              ),
                              if (p.expiry != null)
                                Text(
                                  'Expiry: ${AppDateFormat.date.format(p.expiry!)}',
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
                          tooltip: 'More actions',
                          onSelected: (value) {
                            if (value == 'add_batch') {
                              showAddBatchScreen(context, product: p);
                            } else if (value == 'view_batches') {
                              showViewBatchesScreen(context, product: p, moveToStockLabel: 'Remove from Sellable');
                            } else if (value == 'delete') {
                              _deleteProduct(p.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'add_batch', child: Text('Add New Batch')),
                            const PopupMenuItem(value: 'view_batches', child: Text('View Batches')),
                            if (isAdmin)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: context.colors.dangerSoft)),
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
                    label: Text('Edit', style: TextStyle(color: context.colors.primary)),
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
                    label: const Text('Release'),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: AppSpacing.s10)),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return context.colors.accent;
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
}
