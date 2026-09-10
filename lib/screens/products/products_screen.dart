import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/product_catalog_side_panel.dart';
import '../../widgets/product_thumbnail.dart';
import '../../services/product_catalog_service.dart';
import '../../services/usage_calculator_service.dart';
import 'add_edit_product_screen.dart';
import 'add_batch_screen.dart';
import 'view_batches_screen.dart';
import '../sales/add_sale_screen.dart';
import '../dashboard/stock_alerts_screen.dart';
import '../../models/notification_model.dart';

class ProductsScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const ProductsScreen({super.key, this.initialSearchQuery});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final GlobalKey _bellKey = GlobalKey();

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  final TextEditingController _searchController = TextEditingController();

  // Grid (image cards) vs a more compact list view - the toolbar's own
  // view toggle switches this.
  bool _isGridView = true;

  // Everything the catalog view currently wants to see, in one place -
  // matches ProductCatalogService's own query shape, so this screen
  // only ever builds a query and renders whatever result comes back,
  // rather than filtering a product list inline itself. Uses the
  // service's own default page size, so a small catalog (fewer
  // products than one page) never shows pagination controls at
  // all - see result.needsPaginationControls below.
  ProductCatalogQuery _query = const ProductCatalogQuery(pageSize: kProductCatalogDefaultPageSize);

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _query = _query.copyWith(searchQuery: widget.initialSearchQuery!.trim(), page: 1);
    }
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

  Future<void> _recalculateSmartDefaults() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    final products = Provider.of<ProductProvider>(context, listen: false).products;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recalculating smart defaults from usage history...')),
    );

    try {
      final facilityDoc = await FirebaseFirestore.instance.collection('facilities').doc(facilityId).get();
      final restockFrequency = facilityDoc.data()?['restockFrequency'] as String? ??
          UsageCalculatorService.defaultRestockFrequency;

      final updatedCount = await UsageCalculatorService.recalculateForFacility(
        facilityId,
        products,
        restockFrequency: restockFrequency,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedCount > 0
              ? 'Updated smart defaults for $updatedCount product${updatedCount == 1 ? '' : 's'} with enough usage history.'
              : 'No products have enough sales/service history yet to compute smart defaults.'),
        ),
      );
      if (updatedCount > 0) await _manualRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not recalculate smart defaults: $e')),
      );
    }
  }

  /// Same anchored-dropdown pattern as the Dashboard's own bell (see
  /// dashboard_screen.dart's _showNotificationsDropdown) - positioned
  /// relative to this bell's actual measured position, transparent
  /// barrier so it reads as a dropdown rather than a modal taking over
  /// the screen. Scoped to stock-only notifications throughout, since
  /// this bell belongs to the Products screen specifically.
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
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: bellPosition.dy + bellSize.height + 8,
              left: left,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenSize.height * 0.75),
                    child: const StockAlertsScreen(isDropdown: true, lockedCategory: NotificationCategory.stock),
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
      ('Total Products', '$totalCount', Icons.shopping_bag_outlined, primaryDeepGreen),
      ('In Stock', '${statusCounts['Active'] ?? 0}', Icons.check_circle_outline, Colors.green),
      ('Low Stock', '${statusCounts['Low Stock'] ?? 0}', Icons.trending_down, Colors.orange),
      ('Depleted', '${statusCounts['Depleted'] ?? 0}', Icons.remove_shopping_cart_outlined, Colors.red),
      ('Total Stock Value', _moneyFormat.format(totalStockValue), Icons.account_balance_wallet_outlined, warmAmber),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // A smooth 2/3/4/5-column progression across screen widths,
        // rather than a single narrow/wide jump - 160px is a
        // reasonable minimum card width before it starts feeling
        // cramped, and there are exactly 5 cards now, so 5 columns is
        // both the cap and the point where they all fit in one
        // complete row with nothing left over.
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 5);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount <= 2 ? 3.0 : 2.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: metrics.map((m) => _metricCard(m.$1, m.$2, m.$3, m.$4)).toList(),
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
        'color': Colors.grey,
        'icon': Icons.inventory_2_outlined,
      };
    }

    // Nothing left anywhere - the most actionable state (needs
    // restocking), so it takes priority even over an old expiry date
    // still sitting on the record from whatever batch was last here.
    if (product.primaryStatus == ProductStockStatus.depleted) {
      return {
        'text': 'Depleted',
        'color': Colors.red,
        'icon': Icons.remove_shopping_cart_outlined,
      };
    }

    if (product.expiry != null && product.expiry!.isBefore(DateTime.now())) {
      return {
        'text': 'Expired',
        'color': Colors.red,
        'icon': Icons.warning,
      };
    }

    // Same primaryStatus every screen reads, so "Low Stock" (and now
    // "Reorder Soon") never mean something different depending on which
    // screen you're looking at.
    if (product.primaryStatus == ProductStockStatus.lowStock) {
      return {
        'text': 'Low Stock',
        'color': Colors.orange,
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
        'color': Colors.amber[700],
        'icon': Icons.hourglass_bottom,
      };
    }

    if (product.expiry == null) {
      return {
        'text': 'Unknown',
        'color': Colors.grey,
        'icon': Icons.help_outline,
      };
    }

    final now = DateTime.now();
    final expiryDate = product.expiry!;

    if (expiryDate.difference(now).inDays <= 30) {
      return {
        'text': 'Expiring Soon',
        'color': Colors.orange,
        'icon': Icons.schedule,
      };
    }

    return {
      'text': 'Active',
      'color': Colors.green,
      'icon': Icons.check_circle,
    };
  }

  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: offWhite,
        title: Text('Confirm Delete', style: TextStyle(color: primaryDeepGreen)),
        content: Text('Are you sure you want to delete "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: primaryDeepGreen),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: offWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Provider.of<ProductProvider>(context, listen: false)
          .deleteProduct(context, p.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final allProducts = provider.products;

    // This screen's normal purpose is "available to sell right now"
    // (sellableQty > 0).
    bool belongsOnThisScreen(Product p) => p.sellableQty > 0;
    bool productIsDepleted(Product p) => p.stockQty <= 0 && p.sellableQty <= 0;

    // Base set for this screen (before category/status/search
    // narrowing) - a fully depleted product is counted here (it needs
    // to show up under the Depleted status bucket) even though it
    // wouldn't otherwise belong on this screen at all.
    final baseProducts = allProducts.where((p) {
      if (productIsDepleted(p)) return true;
      return belongsOnThisScreen(p);
    }).toList();

    final categoriesInData = <String>{for (final p in baseProducts) _categoryOf(p)};

    // Category counts exclude Depleted products - a depleted product's
    // category isn't a meaningful "what's available" breakdown, the
    // same reasoning ProductCatalogService itself uses to keep
    // Depleted out of the normal browsing set.
    final categoryCounts = <String, int>{};
    for (final p in baseProducts) {
      if (productIsDepleted(p)) continue;
      final cat = _categoryOf(p);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    // Status counts cover every bucket, Depleted included, since
    // that's itself one of the status rows shown in the panel.
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
      primaryColor: primaryDeepGreen,
      accentColor: warmAmber,
    );

    final noFiltersActive = _query.searchQuery.isEmpty &&
        _query.selectedGroup == 'All' &&
        _query.selectedCategory == 'All' &&
        _query.selectedStatus == 'All';

    final totalStockValue = baseProducts.fold<double>(0, (sum, p) => sum + (p.sellableQty * p.buyPrice));

    final listOrGrid = result.items.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  noFiltersActive ? 'No sellable products' : 'No products match your filters',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                if (noFiltersActive)
                  Text(
                    'Release products from Stock Store',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
              ],
            ),
          )
        : RefreshIndicator(
            color: primaryDeepGreen,
            onRefresh: _manualRefresh,
            child: _isGridView ? _buildProductsGrid(result.items) : _buildProductsListView(result.items),
          );

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildSummaryMetrics(
            totalCount: visibleProductCount,
            statusCounts: statusCounts,
            totalStockValue: totalStockValue,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildToolbar(),
        ),
        Expanded(child: listOrGrid),
        if (result.needsPaginationControls)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildPaginationControls(result),
          ),
      ],
    );

    final isWide = MediaQuery.of(context).size.width >= 900;

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

  // A responsive grid that scales smoothly with available width (1-3
  // columns) rather than a hard breakpoint jump. No upper cap on
  // column count or overall width anymore - the side panel now
  // provides the page's own left-side structure, so the grid expands
  // naturally to fill whatever space remains to its right instead of
  // being boxed into an artificial max width that would leave unused
  // space on a wide monitor. When there are fewer products than
  // columns, they're still centered at their natural card width via
  // Wrap instead of stretched into a mostly-empty grid row or
  // left-pinned within it - a plain grid would still anchor a lone
  // card to the first column's slot even so. Widened from 360 to 460
  // now that each card holds a wider image (130px) alongside its info
  // column - at the old width, both would have been cramped; this
  // naturally yields fewer, more comfortable columns per row instead.
  static const double _idealProductCardWidth = 460.0;

  Widget _buildProductsGrid(List<Product> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _idealProductCardWidth).floor().clamp(1, 999);

        if (products.length < columns) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: products
                  .map((p) => SizedBox(width: _idealProductCardWidth, child: _buildProductCard(p)))
                  .toList(),
            ),
          );
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  // A denser, more scannable alternative to the image cards - same
  // actions and status logic, just laid out as a compact horizontal
  // row instead of a large vertical card.
  Widget _buildProductsListView(List<Product> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildProductListRow(products[index]),
    );
  }

  Widget _buildProductListRow(Product p) {
    final status = _getProductStatus(p);
    final statusColor = status['color'] as Color;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductThumbnail.square(
            imageUrl: p.imageUrl,
            size: 56,
            backgroundColor: primaryDeepGreen.withValues(alpha: 0.08),
            iconColor: primaryDeepGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${p.category} \u2022 ${p.type}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(status['text'] as String,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (p.hasRestockShelfAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.move_up, size: 11, color: Colors.blue[700]),
                            const SizedBox(width: 3),
                            Text('Restock Shelf',
                                style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
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
            child: _labelValue('Sellable', '${p.sellableQty} ${p.unit}', valueColor: statusColor),
          ),
          Expanded(
            flex: 2,
            child: _labelValue('Price', _moneyFormat.format(p.sellPrice)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  await showAddEditProductScreen(context, product: p);
                },
                icon: Icon(Icons.edit_outlined, color: primaryDeepGreen, size: 20),
                tooltip: 'Edit',
              ),
              Tooltip(
                message: p.sellableQty <= 0 ? 'Out of stock - nothing sellable' : 'Sell',
                child: IconButton(
                  onPressed: p.sellableQty <= 0
                      ? null
                      : () {
                          showAddSaleScreen(context, product: p);
                        },
                  icon: Icon(Icons.sell,
                      color: p.sellableQty <= 0 ? Colors.grey.shade400 : primaryDeepGreen, size: 20),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: primaryDeepGreen),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p);
                  } else if (value == 'delete') {
                    _deleteProduct(p);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'add_batch', child: Text('Add New Batch')),
                  const PopupMenuItem(value: 'view_batches', child: Text('View Batches')),
                  if (isAdmin)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red[400])),
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
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sellable Products',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Products ready for sale', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Recalculate smart defaults from usage history',
            onPressed: _recalculateSmartDefaults,
          ),
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
                final isWideScreen = MediaQuery.of(context).size.width >= 900;
                if (isWideScreen) {
                  await _showNotificationsDropdown(context);
                } else {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StockAlertsScreen(lockedCategory: NotificationCategory.stock)));
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
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () async {
              await showAddEditProductScreen(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search product, brand or batch...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: offWhite,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: border,
              enabledBorder: border,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = _query.copyWith(searchQuery: '', page: 1);
                      }),
                    ),
            ),
            onChanged: (val) => setState(() => _query = _query.copyWith(searchQuery: val.trim(), page: 1)),
          ),
        ),
        const SizedBox(width: 10),
        _buildSortDropdown(),
        const SizedBox(width: 10),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 44,
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductSortOption>(
          value: _query.sortOption,
          icon: Icon(Icons.swap_vert, size: 18, color: primaryDeepGreen),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
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
        color: offWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? primaryDeepGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[600]),
      ),
    );
  }

  Widget _buildPaginationControls(ProductCatalogResult result) {
    final pageSize = _query.pageSize ?? kProductCatalogDefaultPageSize;
    final start = (result.currentPage - 1) * pageSize + 1;
    final end = (start + result.items.length - 1).clamp(start, result.totalCount);

    // A window of page numbers around the current page, rather than
    // every page when there are many - stays usable regardless of how
    // large the catalog eventually gets.
    const windowSize = 5;
    int windowStart = (result.currentPage - windowSize ~/ 2).clamp(1, result.totalPages);
    int windowEnd = (windowStart + windowSize - 1).clamp(1, result.totalPages);
    windowStart = (windowEnd - windowSize + 1).clamp(1, result.totalPages);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start to $end of ${result.totalCount} products',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              child: const Icon(Icons.chevron_left, size: 18),
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
              child: const Icon(Icons.chevron_right, size: 18),
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
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryDeepGreen : offWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? primaryDeepGreen : Colors.grey.withValues(alpha: 0.3)),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: onTap == null
                  ? Colors.grey.shade400
                  : (isSelected ? Colors.white : Colors.black87),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme(
              data: IconThemeData(color: onTap == null ? Colors.grey.shade400 : (isSelected ? Colors.white : Colors.black87)),
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
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? Colors.black87),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product p) {
    final status = _getProductStatus(p);
    final statusColor = status['color'] as Color;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: primaryDeepGreen.withValues(alpha: 0.08),
                  iconColor: primaryDeepGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${p.category} \u2022 ${p.type}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(status['icon'] as IconData, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status['text'] as String,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (p.hasRestockShelfAlert)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.move_up, size: 12, color: Colors.blue[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Restock Shelf',
                                  style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _labelValue('Sellable', '${p.sellableQty} ${p.unit}', valueColor: statusColor),
                        ),
                        Expanded(child: _labelValue('Price', _moneyFormat.format(p.sellPrice))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      Text(
                        p.description!,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      'Stock: ${p.stockQty} ${p.unit} \u2022 Batch: ${p.batchNo ?? "-"}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                    ),
                    Text(
                      'Buy: ${_moneyFormat.format(p.buyPrice)}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                    ),
                    if (p.expiry != null)
                      Text(
                        'Expiry: ${DateFormat('dd MMM yyyy').format(p.expiry!)}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await showAddEditProductScreen(context, product: p);
                  },
                  icon: Icon(Icons.edit_outlined, size: 16, color: primaryDeepGreen),
                  label: Text('Edit', style: TextStyle(color: primaryDeepGreen)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sell button - takes you into the real Add Sale
              // flow. Disabled when there's nothing sellable for
              // this product specifically, rather than opening
              // Add Sale only for the person to discover there's
              // nothing to actually sell.
              Expanded(
                child: Tooltip(
                  message: p.sellableQty <= 0 ? 'Out of stock - nothing sellable' : '',
                  child: ElevatedButton.icon(
                    onPressed: p.sellableQty <= 0
                        ? null
                        : () {
                            showAddSaleScreen(context, product: p);
                          },
                    icon: const Icon(Icons.sell, size: 16),
                    label: const Text('Sell'),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10)),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.disabled)) return Colors.grey.shade300;
                        if (states.contains(WidgetState.hovered)) return warmAmber;
                        return primaryDeepGreen;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.disabled)) return Colors.grey.shade600;
                        return offWhite;
                      }),
                    ),
                  ),
                ),
              ),
              // Overflow menu - batches (Add New Batch / View
              // Batches) plus, for an admin, Delete. Consolidates
              // what used to be three separate buttons (a
              // batches menu icon, a text Delete button) into
              // one, without removing any of the actions
              // themselves.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: primaryDeepGreen),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p);
                  } else if (value == 'delete') {
                    _deleteProduct(p);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'add_batch', child: Text('Add New Batch')),
                  const PopupMenuItem(value: 'view_batches', child: Text('View Batches')),
                  if (isAdmin)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red[400])),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
