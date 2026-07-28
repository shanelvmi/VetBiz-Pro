import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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

  List<Map<String, dynamic>> _archivedSales = [];
  bool _isLoading = false;
  String _searchType = '';
  DateTime? _searchStart;
  DateTime? _searchEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSearchDialog();
    });
  }

  Future<void> _showSearchDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SearchArchiveDialog(
        primaryDeepGreen: primaryDeepGreen,
        warmAmber: warmAmber,
        offWhite: offWhite,
      ),
    );

    if (result == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _searchType = result['type'] ?? 'All';
      _searchStart = result['startDate'];
      _searchEnd = result['endDate'];
    });

    await _loadArchivedSales();
  }

  Future<void> _loadArchivedSales() async {
    setState(() => _isLoading = true);

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

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

      query = query.orderBy('timestamp', descending: true).limit(100);

      final snapshot = await query.get();

      List<Map<String, dynamic>> sales = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        sales.add(data);
      }

      if (_searchType != 'All' && _searchType.isNotEmpty) {
        sales = sales.where((sale) {
          final paid = (sale['totalPaid'] ?? 0.0).toDouble();
          final total = (sale['totalAmount'] ?? 0.0).toDouble();
          final status = _getPaymentStatus(paid, total);
          return status == _searchType;
        }).toList();
      }

      if (mounted) {
        setState(() {
          _archivedSales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading archived sales: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    
    final totalAmount = _archivedSales.fold<double>(
        0, (sum, sale) => sum + ((sale['totalAmount'] ?? 0.0) as num).toDouble());
    final totalPaid = _archivedSales.fold<double>(
        0, (sum, sale) => sum + ((sale['totalPaid'] ?? 0.0) as num).toDouble());

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        title: const Text('Sales Archive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'New Search',
            onPressed: _showSearchDialog,
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
                            'Search Results',
                            style: TextStyle(
                              color: primaryDeepGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Type: $_searchType', style: const TextStyle(fontSize: 13)),
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
                            'Found: ${_archivedSales.length} sales',
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
                  child: _archivedSales.isEmpty
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _archivedSales.length,
                          itemBuilder: (context, index) {
                            return _buildArchiveCard(
                                _archivedSales[index], dateFormatter);
                          },
                        ),
                ),
              ],
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
    String _selectedType = 'All';
    String _dateMode = 'month';
    DateTime _selectedMonth = DateTime.now();
    DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime _endDate = DateTime.now();

    @override
    Widget build(BuildContext context) {
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
            const Text(
                'Payment Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const ['All', 'Paid', 'Partial', 'Unpaid']
                    .map(
                    (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                    ),
                    )
                    .toList(),
                onChanged: (val) {
                if (val != null) {
                    setState(() => _selectedType = val);
                }
                },
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
                    lastDate: DateTime.now(),
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
                        Text(
                        DateFormat('MMMM yyyy')
                            .format(_selectedMonth),
                        ),
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
                        Text(
                        DateFormat('dd MMM yyyy')
                            .format(_startDate),
                        ),
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
                    lastDate: DateTime.now(),
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
                        Text(
                        DateFormat('dd MMM yyyy')
                            .format(_endDate),
                        ),
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
                'type': _selectedType,
                'startDate': start,
                'endDate': end,
            });
            },
            style: ButtonStyle(
            backgroundColor:
                WidgetStateProperty.resolveWith<Color>(
                (states) {
                if (states.contains(WidgetState.hovered)) {
                    return widget.warmAmber;
                }
                return widget.primaryDeepGreen;
                },
            ),
            foregroundColor:
                WidgetStateProperty.all(widget.offWhite),
            ),
            child: const Text('Search'),
        ),
        ],
    );
    }
}