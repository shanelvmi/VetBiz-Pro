import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../providers/facility_provider.dart';
import 'add_edit_product_screen.dart';

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

  bool _loading = true;
  String _searchQuery = '';

  final Map<String, bool> _categoryExpanded = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacilityId;

    if (facilityId != null) {
      await Provider.of<ProductProvider>(context, listen: false)
          .fetchProducts(facilityId);
    }

    setState(() => _loading = false);
  }

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

    await Provider.of<ProductProvider>(context, listen: false)
        .deleteProduct(context, p.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product deleted')),
    );

    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);

    // 🔑 SELLABLE PRODUCTS ONLY
    final sellableProducts = provider.products
        .where((p) => p.sellableQty > 0)
        .toList();

    final filteredProducts = sellableProducts.where((p) {
      return _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.description ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();

    final Map<String, List<Product>> categoryMap = {};
    if (_searchQuery.isEmpty) {
      for (final p in filteredProducts) {
        final category = p.category.isNotEmpty ? p.category : 'Uncategorized';
        categoryMap.putIfAbsent(category, () => []).add(p);
        _categoryExpanded.putIfAbsent(category, () => false);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        title: const Text('Sellable Products'),
        actions: [
          Container(
            width: 180,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TextField(
              cursorColor: primaryDeepGreen,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search...',
                filled: true,
                fillColor: offWhite,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProducts,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: primaryDeepGreen),
            )
          : filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No sellable products',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Release products from Stock Store',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryDeepGreen,
                  onRefresh: _fetchProducts,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _searchQuery.isNotEmpty
                        ? filteredProducts.map(_buildProductCard).toList()
                        : categoryMap.entries.map((entry) {
                            final category = entry.key;
                            final products = entry.value;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: ExpansionTile(
                                initiallyExpanded:
                                    _categoryExpanded[category] ?? false,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    _categoryExpanded[category] = expanded;
                                  });
                                },
                                title: Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryDeepGreen,
                                  ),
                                ),
                                children:
                                    products.map(_buildProductCard).toList(),
                              ),
                            );
                          }).toList(),
                  ),
                ),
      // Improved FAB with consistent styling
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditProductScreen(),
            ),
          );
          _fetchProducts();
        },
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    final status = _getProductStatus(p);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditProductScreen(product: p),
          ),
        );
        _fetchProducts();
      },
      child: Container(
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
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Delete button
                TextButton.icon(
                  onPressed: () => _deleteProduct(p),
                  icon: Icon(Icons.delete, size: 16, color: Colors.red[400]),
                  label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                ),
                
                const SizedBox(width: 8),
                
                // Sell button with hover effect
                ElevatedButton.icon(
                  onPressed: () {
                    // 🔜 integrate sale flow
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sale flow coming soon...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
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
      ),
    );
  }
}