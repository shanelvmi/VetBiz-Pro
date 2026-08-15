import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/facility_provider.dart';

class SalesArchiveScreen extends StatefulWidget {
  const SalesArchiveScreen({super.key});

  @override
  State<SalesArchiveScreen> createState() => _SalesArchiveScreenState();
}

class _SalesArchiveScreenState extends State<SalesArchiveScreen> {
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
  // Default initial window shown on open: the most recently archived 90
  // days, ending right at the cutoff. Lets the screen show something
  // immediately instead of forcing a dialog before any data appears - the
  // Search button still lets the user widen or change the range anytime.
  static const int _defaultWindowDays = 90;

  List<Map<String, dynamic>> _archivedSales = [];
  bool _isLoading = false;
  DateTime? _searchStart;
  DateTime? _searchEnd;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    final cutoff =
        DateTime.now().subtract(const Duration(days: _archiveCutoffDays));
    _searchEnd = cutoff;
    _searchStart = cutoff.subtract(const Duration(days: _defaultWindowDays));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArchivedSales();
    });
  }

  Future<void> _showSearchDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SearchArchiveDialog(
        primaryDeepGreen: primaryDeepGreen,
        warmAmber: warmAmber,
        offWhite: offWhite,
      ),
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
          .collection('facilities')
          .doc(facilityId)
          .collection('archived_sales');

      if (_searchStart != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_searchStart!));
      }
      if (_searchEnd != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_searchEnd!.add(const Duration(days: 1))));
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
    if (paid >= total) return Colors.green;
    if (paid > 0) return Colors.orange;
    return Colors.red;
  }

  IconData _statusIcon(double paid, double total) {
    if (paid >= total) return Icons.check_circle;
    if (paid > 0) return Icons.pending;
    return Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
    
    final displayedSales = _archivedSales;

    final totalAmount = displayedSales.fold<double>(
        0, (sum, sale) => sum + ((sale['totalAmount'] ?? 0.0) as num).toDouble());
    final totalPaid = displayedSales.fold<double>(
        0, (sum, sale) => sum + ((sale['totalPaid'] ?? 0.0) as num).toDouble());

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        title: const Text('Sales Archive'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: offWhite,
                backgroundColor: offWhite.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.search, size: 18),
              label: const Text(
                'Search',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: _showSearchDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryDeepGreen),
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryDeepGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryDeepGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Archived Sales',
                            style: TextStyle(
                              color: primaryDeepGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_searchStart != null && _searchEnd != null)
                        Text(
                          'Period: ${DateFormat('dd MMM yyyy').format(_searchStart!)} - ${DateFormat('dd MMM yyyy').format(_searchEnd!)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Found: ${displayedSales.length} sales',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryDeepGreen,
                            ),
                          ),
                          Text(
                            'Total: ${_moneyFormat.format(totalAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryDeepGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayedSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.archive_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No archived sales found',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search criteria',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : Focus(
                          autofocus: true,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isLargeScreen = constraints.maxWidth >= 1024;

                              if (isLargeScreen) {
                                return ScrollConfiguration(
                                  behavior: const ScrollBehavior()
                                      .copyWith(overscroll: false),
                                  child: MasonryGridView.count(
                                    primary: true,
                                    padding: const EdgeInsets.all(12),
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    itemCount: displayedSales.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == displayedSales.length) {
                                        return _buildLoadMoreFooter();
                                      }
                                      return _buildArchiveCard(
                                          displayedSales[index], dateFormatter);
                                    },
                                  ),
                                );
                              } else {
                                return ScrollConfiguration(
                                  behavior: const ScrollBehavior()
                                      .copyWith(overscroll: false),
                                  child: ListView.builder(
                                    primary: true,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: displayedSales.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == displayedSales.length) {
                                        return _buildLoadMoreFooter();
                                      }
                                      return _buildArchiveCard(
                                          displayedSales[index], dateFormatter);
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // Footer at the end of the archived-sales list - lets the user page in
  // older archived sales instead of ever fetching a facility's whole
  // archive at once.
  Widget _buildLoadMoreFooter() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryDeepGreen,
            ),
          ),
        ),
      );
    }

    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'End of archived sales for this search',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadMoreArchivedSales,
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryDeepGreen,
            side: BorderSide(color: primaryDeepGreen),
          ),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more archived sales'),
        ),
      ),
    );
  }

  Widget _buildArchiveCard(Map<String, dynamic> sale, DateFormat dateFormatter) {
    final paid = ((sale['totalPaid'] ?? 0.0) as num).toDouble();
    final total = ((sale['totalAmount'] ?? 0.0) as num).toDouble();
    final statusColor = _statusColor(paid, total);
    final statusIcon = _statusIcon(paid, total);
    final statusText = _getPaymentStatus(paid, total);

    final timestamp = (sale['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sale['clientName'] ?? 'Walk-in Customer',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Date: ${dateFormatter.format(timestamp)}\nTotal: ${_moneyFormat.format(total)}',
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Seller:', sale['soldByName'] ?? 'Unknown'),
              _buildDetailRow('Paid:', _moneyFormat.format(paid)),
              const Divider(height: 16),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${item['name']} x${item['quantity']} ${item['unit']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchArchiveDialog extends StatefulWidget {
  final Color primaryDeepGreen;
  final Color warmAmber;
  final Color offWhite;

  const _SearchArchiveDialog({
    required this.primaryDeepGreen,
    required this.warmAmber,
    required this.offWhite,
  });

  @override
    State<_SearchArchiveDialog> createState() => _SearchArchiveDialogState();
    }

class _SearchArchiveDialogState extends State<_SearchArchiveDialog> {
  // Archived sales only ever contain fully-paid sales older than this many
  // days (see ARCHIVE_AFTER_DAYS in functions/index.js). Bounding the date
  // pickers to that cutoff stops someone picking "this month" and always
  // getting zero results, since nothing that recent has been archived yet.
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
      title: Text(
        'Search Archived Sales',
        style: TextStyle(color: widget.primaryDeepGreen),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.primaryDeepGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: widget.primaryDeepGreen.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: widget.primaryDeepGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived sales are always fully paid - sales still '
                      'owing money stay in your active Sales tab regardless '
                      'of age.',
                      style: TextStyle(
                          fontSize: 12, color: widget.primaryDeepGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search By:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                        widget.primaryDeepGreen.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 8),
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
                        widget.primaryDeepGreen.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only sales before $cutoffLabel have reached the archive - '
              'anything newer is still in your active Sales list.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // ───────────── Month mode ─────────────
            if (_dateMode == 'month') ...[
              const Text(
                'Select Month:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: widget.primaryDeepGreen),
                      const SizedBox(width: 12),
                      Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                    ],
                  ),
                ),
              ),
            ]

            // ───────────── Range mode ─────────────
            else ...[
              const Text(
                'Start Date:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: widget.primaryDeepGreen),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM yyyy').format(_startDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'End Date:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: widget.primaryDeepGreen),
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
          style: TextButton.styleFrom(
            foregroundColor: widget.primaryDeepGreen,
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
                  return widget.warmAmber;
                }
                return widget.primaryDeepGreen;
              },
            ),
            foregroundColor: WidgetStateProperty.all(widget.offWhite),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }
}
