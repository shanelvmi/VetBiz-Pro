import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/service.dart';
import '../../providers/facility_provider.dart';
import '../../constants/service_categories.dart';
import 'service_receipt_preview_screen.dart';

class ServicesArchiveScreen extends StatefulWidget {
  const ServicesArchiveScreen({super.key});

  @override
  State<ServicesArchiveScreen> createState() => _ServicesArchiveScreenState();
}

class _ServicesArchiveScreenState extends State<ServicesArchiveScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  static const int _pageSize = 30;

  // Must match ARCHIVE_AFTER_DAYS in functions/index.js - anything newer
  // than this hasn't reached the archive yet.
  static const int _archiveCutoffDays = 180;
  // Default initial window on open: the most recently archived 90 days,
  // ending right at the cutoff, so the screen shows something immediately
  // instead of forcing a search dialog first.
  static const int _defaultWindowDays = 90;

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
    final cutoff = DateTime.now().subtract(const Duration(days: _archiveCutoffDays));
    _searchEnd = cutoff;
    _searchStart = cutoff.subtract(const Duration(days: _defaultWindowDays));

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
        primaryDeepGreen: primaryDeepGreen,
        warmAmber: warmAmber,
        offWhite: offWhite,
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
          .collection('facilities')
          .doc(facilityId)
          .collection('archived_services');

      if (_searchStart != null) {
        query = query.where('serviceDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_searchStart!));
      }
      if (_searchEnd != null) {
        query = query.where('serviceDate',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_searchEnd!.add(const Duration(days: 1))));
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
    if (paid >= total) return Colors.green;
    if (paid > 0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');
    final dateOnlyFormatter = DateFormat('dd MMM yyyy');
    final timeOnlyFormatter = DateFormat('hh:mm a');

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
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryDeepGreen))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _buildInfoBanner(filteredServices.length, totalAmount),
                      ),
                      if (sortedCategories.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _buildCategoryChipsRow(sortedCategories),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _buildSearchBar(),
                      ),
                      Expanded(
                        child: filteredServices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.archive_outlined, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No archived services found',
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try a different search, category, or date range',
                                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Services Archive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Services archived after $_archiveCutoffDays days', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OutlinedButton.icon(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: const Text('Date Range'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(int foundCount, double totalAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryDeepGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryDeepGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _searchStart != null && _searchEnd != null
                  ? 'Period: ${DateFormat('dd MMM yyyy').format(_searchStart!)} \u2013 ${DateFormat('dd MMM yyyy').format(_searchEnd!)}'
                  : 'Archived services',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
            ),
          ),
          Text('$foundCount found', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primaryDeepGreen)),
          const SizedBox(width: 12),
          Text(_moneyFormat.format(totalAmount), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryDeepGreen)),
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
        child: Text(
          category,
          style: TextStyle(
            fontSize: 12.5,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    return TextField(
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
    );
  }

  // ==================== TABLE ====================

  Widget _buildArchiveTable(List<Map<String, dynamic>> services, DateFormat dateFormatter) {
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
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: services.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
            itemBuilder: (context, index) => _buildArchiveRow(services[index], dateFormatter),
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
                  Text((service['name'] as String?) ?? 'Service',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryDeepGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ((service['category'] as String?)?.isNotEmpty ?? false) ? service['category'] as String : 'Other',
                      style: TextStyle(fontSize: 10.5, color: primaryDeepGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Notes: $description',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(service['clientName'] ?? 'Walk-in', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(service['providedByName'] ?? 'Unknown', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(_moneyFormat.format(totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              child: Text(service['paymentMethod'] ?? '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalFiltered == 0
                ? 'No services'
                : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered${_hasMore ? '+' : ''} services',
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
                icon: _isLoadingMore
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                  child: Text((service['name'] as String?) ?? 'Service',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
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
                  _totalsRow('Paid Amount', _moneyFormat.format(totalPaid)),
                  _totalsRow('Payment Method', service['paymentMethod'] ?? 'Not recorded'),
                  if (transactionId != null && transactionId.isNotEmpty)
                    _totalsRow('Transaction ID', transactionId),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailField(Icons.category_outlined, 'Category',
                ((service['category'] as String?)?.isNotEmpty ?? false) ? service['category'] as String : 'Other'),
            _detailField(Icons.person_outline, 'Client', service['clientName'] ?? 'Walk-in'),
            _detailField(Icons.badge_outlined, 'Provided By', service['providedByName'] ?? 'Unknown'),
            _detailField(Icons.calendar_today_outlined, 'Service Date', dateOnlyFormatter.format(serviceDate)),
            _detailField(Icons.edit_note_outlined, 'Notes', description.isNotEmpty ? description : '-'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _openReceipt(service),
              icon: const Icon(Icons.print_outlined, size: 16),
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

  Widget _detailField(IconData icon, String label, String value) {
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
  static const int _archiveCutoffDays = 180;
  final DateTime _archiveCutoff =
      DateTime.now().subtract(const Duration(days: _archiveCutoffDays));

  String _dateMode = 'month';
  late DateTime _selectedMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_archiveCutoff.year, _archiveCutoff.month);
    _startDate = _archiveCutoff.subtract(const Duration(days: 30));
    _endDate = _archiveCutoff;
  }

  @override
  Widget build(BuildContext context) {
    final cutoffLabel = DateFormat('dd MMM yyyy').format(_archiveCutoff);

    return AlertDialog(
      title: Text('Search Archived Services', style: TextStyle(color: widget.primaryDeepGreen)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search By:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Specific Month'),
                    selected: _dateMode == 'month',
                    onSelected: (selected) {
                      if (selected) setState(() => _dateMode = 'month');
                    },
                    selectedColor: widget.primaryDeepGreen.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Date Range'),
                    selected: _dateMode == 'range',
                    onSelected: (selected) {
                      if (selected) setState(() => _dateMode = 'range');
                    },
                    selectedColor: widget.primaryDeepGreen.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only services before $cutoffLabel have reached the archive.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_dateMode == 'month') ...[
              const Text('Select Month:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                      const SizedBox(width: 12),
                      Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM yyyy').format(_startDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('End Date:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM yyyy').format(_endDate)),
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
