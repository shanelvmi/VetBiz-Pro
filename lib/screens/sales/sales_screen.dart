import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'add_sale_screen.dart';
import 'sales_archive_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  String _filterStatus = 'All';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      Provider.of<SaleProvider>(context, listen: false).init(facilityId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _truncate(String text, int cutoff) =>
      (text.length <= cutoff) ? text : '${text.substring(0, cutoff)}...';

  String _getPaymentStatus(double paid, double total) {
    if (paid >= total) return 'Paid';
    if (paid > 0) return 'Partial';
    return 'Unpaid';
  }

  Color _statusColor(double paid, double total) {
    if (paid >= total) return Colors.green;
    if (paid > 0) return Colors.orange;
    return Colors.red;
  }

  IconData _statusIcon(double paid, double total) {
    if (paid >= total) return Icons.check_circle;
    if (paid > 0) return Icons.pending;
    return Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = Provider.of<SaleProvider>(context);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    final sortedSales = [...saleProvider.sales];
    sortedSales.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final filteredSales = sortedSales.where((sale) {
      final matchesSearch = _searchQuery.isEmpty ||
          sale.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ==
              true ||
          sale.soldByName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.items.any((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()));

      final status = _getPaymentStatus(sale.totalPaid, sale.totalAmount);
      final matchesStatus =
          _filterStatus == 'All' || status == _filterStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    final totalSales = filteredSales.fold<double>(
        0, (sum, sale) => sum + sale.totalAmount);
    final totalPaid = filteredSales.fold<double>(
        0, (sum, sale) => sum + sale.totalPaid);
    final totalPending = totalSales - totalPaid;

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildProAppBar(context),
      body: Column(
        children: [
          _buildStatsCard(
              filteredSales.length, totalSales, totalPaid, totalPending),
          Expanded(
            child: filteredSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No sales yet'
                              : 'No sales match your filters',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : Focus(
                    autofocus: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLargeScreen = constraints.maxWidth >= 1024;

                        if (isLargeScreen) {
                          // Desktop Masonry Grid with keyboard scrolling and no glow
                          return ScrollConfiguration(
                            behavior: const ScrollBehavior().copyWith(overscroll: false),
                            child: MasonryGridView.count(
                              primary: true, // allows arrow key scrolling
                              padding: const EdgeInsets.all(12),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              itemCount: filteredSales.length,
                              itemBuilder: (context, index) {
                                return _buildSaleCard(
                                  filteredSales[index],
                                  saleProvider,
                                  dateFormatter,
                                );
                              },
                            ),
                          );
                        } else {
                          // Mobile / small screens ListView with keyboard scrolling
                          return ScrollConfiguration(
                            behavior: const ScrollBehavior().copyWith(overscroll: false),
                            child: ListView.builder(
                              primary: true, // allows arrow key scrolling
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredSales.length,
                              itemBuilder: (context, index) {
                                return _buildSaleCard(
                                  filteredSales[index],
                                  saleProvider,
                                  dateFormatter,
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSaleScreen()),
          );
        },
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Sale'),
      ),
    );
  }


  // 🆕 PRO AppBar with integrated search and filter
  PreferredSizeWidget _buildProAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      elevation: 0,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search sales...',
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
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            )
          : const Text('Sales Records'),
      actions: [
        // Search icon button
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              setState(() => _isSearchExpanded = true);
            },
          ),

        // Filter dropdown - compact in AppBar
        if (!_isSearchExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: offWhite.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterStatus,
                  icon: Icon(Icons.arrow_drop_down, color: offWhite),
                  dropdownColor: primaryDeepGreen,
                  style: TextStyle(color: offWhite, fontSize: 14),
                  items: [
                    DropdownMenuItem(
                      value: 'All',
                      child: Row(
                        children: [
                          Icon(Icons.all_inclusive, size: 16, color: offWhite),
                          const SizedBox(width: 8),
                          const Text('All'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Paid',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Paid'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Partial',
                      child: Row(
                        children: [
                          Icon(Icons.pending, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Partial'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Unpaid',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Unpaid'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null && mounted) {
                      setState(() => _filterStatus = val);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsCard(int count, double total, double paid, double pending) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDeepGreen, primaryDeepGreen.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryDeepGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
         Row(
            children: [
              Icon(Icons.analytics, color: offWhite, size: 24),
              const SizedBox(width: 8),
              Text(
                'Sales Summary',
                style: TextStyle(
                  color: offWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: offWhite,
                  backgroundColor: offWhite.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.archive, size: 18),
                label: const Text(
                  'Archive',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesArchiveScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _statChip('Total Sales', count.toString(), Icons.receipt_long),
              _statChip('Revenue', _moneyFormat.format(total), Icons.payments),
              _statChip('Paid', _moneyFormat.format(paid), Icons.check_circle),
              _statChip('Pending', _moneyFormat.format(pending), Icons.pending),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: offWhite.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: offWhite, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: offWhite.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: offWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sale card widget
  Widget _buildSaleCard(dynamic sale, SaleProvider saleProvider, DateFormat dateFormatter) {
    final updatedDate = dateFormatter.format(sale.updatedAt);
    final statusColor = _statusColor(sale.totalPaid, sale.totalAmount);
    final statusIcon = _statusIcon(sale.totalPaid, sale.totalAmount);
    final statusText = _getPaymentStatus(sale.totalPaid, sale.totalAmount);

    final int previewCount = 3;
    final itemsPreview = sale.items.take(previewCount).map((item) {
      final name = _truncate(item.name, 15);
      return '$name x${item.quantity}';
    }).join(', ');
    final extraCount = sale.items.length - previewCount;
    final productsSummary =
        extraCount > 0 ? '$itemsPreview, +$extraCount' : itemsPreview;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    productsSummary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Paid: ${_moneyFormat.format(sale.totalPaid)} / ${_moneyFormat.format(sale.totalAmount)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primaryDeepGreen,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Updated: $updatedDate",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildDetailRow("Seller:", sale.soldByName),
          _buildDetailRow("Client:", sale.clientName ?? 'Walk-in Customer'),
          _buildDetailRow("Created:", dateFormatter.format(sale.timestamp)),
          const Divider(height: 16),
          const Text(
            "Items Sold:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...sale.items.map((item) {
            final itemTotal = (item.unitPrice * item.quantity) - item.discount;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${item.name} x${item.quantity} ${item.unit}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    _moneyFormat.format(itemTotal),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                _moneyFormat.format(sale.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: primaryDeepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
              label: Text('Delete', style: TextStyle(color: Colors.red[400])),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        'Confirm Delete',
                        style: TextStyle(color: primaryDeepGreen),
                      ),
                      content: const Text(
                          'Are you sure you want to delete this sale?'),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: primaryDeepGreen),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: offWhite,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  saleProvider.deleteSale(sale.id, sale.facilityId);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sale deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}