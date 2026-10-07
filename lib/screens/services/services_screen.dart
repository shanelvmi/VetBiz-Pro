import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/service.dart';
import '../../constants/service_categories.dart';
import '../../providers/service_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../providers/client_provider.dart';
import '../../services/cursor_paginated_list_controller.dart';
import '../../widgets/firestore_error_view.dart';
import 'add_edit_service_screen.dart';
import 'services_archive_screen.dart';
import 'service_receipt_preview_screen.dart';
import '../../utils/subscription_guard.dart';
import '../../theme/app_palette.dart';
import '../../data/collections.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final Color primaryDeepGreen = AppPalette.primary;
  final Color warmAmber = AppPalette.accent;
  final Color offWhite = AppPalette.background;

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

  // Which service is shown in the details panel. Pagination state now
  // lives entirely in servicesListController below.
  Service? _selectedService;

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
  // Periodically checks (never a live listener) whether new services
  // have landed since the current browsing session's snapshot moment,
  // to drive the "N new services available - Refresh" banner.
  Timer? _newRecordsCheckTimer;
  Timer? _searchDebounce;

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
      _openServicesListSession();
      _newRecordsCheckTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _serviceProvider?.servicesListController.checkForNewRecords(),
      );
    }
  }

  /// Records the toolbar's current filters onto ServiceProvider, then
  /// (re)opens the browsing session for them - a no-op if the
  /// signature hasn't actually changed and a session's already open.
  void _openServicesListSession({bool forceRefresh = false}) {
    final provider = _serviceProvider;
    if (provider == null) return;
    final signature = provider.updateServicesListFilters(
      searchTerm: _searchQuery,
      statusFilter: _statusFilter,
      categoryFilter: _selectedCategory,
      dateFilter: _dateFilter,
    );
    provider.servicesListController.openSession(signature, forceRefresh: forceRefresh);
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
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.services)
          .where('serviceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      double paidAmount = 0;
      double outstanding = 0;
      double nonCashAmount = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
        paidAmount += totalPaid;
        outstanding += (totalAmount - totalPaid);
        if (data['paymentMethod'] != null && data['paymentMethod'] != 'Cash') {
          nonCashAmount += totalPaid;
        }
      }

      if (!mounted) return;
      setState(() {
        _rangeSummary = {
          'count': snap.docs.length.toDouble(),
          'paidAmount': paidAmount,
          'outstanding': outstanding,
          'nonCashAmount': nonCashAmount,
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
    _newRecordsCheckTimer?.cancel();
    _searchDebounce?.cancel();
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
                      Expanded(child: _buildMetricsRow()),
                      const SizedBox(width: 12),
                      _buildArchiveButton(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildFiltersToolbar(),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: serviceProvider.servicesListController,
                    builder: (context, _) {
                      final controller = serviceProvider.servicesListController;
                      final pageServices = controller.items;
                      return Column(
                        children: [
                          if (controller.newRecordsAvailable > 0)
                            Container(
                              width: double.infinity,
                              color: primaryDeepGreen.withValues(alpha: 0.08),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.fiber_new, size: 18, color: primaryDeepGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${controller.newRecordsAvailable} new service'
                                      '${controller.newRecordsAvailable == 1 ? '' : 's'} available',
                                      style: TextStyle(fontSize: 13, color: primaryDeepGreen),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => serviceProvider.servicesListController.refreshSession(),
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: controller.error != null && pageServices.isEmpty
                                ? Center(child: FirestoreErrorView(error: controller.error))
                                : controller.isLoading && pageServices.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : pageServices.isEmpty
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
                          _buildPaginationBar(serviceProvider: serviceProvider, controller: controller),
                        ],
                      );
                    },
                  ),
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
    final nonCashAmount = summary?['nonCashAmount'] ?? 0.0;

    final metrics = [
      ('Total Services', '$count', Icons.medical_services_outlined, primaryDeepGreen),
      ('Paid Amount', _moneyFormat.format(paidAmount), Icons.account_balance_wallet_outlined, Colors.blue),
      ('Outstanding', _moneyFormat.format(outstanding), Icons.pending_actions_outlined, warmAmber),
      ('Digital Payments', _moneyFormat.format(nonCashAmount), Icons.phone_iphone_outlined, Colors.green),
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
              onNavigate: () async {
                await showAddEditServiceScreen(context);
                if (mounted) _openServicesListSession(forceRefresh: true);
              },
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
                      onPressed: () {
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = '');
                        _searchController.clear();
                        _openServicesListSession();
                      },
                    ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), _openServicesListSession);
            },
          ),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _dateFilter,
          items: _dateFilterOptions,
          label: 'Date',
          onChanged: (val) {
            setState(() => _dateFilter = val);
            _openServicesListSession();
          },
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _selectedCategory,
          items: ['All', ...kServiceCategories],
          label: 'Category',
          onChanged: (val) {
            setState(() => _selectedCategory = val);
            _openServicesListSession();
          },
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _statusFilter,
          items: _statusFilterOptions,
          label: 'Status',
          onChanged: (val) {
            setState(() => _statusFilter = val);
            _openServicesListSession();
          },
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'All';
                _dateFilter = 'Last 30 days';
                _statusFilter = 'All';
              });
              _openServicesListSession();
            },
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
                  if (Provider.of<UserRoleProvider>(context, listen: false).isAdmin)
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
    required CursorPaginatedListController<Service> controller,
  }) {
    final pageSize = controller.pageSize;
    final itemCount = controller.items.length;
    final pageStart = itemCount == 0 ? 0 : (controller.currentPage - 1) * pageSize + 1;
    final pageEnd = (controller.currentPage - 1) * pageSize + itemCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            itemCount == 0 ? 'No services' : 'Showing $pageStart to $pageEnd',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) serviceProvider.servicesListController.setPageSize(val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.hasPreviousPage ? () => controller.goToPreviousPage() : null,
              ),
              Text('Page ${controller.currentPage}', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: controller.isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: controller.hasNextPage && !controller.isLoading
                    ? () => controller.goToNextPage()
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
      _openServicesListSession(forceRefresh: true);
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
                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
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
