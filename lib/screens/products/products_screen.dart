import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../constants/product_categories.dart';
import '../../widgets/product_category_filter_bar.dart';
import 'add_edit_product_screen.dart';
import 'add_batch_screen.dart';
import 'view_batches_screen.dart';
import '../sales/add_sale_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // Replaces the old expand/collapse-per-category state with a single
  // selected filter chip - "All" or one specific category at a time.
  String _selectedCategory = 'All';
  String _selectedGroup = 'All';

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

    // 🔑 SELLABLE PRODUCTS ONLY
    final sellableProducts = provider.products
        .where((p) => p.sellableQty > 0)
        .toList();

    // Every category actually in use right now, passed to the filter bar
    // so a legacy/unmapped category value still shows up somewhere,
    // instead of being invisible under every group.
    final categoriesInData = <String>{for (final p in sellableProducts) _categoryOf(p)};

    final filteredProducts = sellableProducts.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.description ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      final category = _categoryOf(p);
      final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
      final matchesGroup = _selectedGroup == 'All' || groupOfCategory(category) == _selectedGroup;

      return matchesSearch && matchesCategory && matchesGroup;
    }).toList();

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ProductCategoryFilterBar(
              selectedGroup: _selectedGroup,
              selectedCategory: _selectedCategory,
              extraCategoriesInData: categoriesInData,
              primaryColor: primaryDeepGreen,
              accentColor: warmAmber,
              onGroupChanged: (group) => setState(() {
                _selectedGroup = group;
                _selectedCategory = 'All'; // reset - a category from the old group may not exist in the new one
              }),
              onCategoryChanged: (category) => setState(() => _selectedCategory = category),
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty && _selectedCategory == 'All'
                              ? 'No sellable products'
                              : 'No products match your filters',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isEmpty && _selectedCategory == 'All')
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
                    child: _buildProductsGrid(filteredProducts),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showAddEditProductScreen(context);
        },
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  // One flat, responsive grid for every view - no expand/collapse. 2
  // columns on wide screens, 1 on phones; same pattern as Sales/Archive.
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
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search products...',
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
          : const Text('Sellable Products'),
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
            // Product name and status badge
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
                // Status badge
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

            // Description
            if (p.description != null && p.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  p.description!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 4),

            // Batch and Type
            Text(
              'Batch: ${p.batchNo ?? "-"} | Type: ${p.type} | Category: ${p.category}',
              style: const TextStyle(fontSize: 13),
            ),

            // Stock quantities
            Text(
              'Stock: ${p.stockQty} ${p.unit} | Sellable: ${p.sellableQty} ${p.unit}',
              style: const TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 2),

            // Prices
            Text(
              'Buy: ${_moneyFormat.format(p.buyPrice)} | Sell: ${_moneyFormat.format(p.sellPrice)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),

            // Expiry date
            if (p.expiry != null)
              Text(
                'Expiry: ${DateFormat('dd MMM yyyy').format(p.expiry!)}',
                style: const TextStyle(fontSize: 13),
              ),

            const SizedBox(height: 8),

            // Action buttons - Wrap rather than Row, since up to four
            // items (Edit, Batches menu, Delete, Sell) side by side
            // could overflow a narrow phone screen; this drops
            // gracefully to a second line instead.
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
                  onPressed: () async {
                    await showAddEditProductScreen(context, product: p);
                  },
                  icon: Icon(Icons.edit, size: 16, color: primaryDeepGreen),
                  label: Text('Edit', style: TextStyle(color: primaryDeepGreen)),
                ),

                PopupMenuButton<String>(
                  icon: Icon(Icons.layers_outlined, color: primaryDeepGreen, size: 20),
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

                // Delete button - admin only
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                  TextButton.icon(
                    onPressed: () => _deleteProduct(p),
                    icon: Icon(Icons.delete, size: 16, color: Colors.red[400]),
                    label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                  ),

                const SizedBox(width: 8),

                // Sell button - takes you into the real Add Sale flow.
                ElevatedButton.icon(
                  onPressed: () {
                    showAddSaleScreen(context);
                  },
                  icon: const Icon(Icons.sell, size: 16),
                  label: const Text('Sell'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) {
                        if (states.contains(WidgetState.hovered)) {
                          return warmAmber;
                        }
                        return primaryDeepGreen;
                      },
                    ),
                    foregroundColor: WidgetStateProperty.all(offWhite),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
