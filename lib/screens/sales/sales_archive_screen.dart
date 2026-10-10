import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/sale.dart';
import '../../providers/facility_provider.dart';
import 'receipt_preview_screen.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

class SalesArchiveScreen extends StatefulWidget {
  const SalesArchiveScreen({super.key});

  @override
  State<SalesArchiveScreen> createState() => _SalesArchiveScreenState();
}

class _SalesArchiveScreenState extends State<SalesArchiveScreen> {


  static const int _pageSize = AppLimits.archivePageSize;

  // Must match ARCHIVE_AFTER_DAYS in functions/index.js - anything newer
  // than this hasn't reached the archive yet.
  static const int _archiveCutoffDays = AppRanges.archiveCutoffDays;
  // Default initial window shown on open: the most recently archived 90
  // days, ending right at the cutoff. Lets the screen show something
  // immediately instead of forcing a dialog before any data appears - the
  // Search button still lets the user widen or change the range anytime.

  List<Map<String, dynamic>> _archivedSales = [];
  bool _isLoading = false;
  DateTime? _searchStart;
  DateTime? _searchEnd;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Which archived sale is shown in the details panel, the display
  // pagination window (over whatever's already loaded), and a
  // client-side text search over the currently loaded page - matches
  // the main Sales screen's pattern. Kept separate from the existing
  // date-range search dialog, which re-queries Firestore server-side.
  Map<String, dynamic>? _selectedSale;
  int _displayPageSize = 10;
  int _currentPageIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cutoff =
        DateTime.now().subtract(AppRanges.archiveCutoff);
    _searchEnd = cutoff;
    _searchStart = cutoff.subtract(AppRanges.archiveDefaultWindow);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArchivedSales();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSearchDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SearchArchiveDialog(),
    );

    // Cancelling just dismisses the dialog now - the screen already has
    // data showing, there's nothing to navigate away from.
    if (result == null) return;

    setState(() {
      _searchStart = result['startDate'];
      _searchEnd = result['endDate'];
    });

    await _loadArchivedSales();
  }

  /// First page of a fresh search - resets pagination state.
  Future<void> _loadArchivedSales() async {
    setState(() {
      _isLoading = true;
      _archivedSales = [];
      _lastDoc = null;
      _hasMore = true;
    });

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    await _fetchArchivedSalesPage(facilityId);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Fetch one page (the next [_pageSize] docs after [_lastDoc], or the
  /// first page if [_lastDoc] is null) and append it to [_archivedSales].
  /// This is what keeps a scroll through months of archived sales from
  /// pulling everything in one shot.
  Future<void> _fetchArchivedSalesPage(String facilityId) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.archivedSales);

      if (_searchStart != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_searchStart!));
      }
      if (_searchEnd != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_searchEnd!.add(AppRanges.day)));
      }

      query = query.orderBy('timestamp', descending: true);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      query = query.limit(_pageSize);

      final snapshot = await query.get();

      final newSales = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
      }
      _hasMore = snapshot.docs.length >= _pageSize;

      if (mounted) {
        setState(() {
          _archivedSales = [..._archivedSales, ...newSales];
        });
      }
    } catch (e) {
      debugPrint('Error loading archived sales: $e');
      if (mounted) {
        setState(() => _hasMore = false);
      }
    }
  }

  /// Load the next page for the current search (called from the
  /// "Load more" footer at the bottom of the list).
  Future<void> _loadMoreArchivedSales() async {
    if (_isLoadingMore || !_hasMore) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isLoadingMore = true);
    await _fetchArchivedSalesPage(facilityId);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
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

  String _invoiceNo(Map<String, dynamic> sale) {
    final receiptNumber = sale['receiptNumber'];
    return 'SL-${(receiptNumber ?? 0).toString().padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = AppDateFormat.dateTime24;
    final dateOnlyFormatter = AppDateFormat.date;
    final timeOnlyFormatter = AppDateFormat.time12;

    final filteredSales = _archivedSales.where((sale) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final clientName = (sale['clientName'] as String? ?? '').toLowerCase();
      final soldByName = (sale['soldByName'] as String? ?? '').toLowerCase();
      final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return clientName.contains(q) ||
          soldByName.contains(q) ||
          _invoiceNo(sale).toLowerCase().contains(q) ||
          items.any((item) => (item['name'] as String? ?? '').toLowerCase().contains(q));
    }).toList();

    final totalAmount = filteredSales.fold<double>(
        0, (sum, sale) => sum + ((sale['totalAmount'] ?? 0.0) as num).toDouble());

    // Same honest display-pagination window as the main Sales screen -
    // a page here is a view over whatever's already loaded (or gets
    // loaded on demand via _loadMoreArchivedSales), not a true jump to
    // an arbitrary page number.
    final totalPages = (filteredSales.length / _displayPageSize).ceil().clamp(1, 999999);
    if (_currentPageIndex >= totalPages) _currentPageIndex = totalPages - 1;
    if (_currentPageIndex < 0) _currentPageIndex = 0;
    final pageStart = _currentPageIndex * _displayPageSize;
    final pageEnd = (pageStart + _displayPageSize).clamp(0, filteredSales.length);
    final pageSales = filteredSales.sublist(pageStart.clamp(0, filteredSales.length), pageEnd);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
                        child: _buildInfoBanner(filteredSales.length, totalAmount),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                        child: _buildSearchBar(),
                      ),
                      Expanded(
                        child: filteredSales.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.archive_outlined, size: AppIconSize.i64, color: context.colors.textDisabled),
                                    const SizedBox(height: AppSpacing.s16),
                                    Text(
                                      'No archived sales found',
                                      style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      'Try a different search or date range',
                                      style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textHint),
                                    ),
                                  ],
                                ),
                              )
                            : _buildArchiveTable(pageSales, dateFormatter),
                      ),
                      _buildPaginationBar(
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
                    child: _buildDetailsPanel(_selectedSale!, dateOnlyFormatter, timeOnlyFormatter),
                  ),
                ],
              ],
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
          Text('Sales Archive', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('Sales archived after $_archiveCutoffDays days', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: OutlinedButton.icon(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.date_range_outlined, size: AppIconSize.i16),
            label: const Text('Date Range'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(int foundCount, double totalAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a20)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.colors.primary, size: AppIconSize.i18),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              _searchStart != null && _searchEnd != null
                  ? 'Period: ${AppDateFormat.date.format(_searchStart!)} \u2013 ${AppDateFormat.date.format(_searchEnd!)}'
                  : 'Archived sales',
              style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
            ),
          ),
          Text('$foundCount found', style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold, color: context.colors.primary)),
          const SizedBox(width: AppSpacing.s12),
          Text(Money.format(totalAmount), style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search sale by product, client, invoice...',
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
    );
  }

  // ==================== TABLE ====================

  Widget _buildArchiveTable(List<Map<String, dynamic>> sales, DateFormat dateFormatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
          child: Row(
            children: [
              _headerCell('Date', flex: 3),
              _headerCell('Invoice No.', flex: 2),
              _headerCell('Client', flex: 2),
              _headerCell('Items', flex: 3),
              _headerCell('Amount', flex: 2),
              _headerCell('Payment Status', flex: 2),
              _headerCell('Seller', flex: 2),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
            itemBuilder: (context, index) => _buildArchiveRow(sales[index], dateFormatter),
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

  Widget _buildArchiveRow(Map<String, dynamic> sale, DateFormat dateFormatter) {
    final paid = ((sale['totalPaid'] ?? 0.0) as num).toDouble();
    final total = ((sale['totalAmount'] ?? 0.0) as num).toDouble();
    final status = _getPaymentStatus(paid, total);
    final statusColor = _statusColor(paid, total);
    final isSelected = _selectedSale?['id'] == sale['id'];
    final timestamp = (sale['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final firstItem = items.isNotEmpty ? items.first : null;

    return InkWell(
      onTap: () => setState(() => _selectedSale = sale),
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
                  Text(dateFormatter.format(timestamp).split(',').first, style: const TextStyle(fontSize: AppFontSize.f13)),
                  Text(AppDateFormat.time12.format(timestamp),
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _invoiceNo(sale),
                style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.primary, fontWeight: AppFontWeight.semibold),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(sale['clientName'] ?? 'Walk-in', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 3,
              child: firstItem == null
                  ? const Text('-', style: TextStyle(fontSize: AppFontSize.f13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${firstItem['name']} \u00d7 ${firstItem['quantity']}',
                            style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${items.length} item${items.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                      ],
                    ),
            ),
            Expanded(
              flex: 2,
              child: Text(Money.format(total), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
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
              child: Text(sale['soldByName'] ?? 'Unknown', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAGINATION ====================

  Widget _buildPaginationBar({
    required int totalFiltered,
    required int pageStart,
    required int pageEnd,
    required int totalPages,
  }) {
    final canGoNext = _currentPageIndex < totalPages - 1 || _hasMore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalFiltered == 0
                ? 'No sales'
                : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered${_hasMore ? '+' : ''} sales',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
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
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPageIndex > 0 ? () => setState(() => _currentPageIndex--) : null,
              ),
              Text('Page ${_currentPageIndex + 1} of $totalPages', style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: _isLoadingMore
                    ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: canGoNext && !_isLoadingMore
                    ? () async {
                        final needed = (_currentPageIndex + 2) * _displayPageSize;
                        if (needed > _archivedSales.length && _hasMore) {
                          await _loadMoreArchivedSales();
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

  // ==================== DETAILS PANEL ====================

  Widget _buildDetailsPanel(Map<String, dynamic> sale, DateFormat dateOnlyFormatter, DateFormat timeOnlyFormatter) {
    final paid = ((sale['totalPaid'] ?? 0.0) as num).toDouble();
    final total = ((sale['totalAmount'] ?? 0.0) as num).toDouble();
    final status = _getPaymentStatus(paid, total);
    final statusColor = _statusColor(paid, total);
    final timestamp = (sale['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final subtotal = items.fold<double>(
        0, (sum, i) => sum + ((i['unitPrice'] ?? 0.0) as num).toDouble() * ((i['quantity'] ?? 0) as num).toDouble());
    final totalDiscount =
        items.fold<double>(0, (sum, i) => sum + ((i['discount'] ?? 0.0) as num).toDouble());
    final balance = total - paid;

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
                const Text('Sale Details', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i20),
                  onPressed: () => setState(() => _selectedSale = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_invoiceNo(sale), style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold)),
                ),
              ],
            ),
            Text('${dateOnlyFormatter.format(timestamp)}, ${timeOnlyFormatter.format(timestamp)}',
                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                Text('${items.length} item${items.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
              ],
            ),
            const SizedBox(height: AppSpacing.s10),
            ...items.map((item) {
              final unitPrice = ((item['unitPrice'] ?? 0.0) as num).toDouble();
              final quantity = ((item['quantity'] ?? 0) as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] ?? 'Item', style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.semibold)),
                          Text('\u00d7 ${quantity.toInt()}', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                        ],
                      ),
                    ),
                    Text(Money.format(unitPrice * quantity), style: const TextStyle(fontSize: AppFontSize.f13_5)),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            _totalsRow('Subtotal', Money.format(subtotal)),
            _totalsRow('Discount', Money.format(totalDiscount)),
            _totalsRow('Total Amount', Money.format(total), bold: true, color: context.colors.primary),
            const SizedBox(height: AppSpacing.s10),
            _totalsRow('Paid', Money.format(paid), color: context.colors.success),
            _totalsRow('Balance', Money.format(balance), bold: true),
            const Divider(height: 24),
            _detailField(Icons.person_outline, 'Client', sale['clientName'] ?? 'Walk-in'),
            _detailField(Icons.badge_outlined, 'Seller', sale['soldByName'] ?? 'Unknown'),
            _detailField(Icons.payment_outlined, 'Payment Method', sale['paymentMethod'] ?? 'Not recorded'),
            _detailField(Icons.edit_note_outlined, 'Notes',
                (sale['notes'] as String?)?.isNotEmpty == true ? sale['notes'] as String : '-'),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openReceipt(sale),
                    icon: const Icon(Icons.print_outlined, size: AppIconSize.i16),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openReceipt(sale),
                    icon: const Icon(Icons.share_outlined, size: AppIconSize.i16),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Archived sales aren't deletable (there's no delete path anywhere
  // in this screen, by design - archiving is meant to be a permanent
  // historical record), so unlike the main Sales screen's details
  // panel, there's no Delete button here.
  void _openReceipt(Map<String, dynamic> sale) {
    final saleObj = Sale.fromFirestore(sale, sale['id'] as String? ?? '');
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(sale: saleObj)));
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

  Widget _detailField(IconData icon, String label, String value) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchArchiveDialog extends StatefulWidget {
  const _SearchArchiveDialog();

  @override
    State<_SearchArchiveDialog> createState() => _SearchArchiveDialogState();
    }

class _SearchArchiveDialogState extends State<_SearchArchiveDialog> {
  // Archived sales only ever contain fully-paid sales older than this many
  // days (see ARCHIVE_AFTER_DAYS in functions/index.js). Bounding the date
  // pickers to that cutoff stops someone picking "this month" and always
  // getting zero results, since nothing that recent has been archived yet.
  final DateTime _archiveCutoff =
      DateTime.now().subtract(AppRanges.archiveCutoff);

  String _dateMode = 'month';
  late DateTime _selectedMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_archiveCutoff.year, _archiveCutoff.month);
    _startDate = _archiveCutoff.subtract(AppRanges.month);
    _endDate = _archiveCutoff;
  }

  @override
  Widget build(BuildContext context) {
    final cutoffLabel = AppDateFormat.date.format(_archiveCutoff);

    return AlertDialog(
      title: Text(
        'Search Archived Sales',
        style: TextStyle(color: context.colors.primary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Replaces the old Payment Status dropdown: archived sales are
            // always fully paid (that's the only kind that ever gets
            // archived), so a Paid/Partial/Unpaid filter here could only
            // ever return everything or nothing - it wasn't a real filter.
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                borderRadius: BorderRadius.circular(AppRadius.r8),
                border: Border.all(
                    color: context.colors.primary.withValues(alpha: AppAlpha.a30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: AppIconSize.i18, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Archived sales are always fully paid - sales still '
                      'owing money stay in your active Sales tab regardless '
                      'of age.',
                      style: TextStyle(
                          fontSize: AppFontSize.f12, color: context.colors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            const Text(
              'Search By:',
              style: TextStyle(fontWeight: AppFontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Specific Month'),
                    selected: _dateMode == 'month',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _dateMode = 'month');
                      }
                    },
                    selectedColor:
                        context.colors.primary.withValues(alpha: AppAlpha.a20),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Date Range'),
                    selected: _dateMode == 'range',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _dateMode = 'range');
                      }
                    },
                    selectedColor:
                        context.colors.primary.withValues(alpha: AppAlpha.a20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Only sales before $cutoffLabel have reached the archive - '
              'anything newer is still in your active Sales list.',
              style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s16),

            // ───────────── Month mode ─────────────
            if (_dateMode == 'month') ...[
              const Text(
                'Select Month:',
                style: TextStyle(fontWeight: AppFontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: _archiveCutoff,
                  );
                  if (picked != null) {
                    setState(() => _selectedMonth = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: context.colors.primary),
                      const SizedBox(width: AppSpacing.s12),
                      Text(AppDateFormat.monthYear.format(_selectedMonth)),
                    ],
                  ),
                ),
              ),
            ]

            // ───────────── Range mode ─────────────
            else ...[
              const Text(
                'Start Date:',
                style: TextStyle(fontWeight: AppFontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: _endDate,
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: context.colors.primary),
                      const SizedBox(width: AppSpacing.s12),
                      Text(AppDateFormat.date.format(_startDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              const Text(
                'End Date:',
                style: TextStyle(fontWeight: AppFontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: _archiveCutoff,
                  );
                  if (picked != null) {
                    setState(() => _endDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: context.colors.primary),
                      const SizedBox(width: AppSpacing.s12),
                      Text(AppDateFormat.date.format(_endDate)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            DateTime start;
            DateTime end;

            if (_dateMode == 'month') {
              start = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                1,
              );
              end = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                0,
                23,
                59,
                59,
              );
            } else {
              start = _startDate;
              end = _endDate;
            }

            Navigator.pop(context, {
              'startDate': start,
              'endDate': end,
            });
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (states) {
                if (states.contains(WidgetState.hovered)) {
                  return context.colors.accent;
                }
                return context.colors.primary;
              },
            ),
            foregroundColor: WidgetStateProperty.all(context.colors.background),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }
}
