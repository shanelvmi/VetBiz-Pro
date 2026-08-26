import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../constants/product_categories.dart';
import '../../widgets/product_category_filter_bar.dart';
import '../products/add_edit_product_screen.dart';
import '../products/add_batch_screen.dart';
import '../products/view_batches_screen.dart';

class StockStoreScreen extends StatefulWidget {
  const StockStoreScreen({super.key});

  @override
  State<StockStoreScreen> createState() => _StockStoreScreenState();
}

class _StockStoreScreenState extends State<StockStoreScreen> {
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // Same filter-chip pattern as Sellable Products - one selected category
  // at a time, instead of expand/collapse-per-category tiles.
  String _selectedCategory = 'All';
  String _selectedGroup = 'All';

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

  // Get product status based on expiry date
  Map<String, dynamic> _getProductStatus(Product product) {
    if (product.expiry == null) {
      return {
        'text': 'Unknown',
        'color': Colors.grey,
        'icon': Icons.help_outline,
      };
    }

    final now = DateTime.now();
    final expiryDate = product.expiry!;

    if (expiryDate.isBefore(now)) {
      return {
        'text': 'Expired',
        'color': Colors.red,
        'icon': Icons.warning,
      };
    } else if (expiryDate.difference(now).inDays <= 30) {
      return {
        'text': 'Expiring Soon',
        'color': Colors.orange,
        'icon': Icons.schedule,
      };
    } else {
      return {
        'text': 'Active',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    }
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
            '✅ Released $qty ${product.unit} of ${product.name} to shop',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to release product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);

    // Only show products with stockQty > 0
    final stockProducts =
        provider.products.where((p) => p.stockQty > 0).toList();

    // Every category actually in use right now, passed to the filter bar
    // so a legacy/unmapped category value still shows up somewhere.
    final categoriesInData = <String>{for (final p in stockProducts) _categoryOf(p)};

    final filteredProducts = stockProducts.where((p) {
      final matchesSearch =
          _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final category = _categoryOf(p);
      final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
      final matchesGroup = _selectedGroup == 'All' || groupOfCategory(category) == _selectedGroup;
      return matchesSearch && matchesCategory && matchesGroup;
    }).toList();

    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEditProductScreen(context),
        backgroundColor: primaryDeepTealGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ProductCategoryFilterBar(
              selectedGroup: _selectedGroup,
              selectedCategory: _selectedCategory,
              extraCategoriesInData: categoriesInData,
              primaryColor: primaryDeepTealGreen,
              accentColor: warmAmber,
              onGroupChanged: (group) => setState(() {
                _selectedGroup = group;
                _selectedCategory = 'All';
              }),
              onCategoryChanged: (category) => setState(() => _selectedCategory = category),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${filteredProducts.length} product${filteredProducts.length == 1 ? '' : 's'} in stock',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty && _selectedCategory == 'All'
                              ? 'No products in stock store'
                              : 'No products match your filters',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: primaryDeepTealGreen,
                    onRefresh: _manualRefresh,
                    child: _buildProductsGrid(filteredProducts),
                  ),
          ),
        ],
      ),
    );
  }

  // Same flat, responsive grid as Sellable Products - no expand/collapse.
  Widget _buildProductsGrid(List<Product> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;

        if (isLargeScreen) {
          return MasonryGridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(products[index]),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: products.map(_buildProductCard).toList(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search stock...',
                hintStyle: TextStyle(color: offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: offWhite),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            )
          : const Text('Stock Store'),
      backgroundColor: primaryDeepTealGreen,
      foregroundColor: offWhite,
      actions: [
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _manualRefresh,
          ),
      ],
    );
  }

  Widget _buildProductCard(Product p) {
    final status = _getProductStatus(p);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: offWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Status badge (replaced category)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (status['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (status['color'] as Color).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status['icon'] as IconData,
                        size: 14,
                        color: status['color'] as Color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status['text'] as String,
                        style: TextStyle(
                          color: status['color'] as Color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Batch: ${p.batchNo ?? "-"} | Type: ${p.type} | Unit: ${p.unit}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Stock: ${p.stockQty} ${p.unit} | Sellable: ${p.sellableQty} ${p.unit}',
              style: const TextStyle(fontSize: 13),
            ),
            // Money with thousand separator
            Text(
              'Buy: ${_moneyFormat.format(p.buyPrice)} | Sell: ${_moneyFormat.format(p.sellPrice)}',
              style: const TextStyle(fontSize: 13),
            ),
            if (p.expiry != null)
              Text(
                'Expiry: ${DateFormat('dd MMM yyyy').format(p.expiry!)}',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                // Edit button - the only way to reach the edit screen
                // now; the card itself is no longer tappable, since a
                // whole-card tap-to-edit made it too easy to open
                // editing by accident while just browsing the list.
                TextButton.icon(
                  onPressed: () {
                    showAddEditProductScreen(context, product: p);
                  },
                  icon: Icon(Icons.edit, size: 16, color: primaryDeepTealGreen),
                  label: Text('Edit', style: TextStyle(color: primaryDeepTealGreen)),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.layers_outlined, color: primaryDeepTealGreen, size: 20),
                  tooltip: 'Batches',
                  onSelected: (value) {
                    if (value == 'add') {
                      showAddBatchScreen(context, product: p);
                    } else if (value == 'view') {
                      showViewBatchesScreen(context, product: p);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add', child: Text('Add New Batch')),
                    PopupMenuItem(value: 'view', child: Text('View Batches')),
                  ],
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                TextButton.icon(
                  icon: Icon(Icons.delete, size: 16, color: Colors.red[400]),
                  label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                  onPressed: () => _deleteProduct(p.id),
                ),
                if (p.stockQty > 0) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Release'),
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
                    onPressed: () => _releaseToShop(p),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }
}
