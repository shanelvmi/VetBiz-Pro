import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/facility_provider.dart';
import '../../constants/service_categories.dart';

class ServicesArchiveScreen extends StatefulWidget {
  const ServicesArchiveScreen({super.key});

  @override
  State<ServicesArchiveScreen> createState() => _ServicesArchiveScreenState();
}

class _ServicesArchiveScreenState extends State<ServicesArchiveScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _numberFormat = NumberFormat.decimalPattern('en_US');

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

  @override
  Widget build(BuildContext context) {
    final displayedServices = _selectedCategory == 'All'
        ? _archivedServices
        : _archivedServices.where((s) {
            final category = (s['category'] as String?) ?? 'Other';
            return category == _selectedCategory;
          }).toList();

    final categories = <String>{...kServiceCategories};
    for (final s in _archivedServices) {
      final c = (s['category'] as String?) ?? '';
      categories.add(c.isNotEmpty ? c : 'Other');
    }
    final sortedCategories = ['All', ...categories.toList()..sort()];

    final totalAmount = displayedServices.fold<double>(
        0, (sum, s) => sum + ((s['totalAmount'] ?? 0.0) as num).toDouble());

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        centerTitle: true,
        title: const Text('Services Archive'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: offWhite,
                backgroundColor: offWhite.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: _showSearchDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryDeepGreen))
          : Column(
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_searchStart != null && _searchEnd != null)
                        Text(
                          '${DateFormat('dd MMM yyyy').format(_searchStart!)} - ${DateFormat('dd MMM yyyy').format(_searchEnd!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      Text(
                        '${displayedServices.length} services · Tsh ${_numberFormat.format(totalAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryDeepGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayedServices.isEmpty
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
                                'Try a different search or category',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isLargeScreen = constraints.maxWidth >= 1024;
                            final itemCount = displayedServices.length + 1;

                            Widget itemBuilder(BuildContext context, int index) {
                              if (index == displayedServices.length) {
                                return _buildLoadMoreFooter();
                              }
                              return _buildArchiveCard(displayedServices[index]);
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
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoadingMore) {
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
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'End of archived services for this search',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadMoreArchivedServices,
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryDeepGreen,
            side: BorderSide(color: primaryDeepGreen),
          ),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more archived services'),
        ),
      ),
    );
  }

  Widget _buildArchiveCard(Map<String, dynamic> service) {
    final totalAmount = ((service['totalAmount'] ?? 0.0) as num).toDouble();
    final totalPaid = ((service['totalPaid'] ?? 0.0) as num).toDouble();
    final serviceDate = service['serviceDate'] is Timestamp
        ? (service['serviceDate'] as Timestamp).toDate()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 2, offset: const Offset(0, 1)),
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
                  (service['name'] as String?) ?? 'Service',
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
                  ((service['category'] as String?)?.isNotEmpty ?? false)
                      ? service['category'] as String
                      : 'Other',
                  style: TextStyle(color: primaryDeepGreen, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Client: ${service['clientName'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
          Text('Provided By: ${service['providedByName'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
          if (serviceDate != null)
            Text('Date: ${DateFormat.yMMMd().format(serviceDate)}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            'Total: Tsh ${_numberFormat.format(totalAmount)} | Paid: Tsh ${_numberFormat.format(totalPaid)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
