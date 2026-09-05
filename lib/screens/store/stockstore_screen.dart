import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
import '../dashboard/stock_alerts_screen.dart';

class StockStoreScreen extends StatefulWidget {
  const StockStoreScreen({super.key});

  @override
  State<StockStoreScreen> createState() => _StockStoreScreenState();
}

class _StockStoreScreenState extends State<StockStoreScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Grid (image cards) vs a more compact list view - matches Sellable
  // Products.
  bool _isGridView = true;

  // Everything the catalog view currently wants to see, in one place -
  // matches Sellable Products, same reasoning. Uses the service's own
  // default page size, so a small catalog never shows pagination
  // controls at all.
  ProductCatalogQuery _query = const ProductCatalogQuery(pageSize: kProductCatalogDefaultPageSize);

  final Color primaryDeepTealGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  // Money formatter with thousand separator
  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

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

  String _categoryOf(Product p) => p.category.isNotEmpty ? p.category : 'Uncategorized';

  Widget _buildSummaryMetrics({
    required int totalCount,
    required Map<String, int> statusCounts,
    required double totalStockValue,
  }) {
    final metrics = [
      ('Total Products', '$totalCount', Icons.shopping_bag_outlined, primaryDeepTealGreen),
      ('In Stock', '${statusCounts['Active'] ?? 0}', Icons.check_circle_outline, Colors.green),
      ('Low Stock', '${statusCounts['Low Stock'] ?? 0}', Icons.trending_down, Colors.orange),
      ('Depleted', '${statusCounts['Depleted'] ?? 0}', Icons.remove_shopping_cart_outlined, Colors.red),
      ('Total Stock Value', _moneyFormat.format(totalStockValue), Icons.account_balance_wallet_outlined, warmAmber),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isNarrow ? 2 : 5,
          childAspectRatio: isNarrow ? 3.0 : 2.6,
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
    // Nothing left anywhere - the most actionable state (needs
    // restocking), so it takes priority even over an old expiry date
    // still sitting on the record from whatever batch was last here.
    if (product.stockQty <= 0 && product.sellableQty <= 0) {
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

    // Same either-quantity-low check as the dashboard's own stock
    // alerts, so "Low Stock" never means something different depending
    // on which screen you're looking at.
    if (product.isLowStock) {
      return {
        'text': 'Low Stock',
        'color': Colors.orange,
        'icon': Icons.trending_down,
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

  Future<void> _deleteProduct(String productId) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Delete',
            style: TextStyle(color: primaryDeepTealGreen)),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: primaryDeepTealGreen,
            ),
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

    if (confirmed != true) return;

    try {
      await provider.deleteProduct(context, productId);
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

  Future<void> _releaseToShop(Product product) async {
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Release to Shop',
            style: TextStyle(color: primaryDeepTealGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available stock: ${product.stockQty} ${product.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              cursorColor: primaryDeepTealGreen,
              decoration: InputDecoration(
                labelText: 'Quantity to release',
                labelStyle: TextStyle(color: Colors.grey[700]),
                floatingLabelStyle: TextStyle(color: primaryDeepTealGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryDeepTealGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              cursorColor: primaryDeepTealGreen,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., Quality checked, ready for sale',
                labelStyle: TextStyle(color: Colors.grey[700]),
                floatingLabelStyle: TextStyle(color: primaryDeepTealGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryDeepTealGreen, width: 2),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: primaryDeepTealGreen,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (states) {
                  if (states.contains(WidgetState.hovered)) {
                    return warmAmber;
                  }
                  return primaryDeepTealGreen;
                },
              ),
              foregroundColor: WidgetStateProperty.all(offWhite),
            ),
            child: const Text('Release'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    if (qty <= 0 || qty > product.stockQty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity')),
      );
      return;
    }

    try {
      await Provider.of<ProductProvider>(context, listen: false)
          .moveToSellable(
            product,
            qty,
            context,
            notes: notesController.text.trim().isNotEmpty
                ? notesController.text.trim()
                : null,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Released $qty ${product.unit} of ${product.name} to shop',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to release product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
      primaryColor: primaryDeepTealGreen,
      accentColor: warmAmber,
    );

    final noFiltersActive = _query.searchQuery.isEmpty &&
        _query.selectedGroup == 'All' &&
        _query.selectedCategory == 'All' &&
        _query.selectedStatus == 'All';

    final totalStockValue = baseProducts.fold<double>(0, (sum, p) => sum + (p.stockQty * p.buyPrice));

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${result.totalCount} product${result.totalCount == 1 ? '' : 's'} in stock',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
        Expanded(
          child: result.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        noFiltersActive ? 'No products in stock store' : 'No products match your filters',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryDeepTealGreen,
                  onRefresh: _manualRefresh,
                  child: _isGridView ? _buildProductsGrid(result.items) : _buildProductsListView(result.items),
                ),
        ),
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

  // A denser, more scannable alternative to the image cards - matches
  // Sellable Products' own list row, with Stock (not Sellable) as the
  // primary value and Release (not Sell) as this screen's own action.
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
            backgroundColor: primaryDeepTealGreen.withValues(alpha: 0.08),
            iconColor: primaryDeepTealGreen,
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
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _labelValue('Stock', '${p.stockQty} ${p.unit}', valueColor: statusColor),
          ),
          Expanded(
            flex: 2,
            child: _labelValue('Price', _moneyFormat.format(p.sellPrice)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  showAddEditProductScreen(context, product: p);
                },
                icon: Icon(Icons.edit_outlined, color: primaryDeepTealGreen, size: 20),
                tooltip: 'Edit',
              ),
              if (p.stockQty > 0)
                IconButton(
                  onPressed: () => _releaseToShop(p),
                  icon: Icon(Icons.upload, color: primaryDeepTealGreen, size: 20),
                  tooltip: 'Release',
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: primaryDeepTealGreen),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p);
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
          const Text('Stock Store',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Manage your inventory', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Stock Alerts',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StockAlertsScreen()));
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
            onPressed: () => showAddEditProductScreen(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepTealGreen,
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
              hintText: 'Search stock, brand or batch...',
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
          icon: Icon(Icons.swap_vert, size: 18, color: primaryDeepTealGreen),
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
          color: isSelected ? primaryDeepTealGreen : Colors.transparent,
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
            color: isSelected ? primaryDeepTealGreen : offWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? primaryDeepTealGreen : Colors.grey.withValues(alpha: 0.3)),
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
                  backgroundColor: primaryDeepTealGreen.withValues(alpha: 0.08),
                  iconColor: primaryDeepTealGreen,
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
                    const SizedBox(height: 10),
                    // Stock / Price - Stock (not Sellable) is this
                    // screen's own primary concern, since this is
                    // the warehouse side of the catalog.
                    Row(
                      children: [
                        Expanded(
                          child: _labelValue('Stock', '${p.stockQty} ${p.unit}', valueColor: statusColor),
                        ),
                        Expanded(child: _labelValue('Price', _moneyFormat.format(p.sellPrice))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sellable: ${p.sellableQty} ${p.unit} \u2022 Batch: ${p.batchNo ?? "-"}',
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
                  onPressed: () {
                    showAddEditProductScreen(context, product: p);
                  },
                  icon: Icon(Icons.edit_outlined, size: 16, color: primaryDeepTealGreen),
                  label: Text('Edit', style: TextStyle(color: primaryDeepTealGreen)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryDeepTealGreen.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (p.stockQty > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Release'),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10)),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return warmAmber;
                        return primaryDeepTealGreen;
                      }),
                      foregroundColor: WidgetStateProperty.all(offWhite),
                    ),
                    onPressed: () => _releaseToShop(p),
                  ),
                ),
              ],
              // Overflow menu - batches (Add New Batch / View
              // Batches) plus, for an admin, Delete. Consolidates
              // what used to be three separate buttons into one,
              // without removing any of the actions themselves.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: primaryDeepTealGreen),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'add_batch') {
                    showAddBatchScreen(context, product: p);
                  } else if (value == 'view_batches') {
                    showViewBatchesScreen(context, product: p);
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
