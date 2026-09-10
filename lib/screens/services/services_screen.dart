import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/service.dart';
import '../../constants/service_categories.dart';
import '../../providers/service_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/client_provider.dart';
import 'add_edit_service_screen.dart';
import 'services_archive_screen.dart';
import 'service_receipt_preview_screen.dart';
import '../../utils/subscription_guard.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _dateFilter = 'Last 30 days';
  String _statusFilter = 'All';

  // Which service is shown in the details panel, and the display
  // pagination window (over whatever's already loaded) - same pattern
  // as the Sales screen.
  Service? _selectedService;
  int _displayPageSize = 10;
  int _currentPageIndex = 0;

  String? _facilityId;
  Map<String, double>? _rangeSummary;
  bool _isSummaryLoading = false;

  // Auto-refreshes the summary shortly after a service changes below,
  // instead of leaving it stale until a manual refresh. Unlike Sales,
  // this reads directly from a live Firestore query (no Cloud
  // Function aggregate to wait on), so the debounce is short - just
  // enough to avoid re-querying on rapid successive changes.
  ServiceProvider? _serviceProvider;
  int _lastKnownServiceCount = 0;
  Timer? _pendingSummaryRefresh;

  @override
  void initState() {
    super.initState();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      _facilityId = facilityId;
      _serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
      _serviceProvider!.listenToServices(facilityId);
      _lastKnownServiceCount = _serviceProvider!.services.length;
      _serviceProvider!.addListener(_onServicesChanged);
      _loadRangeSummary();
    }
  }

  void _onServicesChanged() {
    if (!mounted || _serviceProvider == null) return;
    final currentCount = _serviceProvider!.services.length;
    if (currentCount == _lastKnownServiceCount) return;
    _lastKnownServiceCount = currentCount;

    _pendingSummaryRefresh?.cancel();
    _pendingSummaryRefresh = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadRangeSummary();
    });
  }

  Future<void> _loadRangeSummary() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isSummaryLoading = true);
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('services')
          .where('serviceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      double paidAmount = 0;
      double outstanding = 0;
      double mpesaAmount = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
        paidAmount += totalPaid;
        outstanding += (totalAmount - totalPaid);
        if (data['paymentMethod'] == 'M-Pesa') {
          mpesaAmount += totalPaid;
        }
      }

      if (!mounted) return;
      setState(() {
        _rangeSummary = {
          'count': snap.docs.length.toDouble(),
          'paidAmount': paidAmount,
          'outstanding': outstanding,
          'mpesaAmount': mpesaAmount,
        };
        _isSummaryLoading = false;
      });
    } catch (e) {
      debugPrint('Could not load service summary: $e');
      if (mounted) setState(() => _isSummaryLoading = false);
    }
  }

  @override
  void dispose() {
    _pendingSummaryRefresh?.cancel();
    _serviceProvider?.removeListener(_onServicesChanged);
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');
    final dateOnlyFormatter = DateFormat('dd MMM yyyy');
    final timeOnlyFormatter = DateFormat('hh:mm a');

    final sortedServices = [...serviceProvider.services];
    sortedServices.sort((a, b) {
      final aDate = a.serviceDate ?? DateTime(2000);
      final bDate = b.serviceDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    final now = DateTime.now();
    final filteredServices = sortedServices.where((service) {
      final matchesSearch = _searchQuery.isEmpty ||
          service.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          service.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          _invoiceNo(service).toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'All' || service.category == _selectedCategory;

      final status = _getPaymentStatus(service.totalPaid, service.totalAmount);
      final matchesStatus = _statusFilter == 'All' || status == _statusFilter;

      final serviceDate = service.serviceDate;
      final matchesDate = switch (_dateFilter) {
        'Today' => serviceDate != null &&
            serviceDate.year == now.year &&
            serviceDate.month == now.month &&
            serviceDate.day == now.day,
        'Last 7 days' => serviceDate != null && serviceDate.isAfter(now.subtract(const Duration(days: 7))),
        'Last 30 days' => serviceDate != null && serviceDate.isAfter(now.subtract(const Duration(days: 30))),
        'This month' => serviceDate != null && serviceDate.year == now.year && serviceDate.month == now.month,
        _ => true, // 'All time'
      };

      return matchesSearch && matchesCategory && matchesStatus && matchesDate;
    }).toList();

    // Same honest display-pagination window as the Sales screen - a
    // page here is a view over whatever's already loaded (or gets
    // loaded on demand), not a true jump to an arbitrary page number.
    final totalPages = (filteredServices.length / _displayPageSize).ceil().clamp(1, 999999);
    if (_currentPageIndex >= totalPages) _currentPageIndex = totalPages - 1;
    if (_currentPageIndex < 0) _currentPageIndex = 0;
    final pageStart = _currentPageIndex * _displayPageSize;
    final pageEnd = (pageStart + _displayPageSize).clamp(0, filteredServices.length);
    final pageServices = filteredServices.sublist(pageStart.clamp(0, filteredServices.length), pageEnd);

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _buildCategoryChipsRow()),
                      const SizedBox(width: 12),
                      _buildArchiveButton(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildMetricsRow(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildFiltersToolbar(),
                ),
                Expanded(
                  child: filteredServices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No services yet' : 'No services match your filters',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : _buildServicesTable(pageServices, dateFormatter),
                ),
                _buildPaginationBar(
                  serviceProvider: serviceProvider,
                  totalFiltered: filteredServices.length,
                  pageStart: pageStart,
                  pageEnd: pageEnd,
                  totalPages: totalPages,
                ),
              ],
            ),
          ),
          if (_selectedService != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: _buildServiceDetailsPanel(_selectedService!, dateOnlyFormatter, timeOnlyFormatter),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== METRICS ROW ====================

  Widget _buildMetricsRow() {
    final summary = _rangeSummary;
    final isFirstLoadPending = summary == null && _isSummaryLoading;

    final count = summary?['count']?.toInt() ?? 0;
    final paidAmount = summary?['paidAmount'] ?? 0.0;
    final outstanding = summary?['outstanding'] ?? 0.0;
    final mpesaAmount = summary?['mpesaAmount'] ?? 0.0;

    final metrics = [
      ('Total Services', '$count', Icons.medical_services_outlined, primaryDeepGreen),
      ('Paid Amount', _moneyFormat.format(paidAmount), Icons.account_balance_wallet_outlined, Colors.blue),
      ('Outstanding', _moneyFormat.format(outstanding), Icons.pending_actions_outlined, warmAmber),
      ('M-Pesa Payments', _moneyFormat.format(mpesaAmount), Icons.phone_iphone_outlined, Colors.green),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 2 : 4,
            mainAxisExtent: 90,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final m = metrics[index];
            return _metricCard(m.$1, m.$2, m.$3, m.$4, isFirstLoadPending);
          },
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration:
                      BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
            Text('Last 30 days', style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Service Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Track all services provided to your clients', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () => navigateOrShowLockedDialog(
              context,
              const AddEditServiceScreen(),
              onNavigate: () => showAddEditServiceScreen(context),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Record Visit'),
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

  // ==================== CATEGORY CHIPS ====================

  Widget _buildCategoryChipsRow() {
    final categories = ['All', ...kServiceCategories];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _categoryChip(categories[index]),
      ),
    );
  }

  Widget _categoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () => setState(() {
        _selectedCategory = category;
        _currentPageIndex = 0;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryDeepGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryDeepGreen : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              category,
              style: TextStyle(
                fontSize: 12.5,
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesArchiveScreen()));
      },
      icon: const Icon(Icons.archive_outlined, size: 16),
      label: const Text('Archive'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
    );
  }

  // ==================== FILTERS TOOLBAR ====================

  static const List<String> _dateFilterOptions = ['All time', 'Today', 'Last 7 days', 'Last 30 days', 'This month'];
  static const List<String> _statusFilterOptions = ['All', 'Paid', 'Partial', 'Unpaid'];

  Widget _buildFiltersToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    final hasActiveFilters =
        _searchQuery.isNotEmpty || _selectedCategory != 'All' || _dateFilter != 'Last 30 days' || _statusFilter != 'All';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search service by client, category, note...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
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
                        _searchQuery = '';
                        _currentPageIndex = 0;
                      }),
                    ),
            ),
            onChanged: (val) => setState(() {
              _searchQuery = val.trim();
              _currentPageIndex = 0;
            }),
          ),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _dateFilter,
          items: _dateFilterOptions,
          label: 'Date',
          onChanged: (val) => setState(() {
            _dateFilter = val;
            _currentPageIndex = 0;
          }),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _selectedCategory,
          items: ['All', ...kServiceCategories],
          label: 'Category',
          onChanged: (val) => setState(() {
            _selectedCategory = val;
            _currentPageIndex = 0;
          }),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _statusFilter,
          items: _statusFilterOptions,
          label: 'Status',
          onChanged: (val) => setState(() {
            _statusFilter = val;
            _currentPageIndex = 0;
          }),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _selectedCategory = 'All';
              _dateFilter = 'Last 30 days';
              _statusFilter = 'All';
              _currentPageIndex = 0;
            }),
            child: const Text('Reset'),
          ),
        ],
      ],
    );
  }

  Widget _toolbarDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: primaryDeepGreen),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text('$label: $v'))).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  // ==================== TABLE ====================

  String _invoiceNo(Service service) => 'SV-${(service.receiptNumber ?? 0).toString().padLeft(6, '0')}';

  Widget _buildServicesTable(List<Service> services, DateFormat dateFormatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
          child: Row(
            children: [
              _headerCell('Date', flex: 3),
              _headerCell('Service / Category', flex: 3),
              _headerCell('Client', flex: 2),
              _headerCell('Provider', flex: 2),
              _headerCell('Amount', flex: 2),
              _headerCell('Status', flex: 2),
              _headerCell('Payment Method', flex: 2),
              _headerCell('', flex: 1),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: services.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
            itemBuilder: (context, index) => _buildServiceRow(services[index], dateFormatter),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _buildServiceRow(Service service, DateFormat dateFormatter) {
    final status = _getPaymentStatus(service.totalPaid, service.totalAmount);
    final statusColor = _statusColor(service.totalPaid, service.totalAmount);
    final isSelected = _selectedService?.id == service.id;
    final serviceDate = service.serviceDate ?? DateTime.now();

    return InkWell(
      onTap: () => setState(() => _selectedService = service),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? primaryDeepGreen.withValues(alpha: 0.06) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateFormatter.format(serviceDate).split(',').first, style: const TextStyle(fontSize: 13)),
                  Text(DateFormat('hh:mm a').format(serviceDate),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryDeepGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(service.category, style: TextStyle(fontSize: 10.5, color: primaryDeepGreen, fontWeight: FontWeight.w600)),
                  ),
                  if (service.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Notes: ${service.description}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service.clientName ?? 'Walk-in', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(service.providedByName ?? 'Unknown', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(_moneyFormat.format(service.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service.paymentMethod ?? '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'view') {
                    setState(() => _selectedService = service);
                  } else if (value == 'edit') {
                    showAddEditServiceScreen(context, service: service);
                  } else if (value == 'delete') {
                    _confirmDeleteService(service);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red[400]))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAGINATION ====================

  Widget _buildPaginationBar({
    required ServiceProvider serviceProvider,
    required int totalFiltered,
    required int pageStart,
    required int pageEnd,
    required int totalPages,
  }) {
    final canGoNext = _currentPageIndex < totalPages - 1 || serviceProvider.hasMore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalFiltered == 0
                ? 'No services'
                : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered${serviceProvider.hasMore ? '+' : ''} services',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _displayPageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() {
                      _displayPageSize = val;
                      _currentPageIndex = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPageIndex > 0 ? () => setState(() => _currentPageIndex--) : null,
              ),
              Text('Page ${_currentPageIndex + 1} of $totalPages', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: serviceProvider.isLoadingMore
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: canGoNext && !serviceProvider.isLoadingMore
                    ? () async {
                        final needed = (_currentPageIndex + 2) * _displayPageSize;
                        if (needed > serviceProvider.services.length && serviceProvider.hasMore) {
                          await serviceProvider.loadMoreServices();
                        }
                        if (mounted) setState(() => _currentPageIndex++);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SERVICE DETAILS PANEL ====================

  Future<void> _confirmDeleteService(Service service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service?'),
        content: Text('This permanently deletes ${_invoiceNo(service)} (${service.name}). This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Provider.of<ServiceProvider>(context, listen: false).deleteService(service.id);
      if (!mounted) return;
      if (_selectedService?.id == service.id) setState(() => _selectedService = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Service deleted'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildServiceDetailsPanel(Service service, DateFormat dateOnlyFormatter, DateFormat timeOnlyFormatter) {
    final status = _getPaymentStatus(service.totalPaid, service.totalAmount);
    final statusColor = _statusColor(service.totalPaid, service.totalAmount);
    final serviceDate = service.serviceDate ?? DateTime.now();
    final client =
        service.clientId != null ? Provider.of<ClientProvider>(context, listen: false).getClientById(service.clientId!) : null;

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedService = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(_invoiceNo(service), style: TextStyle(fontSize: 12.5, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            Text('${dateOnlyFormatter.format(serviceDate)}, ${timeOnlyFormatter.format(serviceDate)}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: offWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text(status, style: TextStyle(color: statusColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _totalsRow('Paid Amount', _moneyFormat.format(service.totalPaid)),
                  _totalsRow('Payment Method', service.paymentMethod ?? 'Not recorded'),
                  if (service.transactionId != null && service.transactionId!.isNotEmpty)
                    _totalsRow('Transaction ID', service.transactionId!),
                  _totalsRow('Paid On', service.updatedAt != null ? dateOnlyFormatter.format(service.updatedAt!) : '-'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailField(Icons.category_outlined, 'Category', service.category),
            _detailField(Icons.person_outline, 'Client', service.clientName ?? 'Walk-in', subtitle: client?.phone),
            _detailField(Icons.badge_outlined, 'Provided By', service.providedByName ?? 'Unknown'),
            _detailField(Icons.calendar_today_outlined, 'Service Date', dateOnlyFormatter.format(serviceDate)),
            _detailField(Icons.edit_note_outlined, 'Notes', service.description.isNotEmpty ? service.description : '-'),
            if (service.updatedAt != null)
              _detailField(Icons.history_outlined, 'Created On',
                  '${dateOnlyFormatter.format(service.updatedAt!)}, ${timeOnlyFormatter.format(service.updatedAt!)}'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: service)));
                    },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showAddEditServiceScreen(context, service: service);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteService(service),
                    icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                    label: Text('Delete', style: TextStyle(color: Colors.red[400])),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red[200]!)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }

  Widget _detailField(IconData icon, String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
