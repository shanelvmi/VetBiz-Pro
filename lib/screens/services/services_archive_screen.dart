import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/service.dart';
import '../../providers/facility_provider.dart';
import '../../constants/service_categories.dart';
import 'service_receipt_preview_screen.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

class ServicesArchiveScreen extends StatefulWidget {
  const ServicesArchiveScreen({super.key});

  @override
  State<ServicesArchiveScreen> createState() => _ServicesArchiveScreenState();
}

class _ServicesArchiveScreenState extends State<ServicesArchiveScreen> {


  static const int _pageSize = AppLimits.archivePageSize;

  // Must match ARCHIVE_AFTER_DAYS in functions/index.js - anything newer
  // than this hasn't reached the archive yet.
  static const int _archiveCutoffDays = AppRanges.archiveCutoffDays;
  // Default initial window on open: the most recently archived 90 days,
  // ending right at the cutoff, so the screen shows something immediately
  // instead of forcing a search dialog first.

  List<Map<String, dynamic>> _archivedServices = [];
  bool _isLoading = false;
  DateTime? _searchStart;
  DateTime? _searchEnd;
  String _selectedCategory = 'All';

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Which archived service is shown in the details panel, the display
  // pagination window (over whatever's already loaded), and a
  // client-side text search over the currently loaded page - matches
  // the Sales archive screen's pattern. Kept separate from the
  // existing date-range search dialog, which re-queries Firestore
  // server-side.
  Map<String, dynamic>? _selectedService;
  int _displayPageSize = 10;
  int _currentPageIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cutoff = DateTime.now().subtract(AppRanges.archiveCutoff);
    _searchEnd = cutoff;
    _searchStart = cutoff.subtract(AppRanges.archiveDefaultWindow);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArchivedServices();
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
      builder: (context) => _SearchServicesArchiveDialog(
        primaryDeepGreen: context.colors.primary,
        warmAmber: context.colors.accent,
        offWhite: context.colors.background,
      ),
    );

    if (result == null) return;

    setState(() {
      _searchStart = result['startDate'];
      _searchEnd = result['endDate'];
    });

    await _loadArchivedServices();
  }

  Future<void> _loadArchivedServices() async {
    setState(() {
      _isLoading = true;
      _archivedServices = [];
      _lastDoc = null;
      _hasMore = true;
    });

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    await _fetchArchivedServicesPage(facilityId);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchArchivedServicesPage(String facilityId) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.archivedServices);

      if (_searchStart != null) {
        query = query.where('serviceDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_searchStart!));
      }
      if (_searchEnd != null) {
        query = query.where('serviceDate',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_searchEnd!.add(AppRanges.day)));
      }

      query = query.orderBy('serviceDate', descending: true);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      query = query.limit(_pageSize);

      final snapshot = await query.get();

      final newServices = snapshot.docs.map((doc) {
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
          _archivedServices = [..._archivedServices, ...newServices];
        });
      }
    } catch (e) {
      debugPrint('Error loading archived services: $e');
      if (mounted) setState(() => _hasMore = false);
    }
  }

  Future<void> _loadMoreArchivedServices() async {
    if (_isLoadingMore || !_hasMore) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isLoadingMore = true);
    await _fetchArchivedServicesPage(facilityId);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  String _invoiceNo(Map<String, dynamic> service) {
    final receiptNumber = service['receiptNumber'];
    return 'SV-${(receiptNumber ?? 0).toString().padLeft(6, '0')}';
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
    final dateFormatter = AppDateFormat.dateTime24;
    final dateOnlyFormatter = AppDateFormat.date;
    final timeOnlyFormatter = AppDateFormat.time12;

    final categoryFiltered = _selectedCategory == 'All'
        ? _archivedServices
        : _archivedServices.where((s) {
            final category = (s['category'] as String?) ?? 'Other';
            return category == _selectedCategory;
          }).toList();

    final filteredServices = categoryFiltered.where((service) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (service['name'] as String? ?? '').toLowerCase();
      final category = (service['category'] as String? ?? '').toLowerCase();
      final clientName = (service['clientName'] as String? ?? '').toLowerCase();
      final description = (service['description'] as String? ?? '').toLowerCase();
      return name.contains(q) || category.contains(q) || clientName.contains(q) || description.contains(q);
    }).toList();

    final categories = <String>{...kServiceCategories};
    for (final s in _archivedServices) {
      final c = (s['category'] as String?) ?? '';
      categories.add(c.isNotEmpty ? c : 'Other');
    }
    final sortedCategories = ['All', ...categories.toList()..sort()];

    final totalAmount = filteredServices.fold<double>(
        0, (sum, s) => sum + ((s['totalAmount'] ?? 0.0) as num).toDouble());

    // Same honest display-pagination window as the main Services
    // screen - a page here is a view over whatever's already loaded
    // (or gets loaded on demand via _loadMoreArchivedServices), not a
    // true jump to an arbitrary page number.
    final totalPages = (filteredServices.length / _displayPageSize).ceil().clamp(1, 999999);
    if (_currentPageIndex >= totalPages) _currentPageIndex = totalPages - 1;
    if (_currentPageIndex < 0) _currentPageIndex = 0;
    final pageStart = _currentPageIndex * _displayPageSize;
    final pageEnd = (pageStart + _displayPageSize).clamp(0, filteredServices.length);
    final pageServices = filteredServices.sublist(pageStart.clamp(0, filteredServices.length), pageEnd);

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
                        child: _buildInfoBanner(filteredServices.length, totalAmount),
                      ),
                      if (sortedCategories.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                          child: _buildCategoryChipsRow(sortedCategories),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                        child: _buildSearchBar(),
                      ),
                      Expanded(
                        child: filteredServices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.archive_outlined, size: AppIconSize.i64, color: context.colors.textDisabled),
                                    const SizedBox(height: AppSpacing.s16),
                                    Text(
                                      'No archived services found',
                                      style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      'Try a different search, category, or date range',
                                      style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textHint),
                                    ),
                                  ],
                                ),
                              )
                            : _buildArchiveTable(pageServices, dateFormatter),
                      ),
                      _buildPaginationBar(
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
                    child: _buildDetailsPanel(_selectedService!, dateOnlyFormatter, timeOnlyFormatter),
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
          Text('Services Archive', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('Services archived after $_archiveCutoffDays days', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
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
                  : 'Archived services',
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

  Widget _buildCategoryChipsRow(List<String> categories) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.s8),
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
      borderRadius: BorderRadius.circular(AppRadius.r20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r20),
          border: Border.all(color: isSelected ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30)),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: AppFontSize.f12_5,
            color: isSelected ? context.colors.surface : context.colors.textPrimary,
            fontWeight: isSelected ? AppFontWeight.semibold : AppFontWeight.regular,
          ),
        ),
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

  Widget _buildArchiveTable(List<Map<String, dynamic>> services, DateFormat dateFormatter) {
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
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: services.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
            itemBuilder: (context, index) => _buildArchiveRow(services[index], dateFormatter),
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

  Widget _buildArchiveRow(Map<String, dynamic> service, DateFormat dateFormatter) {
    final totalPaid = ((service['totalPaid'] ?? 0.0) as num).toDouble();
    final totalAmount = ((service['totalAmount'] ?? 0.0) as num).toDouble();
    final status = _getPaymentStatus(totalPaid, totalAmount);
    final statusColor = _statusColor(totalPaid, totalAmount);
    final isSelected = _selectedService?['id'] == service['id'];
    final serviceDate = service['serviceDate'] is Timestamp
        ? (service['serviceDate'] as Timestamp).toDate()
        : DateTime.now();
    final description = (service['description'] as String?) ?? '';

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
                  Text((service['name'] as String?) ?? 'Service',
                      style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.s3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                    child: Text(
                      ((service['category'] as String?)?.isNotEmpty ?? false) ? service['category'] as String : 'Other',
                      style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold),
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s3),
                      child: Text('Notes: $description',
                          style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service['clientName'] ?? 'Walk-in', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(service['providedByName'] ?? 'Unknown', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(Money.format(totalAmount), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
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
              child: Text(service['paymentMethod'] ?? '-', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                ? 'No services'
                : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered${_hasMore ? '+' : ''} services',
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
                        if (needed > _archivedServices.length && _hasMore) {
                          await _loadMoreArchivedServices();
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

  Widget _buildDetailsPanel(Map<String, dynamic> service, DateFormat dateOnlyFormatter, DateFormat timeOnlyFormatter) {
    final totalPaid = ((service['totalPaid'] ?? 0.0) as num).toDouble();
    final totalAmount = ((service['totalAmount'] ?? 0.0) as num).toDouble();
    final status = _getPaymentStatus(totalPaid, totalAmount);
    final statusColor = _statusColor(totalPaid, totalAmount);
    final serviceDate = service['serviceDate'] is Timestamp
        ? (service['serviceDate'] as Timestamp).toDate()
        : DateTime.now();
    final transactionId = service['transactionId'] as String?;
    final description = (service['description'] as String?) ?? '';

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
                  child: Text((service['name'] as String?) ?? 'Service',
                      style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold)),
                ),
              ],
            ),
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
                  _totalsRow('Paid Amount', Money.format(totalPaid)),
                  _totalsRow('Payment Method', service['paymentMethod'] ?? 'Not recorded'),
                  if (transactionId != null && transactionId.isNotEmpty)
                    _totalsRow('Transaction ID', transactionId),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            _detailField(Icons.category_outlined, 'Category',
                ((service['category'] as String?)?.isNotEmpty ?? false) ? service['category'] as String : 'Other'),
            _detailField(Icons.person_outline, 'Client', service['clientName'] ?? 'Walk-in'),
            _detailField(Icons.badge_outlined, 'Provided By', service['providedByName'] ?? 'Unknown'),
            _detailField(Icons.calendar_today_outlined, 'Service Date', dateOnlyFormatter.format(serviceDate)),
            _detailField(Icons.edit_note_outlined, 'Notes', description.isNotEmpty ? description : '-'),
            const SizedBox(height: AppSpacing.s20),
            OutlinedButton.icon(
              onPressed: () => _openReceipt(service),
              icon: const Icon(Icons.print_outlined, size: AppIconSize.i16),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            ),
          ],
        ),
      ),
    );
  }

  // Archived services aren't editable or deletable (there's no
  // edit/delete path anywhere in this screen, by design - archiving
  // is meant to be a permanent historical record), so unlike the main
  // Services screen's details panel, only Print is offered here.
  void _openReceipt(Map<String, dynamic> service) {
    final serviceObj = Service.fromFirestore(service, service['id'] as String? ?? '');
    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: serviceObj)));
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

