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

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final services = serviceProvider.services;

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
                : _buildServicesGrid(filteredServices, serviceProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
        onPressed: () async {
          await navigateOrShowLockedDialog(context, const AddEditServiceScreen());
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
          : const Text('Attended Services', style: TextStyle(color: Color(0xFFFDFDF9))),
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

  Widget _buildServicesGrid(List<Service> services, ServiceProvider serviceProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;
        final itemCount = services.length + 1; // +1 for the load-more footer

        Widget itemBuilder(BuildContext context, int index) {
          if (index == services.length) {
            return _buildLoadMoreFooter(serviceProvider);
          }
          return _buildServiceCard(services[index]);
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

  Widget _buildServiceCard(Service service) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditServiceScreen(service: service),
          ),
        );
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
                    service.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryDeepGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    service.category.isEmpty ? 'Other' : service.category,
                    style: TextStyle(
                      color: primaryDeepGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (service.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  service.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Client: ${service.clientName ?? 'N/A'}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Provided By: ${service.providedByName ?? 'N/A'}',
              style: const TextStyle(fontSize: 13),
            ),
            if (service.serviceDate != null)
              Text(
                'Date: ${DateFormat.yMMMd().format(service.serviceDate!)}',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 2),
            Text(
              'Total: Tsh ${_numberFormat.format(service.totalAmount)} | Paid: Tsh ${_numberFormat.format(service.totalPaid)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                TextButton.icon(
                  onPressed: () => _confirmDelete(service),
                  icon: Icon(Icons.delete, size: 16, color: Colors.red[400]),
                  label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                ),
                const SizedBox(width: 8),
                // Edit was previously missing entirely - tapping a service
                // only expanded its details, with no way to change it.
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditServiceScreen(service: service),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryDeepGreen;
                    }),
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
