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
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_ranges.dart';
import '../../config/payment_methods.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../services/trash_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {


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
        AppTimeouts.newRecordsPoll,
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
    _pendingSummaryRefresh = Timer(AppTimeouts.servicesSummaryRefresh, () {
      if (mounted) _loadRangeSummary();
    });
  }

  Future<void> _loadRangeSummary() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isSummaryLoading = true);
    try {
      final cutoff = DateTime.now().subtract(AppRanges.defaultListRange);
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
        if (data['paymentMethod'] != null && data['paymentMethod'] != PaymentMethod.cash.key) {
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
    if (paid >= total) return context.colors.success;
    if (paid > 0) return context.colors.warning;
    return context.colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final dateFormatter = AppDateFormat.dateTime24;
    final dateOnlyFormatter = AppDateFormat.date;
    final timeOnlyFormatter = AppDateFormat.time12;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _buildMetricsRow()),
                      const SizedBox(width: AppSpacing.s12),
                      _buildArchiveButton(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
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
                              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                              child: Row(
                                children: [
                                  Icon(Icons.fiber_new, size: AppIconSize.i18, color: context.colors.primary),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Text(
                                      '${controller.newRecordsAvailable} new service'
                                      '${controller.newRecordsAvailable == 1 ? '' : 's'} available',
                                      style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.primary),
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
                                            Icon(Icons.medical_services_outlined, size: AppIconSize.i64, color: context.colors.textDisabled),
                                            const SizedBox(height: AppSpacing.s16),
                                            Text(
                                              _searchQuery.isEmpty ? 'No services yet' : 'No services match your filters',
                                              style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted),
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
      ('Total Services', '$count', Icons.medical_services_outlined, context.colors.primary),
      ('Paid Amount', Money.format(paidAmount), Icons.account_balance_wallet_outlined, context.colors.info),
      ('Outstanding', Money.format(outstanding), Icons.pending_actions_outlined, context.colors.accent),
      ('Digital Payments', Money.format(nonCashAmount), Icons.phone_iphone_outlined, context.colors.success),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < AppBreakpoints.compact;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 2 : 4,
            mainAxisExtent: 90,
            crossAxisSpacing: AppSpacing.s12,
            mainAxisSpacing: AppSpacing.s12,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
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
                      BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r7)),
                  child: Icon(icon, color: color, size: AppIconSize.i14),
                ),
                const SizedBox(width: AppSpacing.s8),
                isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(value, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
            Text('Last 30 days', style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textDisabled)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Service Records', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('Track all services provided to your clients', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () => navigateOrShowLockedDialog(
              context,
              const AddEditServiceScreen(),
              onNavigate: () async {
                await showAddEditServiceScreen(context);
                if (mounted) _openServicesListSession(forceRefresh: true);
              },
            ),
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: const Text('Record Visit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
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
      icon: const Icon(Icons.archive_outlined, size: AppIconSize.i16),
      label: const Text('Archive'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
        side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
    );
  }

  // ==================== FILTERS TOOLBAR ====================

  static const List<String> _dateFilterOptions = ['All time', 'Today', 'Last 7 days', 'Last 30 days', 'This month'];
  static const List<String> _statusFilterOptions = ['All', 'Paid', 'Partial', 'Unpaid'];

  Widget _buildFiltersToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
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
              hintStyle: const TextStyle(fontSize: AppFontSize.f13),
              prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
              filled: true,
              fillColor: context.colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
              border: border,
              enabledBorder: border,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: AppIconSize.i18),
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
              _searchDebounce = Timer(AppTimeouts.searchDebounce, _openServicesListSession);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        _toolbarDropdown<String>(
          value: _dateFilter,
          items: _dateFilterOptions,
          label: 'Date',
          onChanged: (val) {
            setState(() => _dateFilter = val);
            _openServicesListSession();
          },
        ),
        const SizedBox(width: AppSpacing.s10),
        _toolbarDropdown<String>(
          value: _selectedCategory,
          items: ['All', ...kServiceCategories],
          label: 'Category',
          onChanged: (val) {
            setState(() => _selectedCategory = val);
            _openServicesListSession();
          },
        ),
        const SizedBox(width: AppSpacing.s10),
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
          const SizedBox(width: AppSpacing.s10),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
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
            separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
            itemBuilder: (context, index) => _buildServiceRow(services[index], dateFormatter),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateFormatter.format(serviceDate).split(',').first, style: const TextStyle(fontSize: AppFontSize.f13)),
                  Text(AppDateFormat.time12.format(serviceDate),
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.s3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                    child: Text(service.category, style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service.clientName ?? 'Walk-in', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(service.providedByName ?? 'Unknown', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(Money.format(service.totalAmount), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: AppAlpha.a10),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service.paymentMethod ?? '-', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: AppIconSize.i18, color: context.colors.textMuted),
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
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: context.colors.dangerSoft))),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            itemCount == 0 ? 'No services' : 'Showing $pageStart to $pageEnd',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
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
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.hasPreviousPage ? () => controller.goToPreviousPage() : null,
              ),
              Text('Page ${controller.currentPage}', style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: controller.isLoading
                    ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
            child: Text('Delete', style: TextStyle(color: context.colors.dangerSoft)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Read before the await: Undo may run after this screen is gone.
    final facilityId = _facilityId;

    try {
      await Provider.of<ServiceProvider>(context, listen: false).deleteService(service.id);
      if (!mounted) return;
      if (_selectedService?.id == service.id) setState(() => _selectedService = null);
      _openServicesListSession(forceRefresh: true);
      // deleteService moves it to Trash (a soft delete, same id), so Undo
      // puts it back with the Trash screen's own restore.
      AppFeedback.undo('Service moved to Trash', onUndo: () => _undoDeleteService(facilityId, service.id));
    } catch (e, st) {
      AppFeedback.error("Couldn't delete the service", error: e, stackTrace: st);
    }
  }

  Future<void> _undoDeleteService(String? facilityId, String id) async {
    if (facilityId == null || facilityId.isEmpty) return;
    try {
      await TrashService.restoreById(
        facilityId: facilityId,
        trashCollection: Collections.trashServices,
        liveCollection: Collections.services,
        id: id,
      );
      AppFeedback.success('Service restored');
      if (mounted) _openServicesListSession(forceRefresh: true);
    } catch (e, st) {
      AppFeedback.error("Couldn't restore the service", error: e, stackTrace: st);
    }
  }

  Widget _buildServiceDetailsPanel(Service service, DateFormat dateOnlyFormatter, DateFormat timeOnlyFormatter) {
    final status = _getPaymentStatus(service.totalPaid, service.totalAmount);
    final statusColor = _statusColor(service.totalPaid, service.totalAmount);
    final serviceDate = service.serviceDate ?? DateTime.now();
    final client =
        service.clientId != null ? Provider.of<ClientProvider>(context, listen: false).getClientById(service.clientId!) : null;

    return Container(
      color: context.colors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Details', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i20),
                  onPressed: () => setState(() => _selectedService = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(service.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold)),
                ),
              ],
            ),
            Text(_invoiceNo(service), style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted, fontWeight: AppFontWeight.semibold)),
            Text('${dateOnlyFormatter.format(serviceDate)}, ${timeOnlyFormatter.format(serviceDate)}',
                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s14),
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Information', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                      Text(status, style: TextStyle(color: statusColor, fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  _totalsRow('Paid Amount', Money.format(service.totalPaid)),
                  _totalsRow('Payment Method', service.paymentMethod ?? 'Not recorded'),
                  if (service.transactionId != null && service.transactionId!.isNotEmpty)
                    _totalsRow('Transaction ID', service.transactionId!),
                  _totalsRow('Paid On', service.updatedAt != null ? dateOnlyFormatter.format(service.updatedAt!) : '-'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            _detailField(Icons.category_outlined, 'Category', service.category),
            _detailField(Icons.person_outline, 'Client', service.clientName ?? 'Walk-in', subtitle: client?.phone),
            _detailField(Icons.badge_outlined, 'Provided By', service.providedByName ?? 'Unknown'),
            _detailField(Icons.calendar_today_outlined, 'Service Date', dateOnlyFormatter.format(serviceDate)),
            _detailField(Icons.edit_note_outlined, 'Notes', service.description.isNotEmpty ? service.description : '-'),
            if (service.updatedAt != null)
              _detailField(Icons.history_outlined, 'Created On',
                  '${dateOnlyFormatter.format(service.updatedAt!)}, ${timeOnlyFormatter.format(service.updatedAt!)}'),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: service)));
                    },
                    icon: const Icon(Icons.print_outlined, size: AppIconSize.i16),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showAddEditServiceScreen(context, service: service);
                    },
                    icon: const Icon(Icons.edit_outlined, size: AppIconSize.i16),
                    label: const Text('Edit'),
                  ),
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteService(service),
                      icon: Icon(Icons.delete_outline, size: AppIconSize.i16, color: context.colors.dangerSoft),
                      label: Text('Delete', style: TextStyle(color: context.colors.dangerSoft)),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
          Text(
            value,
            style: TextStyle(fontSize: AppFontSize.f13_5, fontWeight: bold ? AppFontWeight.bold : AppFontWeight.regular, color: color),
          ),
        ],
      ),
    );
  }

  Widget _detailField(IconData icon, String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.i18, color: context.colors.textMuted),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                Text(value, style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.semibold)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