class _SearchServicesArchiveDialog extends StatefulWidget {
  final Color primaryDeepGreen;
  final Color warmAmber;
  final Color offWhite;

  const _SearchServicesArchiveDialog({
    required this.primaryDeepGreen,
    required this.warmAmber,
    required this.offWhite,
  });

  @override
  State<_SearchServicesArchiveDialog> createState() => _SearchServicesArchiveDialogState();
}

class _SearchServicesArchiveDialogState extends State<_SearchServicesArchiveDialog> {
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
      title: Text('Search Archived Services', style: TextStyle(color: widget.primaryDeepGreen)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search By:', style: TextStyle(fontWeight: AppFontWeight.bold)),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Specific Month'),
                    selected: _dateMode == 'month',
                    onSelected: (selected) {
                      if (selected) setState(() => _dateMode = 'month');
                    },
                    selectedColor: widget.primaryDeepGreen.withValues(alpha: AppAlpha.a20),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Date Range'),
                    selected: _dateMode == 'range',
                    onSelected: (selected) {
                      if (selected) setState(() => _dateMode = 'range');
                    },
                    selectedColor: widget.primaryDeepGreen.withValues(alpha: AppAlpha.a20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Only services before $cutoffLabel have reached the archive.',
              style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (_dateMode == 'month') ...[
              const Text('Select Month:', style: TextStyle(fontWeight: AppFontWeight.bold)),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: _archiveCutoff,
                  );
                  if (picked != null) setState(() => _selectedMonth = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                      const SizedBox(width: AppSpacing.s12),
                      Text(AppDateFormat.monthYear.format(_selectedMonth)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Text('Start Date:', style: TextStyle(fontWeight: AppFontWeight.bold)),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: _endDate,
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                      const SizedBox(width: AppSpacing.s12),
                      Text(AppDateFormat.date.format(_startDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              const Text('End Date:', style: TextStyle(fontWeight: AppFontWeight.bold)),
              const SizedBox(height: AppSpacing.s8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: _archiveCutoff,
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
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
          style: TextButton.styleFrom(foregroundColor: widget.primaryDeepGreen),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            DateTime start;
            DateTime end;
            if (_dateMode == 'month') {
              start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
              end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
            } else {
              start = _startDate;
              end = _endDate;
            }
            Navigator.pop(context, {'startDate': start, 'endDate': end});
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(widget.primaryDeepGreen),
            foregroundColor: WidgetStateProperty.all(widget.offWhite),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }
}
