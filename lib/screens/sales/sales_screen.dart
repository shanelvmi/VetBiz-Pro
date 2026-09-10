import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/client_provider.dart';
import '../../services/sales_summary_service.dart';
import 'add_sale_screen.dart';
import 'receipt_preview_screen.dart';
import 'sales_archive_screen.dart';
import '../../utils/subscription_guard.dart';

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
  String _dateFilter = 'Last 30 days';
  String _sellerFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Which sale is shown in the details panel (null = panel hidden,
  // table takes full width), and the display pagination window - a
  // page here is a view over whatever's already loaded (or gets
  // loaded on demand), independent of SaleProvider's own 25-per-fetch
  // Firestore batching.
  Sale? _selectedSale;
  int _displayPageSize = 10;
  int _currentPageIndex = 0;

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
    }
  }

  void _onSalesChanged() {
    if (!mounted || _saleProvider == null) return;
    final currentCount = _saleProvider!.sales.length;
    if (currentCount == _lastKnownSaleCount) return;
    _lastKnownSaleCount = currentCount;

    // The summary card reads a precomputed daily aggregate, written by
    // a Cloud Function shortly after each sale write - not the instant
    // the sale document itself is created. A short delay here gives
    // that function time to actually finish before re-fetching, so
    // this reliably picks up the new total instead of re-reading the
    // same still-stale aggregate the manual Refresh button could
    // otherwise hit if pressed immediately.
    _pendingSummaryRefresh?.cancel();
    _pendingSummaryRefresh = Timer(const Duration(seconds: 2), () {
      if (mounted) _loadRangeSummary();
    });
  }

  Future<void> _loadRangeSummary() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isSummaryLoading = true);

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

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

      if (mounted) {
        setState(() {
          _rangeSummary = {...totals, 'totalCollected': collected};
          _isSummaryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading range summary: $e');
      if (mounted) {
        setState(() => _isSummaryLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pendingSummaryRefresh?.cancel();
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
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');
    final dateOnlyFormatter = DateFormat('dd MMM yyyy');
    final timeOnlyFormatter = DateFormat('hh:mm a');

    final sortedSales = [...saleProvider.sales];
    sortedSales.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final now = DateTime.now();
    final filteredSales = sortedSales.where((sale) {
      final matchesSearch = _searchQuery.isEmpty ||
          sale.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          sale.soldByName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          _invoiceNo(sale).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.items.any((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase()));

      final status = _getPaymentStatus(sale.totalPaid, sale.totalAmount);
      final matchesStatus = _filterStatus == 'All' || status == _filterStatus;

      final matchesSeller = _sellerFilter == 'All' || sale.soldByName == _sellerFilter;

      final matchesDate = switch (_dateFilter) {
        'Today' => sale.timestamp.year == now.year && sale.timestamp.month == now.month && sale.timestamp.day == now.day,
        'Last 7 days' => sale.timestamp.isAfter(now.subtract(const Duration(days: 7))),
        'Last 30 days' => sale.timestamp.isAfter(now.subtract(const Duration(days: 30))),
        'This month' => sale.timestamp.year == now.year && sale.timestamp.month == now.month,
        _ => true, // 'All time'
      };

      return matchesSearch && matchesStatus && matchesSeller && matchesDate;
    }).toList();

    // Filter options this screen can offer are only ever as complete as
    // the sales already loaded - listing sellers seen only among what's
    // in memory, same honest limitation as the search bar above.
    final availableSellers = sortedSales.map((s) => s.soldByName).toSet().toList()..sort();

    // Display pagination is a window over whatever's already loaded
    // (or about to be), not a true "jump to page 1249" - Firestore's
    // cursor-based pagination genuinely can't do that without
    // significant extra infrastructure. Clamping the page index keeps
    // this consistent if the underlying list shrinks (e.g. after a
    // delete) while sitting on a later page.
    final totalPages = (filteredSales.length / _displayPageSize).ceil().clamp(1, 999999);
    if (_currentPageIndex >= totalPages) _currentPageIndex = totalPages - 1;
    if (_currentPageIndex < 0) _currentPageIndex = 0;
    final pageStart = _currentPageIndex * _displayPageSize;
    final pageEnd = (pageStart + _displayPageSize).clamp(0, filteredSales.length);
    final pageSales = filteredSales.sublist(pageStart.clamp(0, filteredSales.length), pageEnd);

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
                  child: filteredSales.isEmpty
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
                _buildPaginationBar(
                  saleProvider: saleProvider,
                  totalFiltered: filteredSales.length,
                  pageStart: pageStart,
                  pageEnd: pageEnd,
                  totalPages: totalPages,
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
      ('Revenue', _moneyFormat.format(total), Icons.bar_chart, Colors.blue),
      ('Collected', _moneyFormat.format(collected), Icons.account_balance_wallet_outlined, Colors.green),
      ('Pending', _moneyFormat.format(pending), Icons.pending_actions_outlined, warmAmber),
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
          value: _filterStatus,
          items: _statusFilterOptions,
          label: 'Payment Status',
          onChanged: (val) => setState(() {
            _filterStatus = val;
            _currentPageIndex = 0;
          }),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _sellerFilter,
          items: ['All', ...availableSellers],
          label: 'Seller',
          onChanged: (val) => setState(() {
            _sellerFilter = val;
            _currentPageIndex = 0;
          }),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _filterStatus = 'All';
              _dateFilter = 'Last 30 days';
              _sellerFilter = 'All';
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
              onNavigate: () => showAddSaleScreen(context),
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
                  Text(DateFormat('hh:mm a').format(sale.timestamp),
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
              child: Text(_moneyFormat.format(sale.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    required int totalFiltered,
    required int pageStart,
    required int pageEnd,
    required int totalPages,
  }) {
    final canGoNext = _currentPageIndex < totalPages - 1 || saleProvider.hasMore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalFiltered == 0
                ? 'No sales'
                : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered${saleProvider.hasMore ? '+' : ''} sales',
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
                icon: saleProvider.isLoadingMore
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: canGoNext && !saleProvider.isLoadingMore
                    ? () async {
                        // If the next page isn't loaded yet, fetch more
                        // before advancing - this is what keeps "Next"
                        // honest without pretending to jump to an
                        // arbitrary page number.
                        final needed = (_currentPageIndex + 2) * _displayPageSize;
                        if (needed > saleProvider.sales.length && saleProvider.hasMore) {
                          await saleProvider.loadMoreSales();
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
                          Text(_moneyFormat.format(item.unitPrice * item.quantity), style: const TextStyle(fontSize: 13.5)),
                          Text(_moneyFormat.format(item.unitPrice * item.quantity),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            _totalsRow('Subtotal', _moneyFormat.format(subtotal)),
            _totalsRow('Discount', _moneyFormat.format(totalDiscount)),
            _totalsRow('Total Amount', _moneyFormat.format(sale.totalAmount), bold: true, color: primaryDeepGreen),
            const SizedBox(height: 10),
            _totalsRow('Paid', _moneyFormat.format(sale.totalPaid), color: Colors.green),
            _totalsRow('Balance', _moneyFormat.format(balance), bold: true),
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

