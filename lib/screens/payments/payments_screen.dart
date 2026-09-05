import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import '../../widgets/payment_method_selector.dart';
import '../../models/sale.dart';
import '../../models/service.dart';
import '../sales/receipt_preview_screen.dart';
import '../services/service_receipt_preview_screen.dart';

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
  final String? clientPhone;
  final String description;
  final String? paymentMethod;
  final String? paidById;
  final String? saleId;
  final String? serviceId;
  final String? debtId;

  const _LedgerEntry({
    required this.type,
    required this.amount,
    required this.timestamp,
    this.clientId,
    this.clientName,
    this.clientPhone,
    required this.description,
    this.paymentMethod,
    this.paidById,
    this.saleId,
    this.serviceId,
    this.debtId,
  });
}

class _PaymentMetric {
  final double amount;
  final int count;
  final double? previousAmount;

  _PaymentMetric({required this.amount, required this.count, this.previousAmount});

  double? get trendPercent {
    if (previousAmount == null || previousAmount == 0) return null;
    return ((amount - previousAmount!) / previousAmount!) * 100;
  }
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
  late final TextEditingController _searchController;

  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  bool _isLoading = false;
  final Map<String, String> _userNames = {};
  List<_LedgerEntry> _entries = [];

  _PaymentMetric? _todayMetric;
  _PaymentMetric? _weekMetric;
  _PaymentMetric? _monthMetric;
  double? _outstandingAmount;
  int? _outstandingCount;
  double? _previousOutstanding;
  bool _isMetricsLoading = false;
  int _metricsRequestId = 0;

