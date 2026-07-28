import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../products/add_edit_product_screen.dart';

class StockStoreScreen extends StatefulWidget {
  const StockStoreScreen({super.key});

  @override
  State<StockStoreScreen> createState() => _StockStoreScreenState();
}

class _StockStoreScreenState extends State<StockStoreScreen> {
  bool _loading = true;
  String _searchQuery = '';

  final Map<String, bool> _categoryExpanded = {};

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
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

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

    await provider.deleteProduct(context, productId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product deleted')),
    );
    _fetchProducts();
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

      _fetchProducts();
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

    final filteredProducts = stockProducts.where((p) {
      return _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final Map<String, List<Product>> categoryMap = {};
    if (_searchQuery.isEmpty) {
      for (final p in filteredProducts) {
        categoryMap.putIfAbsent(p.category, () => []).add(p);
        _categoryExpanded.putIfAbsent(p.category, () => false);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Store'),
        backgroundColor: primaryDeepTealGreen,
        foregroundColor: offWhite,
        actions: [
          Container(
            width: 180,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TextField(
              cursorColor: primaryDeepTealGreen,
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
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ],
      ),
      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddEditProductScreen(),
          ),
        ).then((_) => _fetchProducts()),
        backgroundColor: primaryDeepTealGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: primaryDeepTealGreen),
            )
          : filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No products in stock store',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryDeepTealGreen,
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
                                    color: primaryDeepTealGreen,
                                  ),
                                ),
                                children: products.map(_buildProductCard).toList(),
                              ),
                            );
                          }).toList(),
                  ),
                ),
    );
  }

  Widget _buildProductCard(Product p) {
    final status = _getProductStatus(p);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditProductScreen(product: p),
          ),
        ).then((_) => _fetchProducts());
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
      ),
    );
  }
}