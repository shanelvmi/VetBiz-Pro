import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/facility_provider.dart';

/// A single row in the merged payments ledger - could originate from a
/// sale payment, a service payment, a debt repayment, or an "other
/// income" transaction. Local to this screen; not a Firestore model since
/// it's a display-only merge of two different collections.
class _LedgerEntry {
  final String type; // 'sale' | 'service' | 'debt_repayment' | 'other_income'
  final double amount;
  final DateTime timestamp;
  final String? clientId;
  final String? clientName;
  final String description;

  const _LedgerEntry({
    required this.type,
    required this.amount,
    required this.timestamp,
    this.clientId,
    this.clientName,
    required this.description,
  });
}

class PaymentsScreen extends StatefulWidget {
  // When opened from a specific debtor's card, pre-filters to just that
  // client instead of showing the whole shop's ledger.
  final String? initialClientId;
  final String? initialClientName;

  const PaymentsScreen({super.key, this.initialClientId, this.initialClientName});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  late final TextEditingController _searchController;

  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  bool _isLoading = false;
  List<_LedgerEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialClientName ?? '');
    _searchQuery = widget.initialClientName ?? '';

    final now = DateTime.now();
    if (widget.initialClientId != null) {
      // Viewing one client's history - default to a wide window so their
      // past payments are actually visible, not just "did they pay today".
      _rangeStart = now.subtract(const Duration(days: 365));
      _rangeEnd = now;
    } else {
      // Default view: today only.
      _rangeStart = DateTime(now.year, now.month, now.day);
      _rangeEnd = now;
    }

    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _labelFor(String type) {
    switch (type) {
      case 'sale':
        return 'Sale payment';
      case 'service':
        return 'Service payment';
      case 'debt_repayment':
        return 'Debt repayment';
      case 'other_income':
        return 'Other income';
      default:
        return 'Payment';
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'sale':
        return Icons.shopping_cart;
      case 'service':
        return Icons.design_services;
      case 'debt_repayment':
        return Icons.account_balance_wallet;
      case 'other_income':
        return Icons.trending_up;
      default:
        return Icons.payments;
    }
  }

  Future<void> _loadEntries() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isLoading = true);

    final entries = <_LedgerEntry>[];

    try {
      // Sale/service payments + debt repayments - all already merged into
      // one `payments` collection.
      final paymentsSnap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_rangeStart))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_rangeEnd))
          .orderBy('timestamp', descending: true)
          .get();

      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        final source = (data['source'] as String?) ?? 'sale';
        entries.add(_LedgerEntry(
          type: source,
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          clientId: data['clientId'] as String?,
          clientName: data['clientName'] as String?,
          description: _labelFor(source),
        ));
      }

      // Other Income - read-only here; still created/edited only in
      // Transactions. Not tied to a client, so excluded when viewing one
      // specific debtor's history.
      if (widget.initialClientId == null) {
        final txSnap = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_rangeStart))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_rangeEnd))
            .orderBy('date', descending: true)
            .get();

        for (final doc in txSnap.docs) {
          final data = doc.data();
          final type = ((data['type'] as String?) ?? '').toLowerCase();
          if (type != 'other income') continue;

          entries.add(_LedgerEntry(
            type: 'other_income',
            amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
            timestamp: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            clientId: null,
            clientName: null,
            description: (data['description'] as String?)?.isNotEmpty == true
                ? data['description'] as String
                : 'Other income',
          ));
        }
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading payments ledger: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDateRangeDialog() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _DateRangeDialog(
        initialStart: _rangeStart,
        initialEnd: _rangeEnd,
        primaryDeepGreen: primaryDeepGreen,
        warmAmber: warmAmber,
        offWhite: offWhite,
      ),
    );

    if (result == null) return;

    setState(() {
      _rangeStart = result['start']!;
      _rangeEnd = result['end']!;
    });

    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where((e) {
      if (widget.initialClientId != null) {
        // Already scoped to one specific client by ID - that's the
        // authoritative match. The search box still lets someone type
        // further within this client's own history, but the client-name
        // text that's pre-filled here on open must never itself act as a
        // required filter - not every payment document reliably carries
        // a clientName field, and requiring it silently dropped valid,
        // correctly-matched entries (this is exactly what caused a
        // second debt repayment to go missing while an earlier one, with
        // a clientName set, still showed).
        if (e.clientId != widget.initialClientId) return false;
        if (_searchQuery.isEmpty || _searchQuery == widget.initialClientName) {
          return true;
        }
        final q = _searchQuery.toLowerCase();
        return (e.clientName ?? '').toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q);
      }

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (e.clientName ?? '').toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();

    final total = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Group by calendar day, preserving descending order.
    final Map<String, List<_LedgerEntry>> grouped = {};
    for (final e in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(e.timestamp);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryDeepGreen))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_rangeStart)} - ${DateFormat('dd MMM yyyy').format(_rangeEnd)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        'Total: Tsh ${_moneyFormat.format(total)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryDeepGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No payments in this period.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: grouped.entries.map((dayEntry) {
                            final dayTotal = dayEntry.value
                                .fold<double>(0.0, (sum, e) => sum + e.amount);
                            return _buildDayGroup(dayEntry.key, dayEntry.value, dayTotal);
                          }).toList(),
                        ),
                ),
              ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search by client or description...',
                hintStyle: TextStyle(color: offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: offWhite),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            )
          : Text(widget.initialClientName != null
              ? 'Payments · ${widget.initialClientName}'
              : 'Payments'),
      actions: [
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
        if (!_isSearchExpanded)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: offWhite,
                backgroundColor: offWhite.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: _showDateRangeDialog,
            ),
          ),
      ],
    );
  }

  Widget _buildDayGroup(String dayKey, List<_LedgerEntry> entries, double dayTotal) {
    final date = DateTime.parse(dayKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, dd MMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryDeepGreen),
                ),
                Text(
                  'Tsh ${_moneyFormat.format(dayTotal)} collected',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          ...entries.map(_buildEntryTile),
        ],
      ),
    );
  }

  Widget _buildEntryTile(_LedgerEntry e) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryDeepGreen.withValues(alpha: 0.1),
            child: Icon(_iconFor(e.type), size: 18, color: primaryDeepGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.clientName ?? e.description,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${e.clientName != null ? '${e.description} · ' : ''}${DateFormat('hh:mm a').format(e.timestamp)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            'Tsh ${_moneyFormat.format(e.amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryDeepGreen),
          ),
        ],
      ),
    );
  }
}

class _DateRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final Color primaryDeepGreen;
  final Color warmAmber;
  final Color offWhite;

  const _DateRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.primaryDeepGreen,
    required this.warmAmber,
    required this.offWhite,
  });

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Date Range', style: TextStyle(color: widget.primaryDeepGreen)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime(2020),
                lastDate: _end,
              );
              if (picked != null) setState(() => _start = picked);
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
                  Text(DateFormat('dd MMM yyyy').format(_start)),
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
                initialDate: _end,
                firstDate: _start,
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _end = picked);
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
                  Text(DateFormat('dd MMM yyyy').format(_end)),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(foregroundColor: widget.primaryDeepGreen),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final endOfDay = DateTime(_end.year, _end.month, _end.day, 23, 59, 59);
            Navigator.pop(context, {'start': _start, 'end': endOfDay});
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(widget.primaryDeepGreen),
            foregroundColor: WidgetStateProperty.all(widget.offWhite),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
