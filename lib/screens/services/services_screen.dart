import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/service.dart';
import '../../constants/service_categories.dart';
import '../../providers/service_provider.dart';
import '../../providers/facility_provider.dart';
import 'add_edit_service_screen.dart';
import 'services_archive_screen.dart';
import '../../widgets/payment_method_selector.dart';
import 'service_receipt_preview_screen.dart';
import '../../utils/subscription_guard.dart';
import '../../providers/user_role_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  // Accordion behavior: only one service card expanded at a time - same
  // reasoning and pattern as Sales' own card list.
  final Map<String, ExpansionTileController> _expansionControllers = {};
  String? _expandedServiceId;

  ExpansionTileController _controllerFor(String id) {
    return _expansionControllers.putIfAbsent(id, () => ExpansionTileController());
  }

  void _collapseIfStillExpanded(String? id) {
    if (id == null) return;
    final controller = _expansionControllers[id];
    if (controller == null) return;
    try {
      controller.collapse();
    } catch (_) {
      // That card's ExpansionTile is no longer in the tree (e.g. the
      // service was deleted while expanded) - nothing to collapse.
    }
  }

  final NumberFormat _numberFormat = NumberFormat.decimalPattern('en_US');

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      Provider.of<ServiceProvider>(context, listen: false).listenToServices(facilityId);
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
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final services = serviceProvider.services;
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

    // Always show every category from the Add Service dropdown, even ones
    // with zero services recorded yet - previously a category only
    // appeared as a chip once some service already used it, so an unused
    // category was effectively invisible as a filter option. Any legacy
    // category value found in real data (e.g. from before a category was
    // renamed) is still included too, so nothing gets silently hidden.
    final categories = <String>{...kServiceCategories};
    for (final s in services) {
      categories.add(s.category.isNotEmpty ? s.category : 'Other');
    }
    final sortedCategories = [
      'All',
      ...categories.toList()..sort(),
    ];

    final filteredServices = services.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.clientName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      final category = s.category.isNotEmpty ? s.category : 'Other';
      final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (sortedCategories.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedCategories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) => setState(() => _selectedCategory = category),
                      selectedColor: warmAmber,
                    );
                  }).toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${filteredServices.length} service${filteredServices.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
          Expanded(
            child: filteredServices.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty && _selectedCategory == 'All'
                          ? 'No services yet.'
                          : 'No services match your filters.',
                    ),
                  )
                : _buildServicesGrid(filteredServices, serviceProvider, dateFormatter),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Record Visit'),
        onPressed: () async {
          await navigateOrShowLockedDialog(
            context,
            const AddEditServiceScreen(),
            onNavigate: () => showAddEditServiceScreen(context),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      iconTheme: const IconThemeData(color: Color(0xFFFDFDF9)),
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search services...',
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
          : const Text('Service Records', style: TextStyle(color: Color(0xFFFDFDF9))),
      actions: [
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
        if (!_isSearchExpanded)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: offWhite,
                backgroundColor: offWhite.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.archive, size: 18),
              label: const Text('Archive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServicesArchiveScreen()),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildServicesGrid(
      List<Service> services, ServiceProvider serviceProvider, DateFormat dateFormatter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;
        final itemCount = services.length + 1; // +1 for the load-more footer

        Widget itemBuilder(BuildContext context, int index) {
          if (index == services.length) {
            return _buildLoadMoreFooter(serviceProvider);
          }
          return _buildServiceCard(services[index], serviceProvider, dateFormatter);
        }

        if (isLargeScreen) {
          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }

  // Same load-more footer pattern used on Sales/Archive - pages in older
  // services instead of ever loading a facility's whole service history.
  Widget _buildLoadMoreFooter(ServiceProvider serviceProvider) {
    if (serviceProvider.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryDeepGreen),
          ),
        ),
      );
    }
    if (!serviceProvider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Showing all recent services',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => serviceProvider.loadMoreServices(),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryDeepGreen,
            side: BorderSide(color: primaryDeepGreen),
          ),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more services'),
        ),
      ),
    );
  }

  // Mimics Sales' ExpansionTile card - collapsed shows a quick summary,
  // expanded shows full detail plus Print/Edit/Delete. No stats/summary
  // card at the top of this screen (unlike Sales), by design.
  Widget _buildServiceCard(Service service, ServiceProvider serviceProvider, DateFormat dateFormatter) {
    final statusColor = _statusColor(service.totalPaid, service.totalAmount);
    final statusIcon = _statusIcon(service.totalPaid, service.totalAmount);
    final statusText = _getPaymentStatus(service.totalPaid, service.totalAmount);
    final updatedDate = service.updatedAt != null
        ? dateFormatter.format(service.updatedAt!)
        : (service.serviceDate != null ? dateFormatter.format(service.serviceDate!) : '-');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        controller: _controllerFor(service.id),
        onExpansionChanged: (expanded) {
          if (expanded) {
            if (_expandedServiceId != null && _expandedServiceId != service.id) {
              _collapseIfStillExpanded(_expandedServiceId);
            }
            _expandedServiceId = service.id;
          } else if (_expandedServiceId == service.id) {
            _expandedServiceId = null;
          }
        },
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
                    _truncate(service.name, 30),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
            Row(
              children: [
                Text(
                  "Paid: Tsh ${_numberFormat.format(service.totalPaid)} / Tsh ${_numberFormat.format(service.totalAmount)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: primaryDeepGreen,
                  ),
                ),
                if (service.paymentMethod != null) ...[
                  const SizedBox(width: 8),
                  Icon(iconForPaymentMethod(service.paymentMethod!), size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 3),
                  Text(
                    service.paymentMethod!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ],
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
          _buildDetailRow("Category:", service.category.isEmpty ? 'Other' : service.category),
          _buildDetailRow("Client:", service.clientName ?? 'N/A'),
          _buildDetailRow("Provided By:", service.providedByName ?? 'N/A'),
          if (service.serviceDate != null)
            _buildDetailRow("Service Date:", DateFormat.yMMMd().format(service.serviceDate!)),
          if (service.description.isNotEmpty)
            _buildDetailRow("Notes:", service.description),
          if (service.itemsUsed.isNotEmpty) ...[
            const Divider(height: 16),
            const Text(
              "Items Used:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...service.itemsUsed.map((item) {
              final name = (item['itemName'] ?? '').toString();
              final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(name, style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      _numberFormat.format(price),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'Tsh ${_numberFormat.format(service.totalAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: primaryDeepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                icon: Icon(Icons.print, size: 18, color: primaryDeepGreen),
                label: Text('Print', style: TextStyle(color: primaryDeepGreen)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: service)),
                  );
                },
              ),
              TextButton.icon(
                onPressed: () {
                  showAddEditServiceScreen(context, service: service);
                },
                icon: Icon(Icons.edit, size: 18, color: primaryDeepGreen),
                label: Text('Edit', style: TextStyle(color: primaryDeepGreen)),
              ),
              if (Provider.of<UserRoleProvider>(context).isAdmin)
                TextButton.icon(
                  icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                  label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                  onPressed: () => _confirmDelete(service),
                ),
            ],
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
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

  Future<void> _confirmDelete(Service service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Provider.of<ServiceProvider>(context, listen: false).deleteService(service.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete service: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
