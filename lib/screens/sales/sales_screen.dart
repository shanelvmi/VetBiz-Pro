import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../providers/client_provider.dart';
import '../../services/sales_summary_service.dart';
import '../../services/cursor_paginated_list_controller.dart';
import '../../widgets/firestore_error_view.dart';
import 'add_sale_screen.dart';
import 'receipt_preview_screen.dart';
import 'sales_archive_screen.dart';
import '../../utils/subscription_guard.dart';
import '../../theme/app_palette.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final Color primaryDeepGreen = AppPalette.primary;
  final Color warmAmber = AppPalette.accent;
  final Color offWhite = AppPalette.background;


  String _searchQuery = '';
  String _filterStatus = 'All';
  String _dateFilter = 'Last 30 days';
  String _sellerFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Which sale is shown in the details panel (null = panel hidden,
  // table takes full width). Pagination state (page size, current
  // page) now lives entirely in salesListController below, not here.
  Sale? _selectedSale;

  // Summary card totals - deliberately NOT derived from whatever sales
  // happen to be loaded in the paginated list below. Those only ever
  // reflect "however far the user has scrolled/paged", which isn't a
  // meaningful number to headline. This instead reads the precomputed
  // daily summaries for a fixed, statable period (Last 30 Days), so the
  // figure means something concrete regardless of pagination or archiving.
  final SalesSummaryService _summaryService = SalesSummaryService();
  String? _facilityId;
  Map<String, double>? _rangeSummary;
  bool _isSummaryLoading = false;

  // Auto-refreshes the summary shortly after a new sale appears in the
  // live list below, instead of leaving it to go stale until the user
  // manually hits Refresh or navigates away and back.
  SaleProvider? _saleProvider;
  int _lastKnownSaleCount = 0;
  Timer? _pendingSummaryRefresh;
  // Periodically checks (never a live listener) whether new sales have
  // landed since the current browsing session's snapshot moment, to
  // drive the "N new sales available - Refresh" banner.
  Timer? _newRecordsCheckTimer;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      _facilityId = facilityId;
      _saleProvider = Provider.of<SaleProvider>(context, listen: false);
      _saleProvider!.init(facilityId);
      _lastKnownSaleCount = _saleProvider!.sales.length;
      _saleProvider!.addListener(_onSalesChanged);
      _loadRangeSummary();
      _openSalesListSession();
      _newRecordsCheckTimer = Timer.periodic(
        AppTimeouts.newRecordsPoll,
        (_) => _saleProvider?.salesListController.checkForNewRecords(),
      );
    }
  }

  /// Records the toolbar's current filters onto SaleProvider, then
  /// (re)opens the browsing session for them - a no-op if the
  /// signature hasn't actually changed and a session's already open,
  /// same as any other call site of this.
  void _openSalesListSession({bool forceRefresh = false}) {
    final provider = _saleProvider;
    if (provider == null) return;
    final signature = provider.updateSalesListFilters(
      searchTerm: _searchQuery,
      statusFilter: _filterStatus,
      sellerFilter: _sellerFilter,
      dateFilter: _dateFilter,
    );
    provider.salesListController.openSession(signature, forceRefresh: forceRefresh);
  }

  void _onSalesChanged() {
    if (!mounted || _saleProvider == null) return;
    final currentCount = _saleProvider!.sales.length;
    if (currentCount == _lastKnownSaleCount) return;
    _lastKnownSaleCount = currentCount;

    // The summary card reads a precomputed daily aggregate, written by
    // a Cloud Function shortly after each sale write - not the instant
    // the sale document itself is created. _loadRangeSummary itself now
    // retries until that aggregate actually reflects this change (or
    // gives up after a few attempts), rather than a single, fixed-delay
    // guess that silently stayed stale whenever the function ran a
    // little slower than expected.
    _pendingSummaryRefresh?.cancel();
    _pendingSummaryRefresh = Timer(AppTimeouts.salesSummaryRefresh, () {
      if (mounted) _loadRangeSummary();
    });
  }

  Future<void> _loadRangeSummary() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isSummaryLoading = true);

    final now = DateTime.now();
    final start = now.subtract(AppRanges.defaultListRange);
    final previousCollected = _rangeSummary?['totalCollected'];

    // Retries a few times, spaced further apart each time, until the
    // fetched total actually differs from what it was before this
    // change - the Cloud Function's own latency is unpredictable (cold
    // starts especially), so a single fixed-delay attempt either fires
    // too early and silently keeps showing a stale total, or has to
    // guess a delay long enough to cover the worst case every time.
    // Retrying instead adapts to however long this specific write
    // actually takes, and gives up cleanly after a few tries rather
    // than retrying forever.
    const retryDelays = AppTimeouts.salesSummaryRetryDelays;

    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      if (retryDelays[attempt] > Duration.zero) {
        await Future.delayed(retryDelays[attempt]);
        if (!mounted) return;
      }

      try {
        final results = await Future.wait([
          _summaryService.getRangeTotals(
            facilityId: facilityId,
            start: start,
            end: now,
          ),
          _summaryService.getTotalCollected(
            facilityId: facilityId,
            start: start,
            end: now,
          ),
        ]);

        final totals = results[0] as Map<String, double>;
        final collected = results[1] as double;

        if (!mounted) return;
        setState(() {
          _rangeSummary = {...totals, 'totalCollected': collected};
          _isSummaryLoading = false;
        });

        // Changed from before this refresh started (or this is the
        // very first load, with nothing to compare against) - done,
        // no need to keep retrying.
        if (previousCollected == null || collected != previousCollected) return;
      } catch (e) {
        debugPrint('Error loading range summary: $e');
        if (mounted) setState(() => _isSummaryLoading = false);
        return;
      }
    }
  }

  @override
  void dispose() {
    _pendingSummaryRefresh?.cancel();
    _newRecordsCheckTimer?.cancel();
    _searchDebounce?.cancel();
    _saleProvider?.removeListener(_onSalesChanged);
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
    final saleProvider = Provider.of<SaleProvider>(context);
    final dateFormatter = AppDateFormat.dateTime24;
    final dateOnlyFormatter = AppDateFormat.date;
    final timeOnlyFormatter = AppDateFormat.time12;

    // A low-stakes dropdown convenience only, not part of search or
    // filter correctness (which is now a real query, further below) -
    // drawn from whichever sales this older, separate mechanism
    // happens to have live/loaded, same honest limitation the search
    // box used to have entirely. A full facility-staff query would be
    // a more complete source, but a bigger, separate change.
    final availableSellers = saleProvider.sales.map((s) => s.soldByName).toSet().toList()..sort();

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
                  child: _buildFiltersToolbar(availableSellers),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: saleProvider.salesListController,
                    builder: (context, _) {
                      final controller = saleProvider.salesListController;
                      final pageSales = controller.items;
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
                                      '${controller.newRecordsAvailable} new sale'
                                      '${controller.newRecordsAvailable == 1 ? '' : 's'} available',
                                      style: TextStyle(fontSize: 13, color: primaryDeepGreen),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => saleProvider.salesListController.refreshSession(),
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: controller.error != null && pageSales.isEmpty
                                ? Center(child: FirestoreErrorView(error: controller.error))
                                : controller.isLoading && pageSales.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : pageSales.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchQuery.isEmpty ? 'No sales yet' : 'No sales match your filters',
                                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _buildSalesTable(pageSales, dateFormatter),
                          ),
                          _buildPaginationBar(saleProvider: saleProvider, controller: controller),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_selectedSale != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: _buildSaleDetailsPanel(_selectedSale!, dateOnlyFormatter, timeOnlyFormatter),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== METRICS ROW ====================

  Widget _buildMetricsRow() {
    final summary = _rangeSummary;
    // Only the very first load (before any data has ever arrived) is
    // worth a loading indicator - a background refresh after a new
    // sale still has the previous numbers to show, and flashing a
    // spinner over already-visible values on every refresh would be
    // more jarring than just quietly updating them once they land.
    final isFirstLoadPending = summary == null && _isSummaryLoading;

    final count = summary?['saleCount']?.toInt() ?? 0;
    final total = summary?['totalAmount'] ?? 0.0;
    // "Of the sales made this period, how much is still unpaid as of
    // now" - this one legitimately stays tied to the sale's own record.
    final paidOnPeriodSales = summary?['totalPaid'] ?? 0.0;
    final pending = total - paidOnPeriodSales;
    // "How much actual cash came in during this period" - sourced from
    // dailyCollections, so a payment collected today on an old credit
    // sale counts here today, not silently filed under the sale's
    // original date.
    final collected = summary?['totalCollected'] ?? 0.0;

    final metrics = [
      ('Total Sales', '$count', Icons.receipt_long_outlined, primaryDeepGreen),
      ('Revenue', Money.format(total), Icons.bar_chart, Colors.blue),
      ('Collected', Money.format(collected), Icons.account_balance_wallet_outlined, Colors.green),
      ('Pending', Money.format(pending), Icons.pending_actions_outlined, warmAmber),
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

  Widget _buildArchiveButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesArchiveScreen()));
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

  Widget _buildFiltersToolbar(List<String> availableSellers) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    final hasActiveFilters =
        _searchQuery.isNotEmpty || _filterStatus != 'All' || _dateFilter != 'Last 30 days' || _sellerFilter != 'All';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search sale by product, client, invoice...',
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
                        _openSalesListSession();
                      },
                    ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
              _searchDebounce?.cancel();
              _searchDebounce = Timer(AppTimeouts.searchDebounce, _openSalesListSession);
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
            _openSalesListSession();
          },
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _filterStatus,
          items: _statusFilterOptions,
          label: 'Payment Status',
          onChanged: (val) {
            setState(() => _filterStatus = val);
            _openSalesListSession();
          },
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _sellerFilter,
          items: ['All', ...availableSellers],
          label: 'Seller',
          onChanged: (val) {
            setState(() => _sellerFilter = val);
            _openSalesListSession();
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
                _filterStatus = 'All';
                _dateFilter = 'Last 30 days';
                _sellerFilter = 'All';
              });
              _openSalesListSession();
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
          Text('Sales Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Track and manage all sales transactions', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadRangeSummary,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () => navigateOrShowLockedDialog(
              context,
              const AddSaleScreen(),
              onNavigate: () async {
                await showAddSaleScreen(context);
                if (mounted) _openSalesListSession(forceRefresh: true);
              },
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Record Sale'),
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

  // ==================== TABLE ====================

  String _invoiceNo(Sale sale) => 'SL-${(sale.receiptNumber ?? 0).toString().padLeft(6, '0')}';

  Widget _buildSalesTable(List<Sale> sales, DateFormat dateFormatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
          child: Row(
            children: [
              _headerCell('Date', flex: 3),
              _headerCell('Invoice No.', flex: 2),
              _headerCell('Client', flex: 2),
              _headerCell('Items', flex: 3),
              _headerCell('Amount', flex: 2),
              _headerCell('Payment Status', flex: 2),
              _headerCell('Seller', flex: 2),
              _headerCell('', flex: 1),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
            itemBuilder: (context, index) => _buildSaleRow(sales[index], dateFormatter),
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

  Widget _buildSaleRow(Sale sale, DateFormat dateFormatter) {
    final status = _getPaymentStatus(sale.totalPaid, sale.totalAmount);
    final statusColor = _statusColor(sale.totalPaid, sale.totalAmount);
    final isSelected = _selectedSale?.id == sale.id;
    final firstItem = sale.items.isNotEmpty ? sale.items.first : null;

    return InkWell(
      onTap: () => setState(() => _selectedSale = sale),
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
                  Text(dateFormatter.format(sale.timestamp).split(',').first, style: const TextStyle(fontSize: 13)),
                  Text(AppDateFormat.time12.format(sale.timestamp),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _invoiceNo(sale),
                style: TextStyle(fontSize: 13, color: primaryDeepGreen, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(sale.clientName ?? 'Walk-in', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 3,
              child: firstItem == null
                  ? const Text('-', style: TextStyle(fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${firstItem.name} \u00d7 ${firstItem.quantity}',
                            style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                      ],
                    ),
            ),
            Expanded(
              flex: 2,
              child: Text(Money.format(sale.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              child: Text(sale.soldByName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'view') {
                    setState(() => _selectedSale = sale);
                  } else if (value == 'delete') {
                    _confirmDeleteSale(sale);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
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
    required SaleProvider saleProvider,
    required CursorPaginatedListController<Sale> controller,
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
            itemCount == 0 ? 'No sales' : 'Showing $pageStart to $pageEnd',
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
                    if (val != null) saleProvider.salesListController.setPageSize(val);
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

  // ==================== SALE DETAILS PANEL ====================

  Future<void> _confirmDeleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: Text('This permanently deletes ${_invoiceNo(sale)} and restores its stock. This cannot be undone.'),
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
      final facilityId = _facilityId;
      if (facilityId == null) return;
      await Provider.of<SaleProvider>(context, listen: false).deleteSale(sale.id, facilityId);
      if (!mounted) return;
      if (_selectedSale?.id == sale.id) setState(() => _selectedSale = null);
      _openSalesListSession(forceRefresh: true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sale deleted'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildSaleDetailsPanel(Sale sale, DateFormat dateOnlyFormatter, DateFormat timeOnlyFormatter) {
    final status = _getPaymentStatus(sale.totalPaid, sale.totalAmount);
    final statusColor = _statusColor(sale.totalPaid, sale.totalAmount);
    final subtotal = sale.items.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
    final totalDiscount = sale.items.fold<double>(0, (sum, i) => sum + i.discount);
    final balance = sale.totalAmount - sale.totalPaid;
    final client =
        sale.clientId != null ? Provider.of<ClientProvider>(context, listen: false).getClientById(sale.clientId!) : null;

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
                const Text('Sale Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedSale = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_invoiceNo(sale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text('${dateOnlyFormatter.format(sale.timestamp)}, ${timeOnlyFormatter.format(sale.timestamp)}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text('${sale.items.length} item${sale.items.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            Text('\u00d7 ${item.quantity}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Money.format(item.unitPrice * item.quantity), style: const TextStyle(fontSize: 13.5)),
                          Text(Money.format(item.unitPrice * item.quantity),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            _totalsRow('Subtotal', Money.format(subtotal)),
            _totalsRow('Discount', Money.format(totalDiscount)),
            _totalsRow('Total Amount', Money.format(sale.totalAmount), bold: true, color: primaryDeepGreen),
            const SizedBox(height: 10),
            _totalsRow('Paid', Money.format(sale.totalPaid), color: Colors.green),
            _totalsRow('Balance', Money.format(balance), bold: true),
            const Divider(height: 24),
            _detailField(Icons.person_outline, 'Client', sale.clientName ?? 'Walk-in', subtitle: client?.phone),
            _detailField(Icons.badge_outlined, 'Seller', sale.soldByName),
            _detailField(Icons.payment_outlined, 'Payment Method', sale.paymentMethod ?? 'Not recorded'),
            _detailField(Icons.edit_note_outlined, 'Notes', (sale.notes?.isNotEmpty == true) ? sale.notes! : '-'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(sale: sale)));
                    },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(sale: sale)));
                    },
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                  ),
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteSale(sale),
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
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
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