  static const List<(String, String?)> _typeTabs = [
    ('All', null),
    ('Sales', 'sale'),
    ('Services', 'service'),
    ('Debt Repayments', 'debt_repayment'),
    ('Other Income', 'other_income'),
  ];
  String _selectedTypeFilter = 'All';
  String? _selectedMethodFilter;
  final Map<String, Future<(String?, String?)>> _referenceFutureByKey = {};
  _LedgerEntry? _selectedEntry;

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
    if (widget.initialClientId == null) {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId != null) {
        Provider.of<DebtProvider>(context, listen: false).listenToDebts(facilityId);
      }
      _loadMetrics();
    }
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
          clientPhone: data['clientPhone'] as String?,
          description: _labelFor(source),
          paymentMethod: data['paymentMethod'] as String?,
          paidById: data['paidById'] as String?,
          saleId: data['saleId'] as String?,
          serviceId: data['serviceId'] as String?,
          debtId: data['debtId'] as String?,
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
            paymentMethod: data['paymentMethod'] as String?,
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

      await _loadUserNames(entries);
    } catch (e) {
      debugPrint('Error loading payments ledger: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserNames(List<_LedgerEntry> entries) async {
    final uniqueIds = entries
        .map((e) => e.paidById)
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_userNames.containsKey(id))
        .toSet();
    if (uniqueIds.isEmpty) return;

    try {
      final futures = uniqueIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get());
      final docs = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        for (final doc in docs) {
          final name = doc.data()?['fullName'] as String?;
          if (name != null && name.isNotEmpty) _userNames[doc.id] = name;
        }
      });
    } catch (e) {
      debugPrint('Error loading payer names: $e');
    }
  }

  Future<(String?, String?)> _getSourceDetailsFuture(_LedgerEntry e) {
    final key = '${e.type}_${e.saleId}_${e.serviceId}_${e.debtId}';
    return _referenceFutureByKey.putIfAbsent(key, () async {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId == null) return (null, null);
      try {
        if (e.type == 'sale' && e.saleId != null) {
          return _formattedReceiptWithNotes(facilityId, 'sales', e.saleId!, 'SL', 'notes');
        } else if (e.type == 'service' && e.serviceId != null) {
          return _formattedReceiptWithNotes(facilityId, 'services', e.serviceId!, 'SV', 'description');
        } else if (e.type == 'debt_repayment' && e.debtId != null) {
          final debtDoc = await FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('debts')
              .doc(e.debtId)
              .get();
          final debtData = debtDoc.data();
          if (debtData == null) return (null, null);
          final source = debtData['source'] as String?;
          if (source == 'Sale' && debtData['saleId'] != null) {
            return _formattedReceiptWithNotes(facilityId, 'sales', debtData['saleId'] as String, 'SL', 'notes');
          } else if (source == 'Service' && debtData['serviceId'] != null) {
            return _formattedReceiptWithNotes(facilityId, 'services', debtData['serviceId'] as String, 'SV', 'description');
          }
        }
      } catch (err) {
        debugPrint('Could not load source details for payment: $err');
      }
      return (null, null);
    });
  }

  Future<(String?, String?)> _formattedReceiptWithNotes(
      String facilityId, String collection, String docId, String prefix, String notesField) async {
    final doc =
        await FirebaseFirestore.instance.collection('facilities').doc(facilityId).collection(collection).doc(docId).get();
    final data = doc.data();
    final receiptNumber = (data?['receiptNumber'] as num?)?.toInt();
    final reference = receiptNumber == null ? null : '$prefix-${receiptNumber.toString().padLeft(6, '0')}';
    final notes = data?[notesField] as String?;
    return (reference, notes);
  }

  Future<(String, String)?> _resolvePrintTarget(_LedgerEntry e) async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return null;
    if (e.type == 'sale' && e.saleId != null) return ('sales', e.saleId!);
    if (e.type == 'service' && e.serviceId != null) return ('services', e.serviceId!);
    if (e.type == 'debt_repayment' && e.debtId != null) {
      final debtDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .doc(e.debtId)
          .get();
      final debtData = debtDoc.data();
      if (debtData == null) return null;
      final source = debtData['source'] as String?;
      if (source == 'Sale' && debtData['saleId'] != null) return ('sales', debtData['saleId'] as String);
      if (source == 'Service' && debtData['serviceId'] != null) return ('services', debtData['serviceId'] as String);
    }
    return null;
  }

  Future<void> _printReceiptFor(_LedgerEntry e) async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;
    final target = await _resolvePrintTarget(e);
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No receipt available for this payment.')));
      }
      return;
    }
    final (collection, docId) = target;
    final doc =
        await FirebaseFirestore.instance.collection('facilities').doc(facilityId).collection(collection).doc(docId).get();
    if (doc.data() == null) return;
    if (!mounted) return;
    if (collection == 'sales') {
      final sale = Sale.fromFirestore(doc.data(), doc.id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(sale: sale)));
    } else {
      final service = Service.fromFirestore(doc.data()!, doc.id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: service)));
    }
  }


  Future<(double, int)> _fetchPaymentsSum(String facilityId, DateTime start, DateTime end) async {
    final snap = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('payments')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return (sum, snap.docs.length);
  }

  Future<void> _loadMetrics() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isMetricsLoading = true);
    final requestId = ++_metricsRequestId;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = now.subtract(const Duration(days: 7));
    final previousWeekStart = now.subtract(const Duration(days: 14));
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = monthStart.subtract(const Duration(seconds: 1));

    // Same dailySnapshots record the dashboard reads for its own
    // "outstanding balance last period" trend - the equivalent point
    // one month ago, not just the 1st of last month.
    final snapshotDateKey =
        '${lastMonthEnd.year.toString().padLeft(4, '0')}-${lastMonthEnd.month.toString().padLeft(2, '0')}-${lastMonthEnd.day.toString().padLeft(2, '0')}';

    try {
      final results = await Future.wait([
        _fetchPaymentsSum(facilityId, today, now),
        _fetchPaymentsSum(facilityId, yesterday, today),
        _fetchPaymentsSum(facilityId, weekStart, now),
        _fetchPaymentsSum(facilityId, previousWeekStart, weekStart),
        _fetchPaymentsSum(facilityId, monthStart, now),
        _fetchPaymentsSum(facilityId, lastMonthStart, lastMonthEnd),
      ]);
      final snapshotDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('dailySnapshots')
          .doc(snapshotDateKey)
          .get();

      if (requestId != _metricsRequestId) return;
      if (!mounted) return;

      final debtProvider = Provider.of<DebtProvider>(context, listen: false);

      setState(() {
        _todayMetric = _PaymentMetric(
          amount: results[0].$1,
          count: results[0].$2,
          previousAmount: results[1].$1,
        );
        _weekMetric = _PaymentMetric(
          amount: results[2].$1,
          count: results[2].$2,
          previousAmount: results[3].$1,
        );
        _monthMetric = _PaymentMetric(
          amount: results[4].$1,
          count: results[4].$2,
          previousAmount: results[5].$1,
        );
        _outstandingAmount = debtProvider.totalOutstanding();
        _outstandingCount = debtProvider.debts.length;
        _previousOutstanding = (snapshotDoc.data()?['totalOutstanding'] as num?)?.toDouble();
        _isMetricsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payment metrics: $e');
      if (requestId != _metricsRequestId) return;
      if (mounted) setState(() => _isMetricsLoading = false);
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
      final selectedType = _typeTabs.firstWhere((t) => t.$1 == _selectedTypeFilter).$2;
      if (selectedType != null && e.type != selectedType) return false;
      if (_selectedMethodFilter != null && e.paymentMethod != _selectedMethodFilter) return false;

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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryDeepGreen))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.initialClientId == null) ...[
                          _buildMetricsRow(),
                          const SizedBox(height: 16),
                        ],
                        _buildToolbarRow(total),
                        const SizedBox(height: 16),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text('No payments in this period.', style: TextStyle(color: Colors.grey[600])),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
                                      child: Row(
                                        children: [
                                          _headerCell('Date & Time', flex: 3),
                                          _headerCell('Payer', flex: 2),
                                          _headerCell('Source', flex: 2),
                                          _headerCell('Reference', flex: 2),
                                          _headerCell('Method', flex: 2),
                                          _headerCell('Amount', flex: 2),
                                          _headerCell('Recorded By', flex: 2),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        children: grouped.entries.map((dayEntry) {
                                          final dayTotal =
                                              dayEntry.value.fold<double>(0.0, (sum, e) => sum + e.amount);
                                          return _buildDayGroup(dayEntry.key, dayEntry.value, dayTotal);
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_selectedEntry != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _buildDetailsPanel(_selectedEntry!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _metricCard('Today', _todayMetric)),
          const SizedBox(width: 12),
          Expanded(child: _metricCard('This Week', _weekMetric)),
          const SizedBox(width: 12),
          Expanded(child: _metricCard('This Month', _monthMetric)),
          const SizedBox(width: 12),
          Expanded(child: _outstandingCard()),
        ],
      ),
    );
  }

  Widget _metricCard(String title, _PaymentMetric? metric) {
    final isLoading = _isMetricsLoading && metric == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoading
                ? SizedBox(key: const ValueKey('loading'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryDeepGreen))
                : Column(
                    key: const ValueKey('loaded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tsh ${_moneyFormat.format(metric?.amount ?? 0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text('${metric?.count ?? 0} payments', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      if (metric?.trendPercent != null) ...[
                        const SizedBox(height: 4),
                        _trendPill(metric!.trendPercent!),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _outstandingCard() {
    final trendPercent = (_previousOutstanding != null && _previousOutstanding != 0 && _outstandingAmount != null)
        ? ((_outstandingAmount! - _previousOutstanding!) / _previousOutstanding!) * 100
        : null;
    final isLoading = _isMetricsLoading && _outstandingAmount == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoading
                ? SizedBox(key: const ValueKey('loading'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryDeepGreen))
                : Column(
                    key: const ValueKey('loaded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tsh ${_moneyFormat.format(_outstandingAmount ?? 0)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: warmAmber),
                      ),
                      Text('${_outstandingCount ?? 0} debts', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      if (trendPercent != null) ...[
                        const SizedBox(height: 4),
                        _trendPill(trendPercent, invertColors: true),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // For most metrics, up is good (green) and down is bad (red). For
  // Outstanding, that's inverted - a rising unpaid balance is the bad
  // direction, a falling one is good.
  Widget _trendPill(double percent, {bool invertColors = false}) {
    final isUp = percent >= 0;
    final isGood = invertColors ? !isUp : isUp;
    final color = isGood ? Colors.green[700]! : Colors.red[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: color),
          const SizedBox(width: 2),
          Text('${percent.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _buildDetailsPanel(_LedgerEntry e) {
    final recordedBy = e.paidById != null ? _userNames[e.paidById] : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedEntry = null),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 13, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text('Payment Received', style: TextStyle(fontSize: 11.5, color: Colors.green[700], fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Tsh ${_moneyFormat.format(e.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: primaryDeepGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(e.description, style: TextStyle(fontSize: 11.5, color: primaryDeepGreen, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('dd MMM yyyy').format(e.timestamp)}, ${DateFormat('hh:mm a').format(e.timestamp)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(height: 32),
            _detailLabel('Payer'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.clientName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (e.clientPhone != null) Text(e.clientPhone!, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (e.clientPhone != null)
                  IconButton(
                    icon: Icon(Icons.phone_outlined, size: 18, color: primaryDeepGreen),
                    tooltip: 'Call',
                    onPressed: () async {
                      final uri = Uri.parse('tel:${e.clientPhone}');
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<(String?, String?)>(
              future: _getSourceDetailsFuture(e),
              builder: (context, snapshot) {
                final reference = snapshot.data?.$1;
                final notes = snapshot.data?.$2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailLabel('Source'),
                    Text('${e.description}${reference != null ? ' $reference' : ''}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    _detailLabel('Payment Method'),
                    Text(e.paymentMethod ?? '-', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    _detailLabel('Recorded By'),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(recordedBy ?? '-', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailLabel('Notes'),
                      Text(notes, style: const TextStyle(fontSize: 13.5)),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _printReceiptFor(e),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDeepGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildToolbarRow(double total) {
    final hasActiveFilters = _selectedTypeFilter != 'All' || _selectedMethodFilter != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search payer, reference, invoice...',
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
                      }),
                    ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),
        if (widget.initialClientId == null) ...[
          const SizedBox(width: 10),
          _toolbarDropdown<String>(
            value: _selectedTypeFilter,
            items: _typeTabs.map((t) => t.$1).toList(),
            label: 'Type',
            onChanged: (val) => setState(() => _selectedTypeFilter = val),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedMethodFilter,
                hint: const Text('All Methods', style: TextStyle(fontSize: 13)),
                icon: Icon(Icons.arrow_drop_down, size: 18, color: primaryDeepGreen),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Method: All')),
                  ...kPaymentMethods.map((m) => DropdownMenuItem<String?>(value: m, child: Text('Method: $m'))),
                ],
                onChanged: (val) => setState(() => _selectedMethodFilter = val),
              ),
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() {
                _selectedTypeFilter = 'All';
                _selectedMethodFilter = null;
              }),
              child: const Text('Clear', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
        const SizedBox(width: 16),
        Text(
          'Total: Tsh ${_moneyFormat.format(total)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryDeepGreen),
        ),
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
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.initialClientName != null ? 'Payments - ${widget.initialClientName}' : 'Payments',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87),
          ),
          const Text('All payments received across your business',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OutlinedButton.icon(
            onPressed: _showDateRangeDialog,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              '${DateFormat('dd MMM yyyy').format(_rangeStart)} - ${DateFormat('dd MMM yyyy').format(_rangeEnd)}',
              style: const TextStyle(fontSize: 12.5),
            ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: primaryDeepGreen.withValues(alpha: 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$label - ${DateFormat('dd MMM yyyy').format(date)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: primaryDeepGreen),
                ),
                Text(
                  'Tsh ${_moneyFormat.format(dayTotal)}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryDeepGreen),
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
    final recordedBy = e.paidById != null ? _userNames[e.paidById] : null;
    final isSelected = _selectedEntry == e;
    return InkWell(
      onTap: () => setState(() => _selectedEntry = e),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? primaryDeepGreen.withValues(alpha: 0.06) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryDeepGreen.withValues(alpha: 0.1),
                  child: Icon(_iconFor(e.type), size: 14, color: primaryDeepGreen),
                ),
                const SizedBox(width: 8),
                Text(DateFormat('hh:mm a').format(e.timestamp), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(e.clientName ?? '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: primaryDeepGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(e.description, style: TextStyle(fontSize: 10.5, color: primaryDeepGreen, fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            flex: 2,
            child: FutureBuilder<(String?, String?)>(
              future: _getSourceDetailsFuture(e),
              builder: (context, snapshot) {
                final ref = snapshot.data?.$1;
                return Text(ref ?? '-', style: const TextStyle(fontSize: 12.5, color: Colors.black54));
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(e.paymentMethod ?? '-', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Tsh ${_moneyFormat.format(e.amount)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryDeepGreen),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(recordedBy ?? '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
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
