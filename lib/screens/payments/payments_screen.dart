import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/payment_method_selector.dart';
import '../../models/sale.dart';
import '../../models/service.dart';
import '../../models/ledger_entry.dart';
import '../../widgets/firestore_error_view.dart';
import '../sales/receipt_preview_screen.dart';
import '../services/service_receipt_preview_screen.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../data/data_keys.dart';
import '../../config/app_links.dart';

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

  String _searchQuery = '';
  late final TextEditingController _searchController;

  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  final Map<String, String> _userNames = {};
  Timer? _searchDebounce;
  // Periodically checks (never a live listener) whether new ledger
  // entries have landed since the current session's snapshot moment,
  // to drive the "N new entries available - Refresh" banner.
  Timer? _newRecordsCheckTimer;

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
  LedgerEntry? _selectedEntry;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialClientName ?? '');
    _searchQuery = widget.initialClientName ?? '';

    final now = DateTime.now();
    if (widget.initialClientId != null) {
      // Viewing one client's history - default to a wide window so their
      // past payments are actually visible, not just "did they pay today".
      _rangeStart = now.subtract(AppRanges.paymentsDefaultRange);
      _rangeEnd = now;
    } else {
      // Default view: today only.
      _rangeStart = DateTime(now.year, now.month, now.day);
      _rangeEnd = now;
    }

    _openLedgerSession();
    _newRecordsCheckTimer = Timer.periodic(
      AppTimeouts.newRecordsPoll,
      (_) => Provider.of<PaymentProvider>(context, listen: false).ledgerController.checkForNewEntries(),
    );
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
    _searchDebounce?.cancel();
    _newRecordsCheckTimer?.cancel();
    super.dispose();
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

  /// Records the toolbar's current filters and chosen date range onto
  /// PaymentProvider, then (re)opens the ledger session for them - a
  /// no-op if neither has actually changed and a session's already
  /// open. Loads the user names shown against each entry right after,
  /// same as the method this replaces did.
  Future<void> _openLedgerSession({bool forceRefresh = false}) async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    final provider = Provider.of<PaymentProvider>(context, listen: false);
    final signature = provider.updateLedgerFilters(
      facilityId: facilityId,
      searchTerm: _searchQuery,
      typeFilter: _typeTabs.firstWhere((t) => t.$1 == _selectedTypeFilter).$2,
      methodFilter: _selectedMethodFilter,
      initialClientId: widget.initialClientId,
    );
    await provider.ledgerController.openSession(
      querySignature: signature,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      await _loadUserNames(provider.ledgerController.entries);
    }
  }

  Future<void> _loadUserNames(List<LedgerEntry> entries) async {
    final uniqueIds = entries
        .map((e) => e.paidById)
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_userNames.containsKey(id))
        .toSet();
    if (uniqueIds.isEmpty) return;

    try {
      final futures = uniqueIds.map((id) => FirebaseFirestore.instance.collection(Collections.users).doc(id).get());
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

  Future<(String?, String?)> _getSourceDetailsFuture(LedgerEntry e) {
    final key = '${e.type}_${e.saleId}_${e.serviceId}_${e.debtId}';
    return _referenceFutureByKey.putIfAbsent(key, () async {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId == null) return (null, null);
      try {
        if (e.type == 'sale' && e.saleId != null) {
          return _formattedReceiptWithNotes(facilityId, Collections.sales, e.saleId!, 'SL', 'notes');
        } else if (e.type == 'service' && e.serviceId != null) {
          return _formattedReceiptWithNotes(facilityId, Collections.services, e.serviceId!, 'SV', 'description');
        } else if (e.type == 'debt_repayment' && e.debtId != null) {
          final debtDoc = await FirebaseFirestore.instance
              .collection(Collections.facilities)
              .doc(facilityId)
              .collection(Collections.debts)
              .doc(e.debtId)
              .get();
          final debtData = debtDoc.data();
          if (debtData == null) return (null, null);
          final source = debtData['source'] as String?;
          if (source == 'Sale' && debtData['saleId'] != null) {
            return _formattedReceiptWithNotes(facilityId, Collections.sales, debtData['saleId'] as String, 'SL', 'notes');
          } else if (source == 'Service' && debtData['serviceId'] != null) {
            return _formattedReceiptWithNotes(facilityId, Collections.services, debtData['serviceId'] as String, 'SV', 'description');
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
        await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).collection(collection).doc(docId).get();
    final data = doc.data();
    final receiptNumber = (data?['receiptNumber'] as num?)?.toInt();
    final reference = receiptNumber == null ? null : '$prefix-${receiptNumber.toString().padLeft(6, '0')}';
    final notes = data?[notesField] as String?;
    return (reference, notes);
  }

  Future<(String, String)?> _resolvePrintTarget(LedgerEntry e) async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return null;
    if (e.type == 'sale' && e.saleId != null) return ('sales', e.saleId!);
    if (e.type == 'service' && e.serviceId != null) return ('services', e.serviceId!);
    if (e.type == 'debt_repayment' && e.debtId != null) {
      final debtDoc = await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.debts)
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

  Future<void> _printReceiptFor(LedgerEntry e) async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;
    final target = await _resolvePrintTarget(e);
    if (target == null) {
      AppFeedback.info('No receipt available for this payment');
      return;
    }
    final (collection, docId) = target;
    final doc =
        await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).collection(collection).doc(docId).get();
    if (doc.data() == null) return;
    if (!mounted) return;
    if (collection == Collections.sales) {
      final sale = Sale.fromFirestore(doc.data(), doc.id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(sale: sale)));
    } else {
      final service = Service.fromFirestore(doc.data()!, doc.id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceReceiptPreviewScreen(service: service)));
    }
  }


  Future<(double, int)> _fetchPaymentsSum(String facilityId, DateTime start, DateTime end) async {
    final snap = await FirebaseFirestore.instance
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.payments)
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
    final yesterday = today.subtract(AppRanges.day);
    final weekStart = now.subtract(AppRanges.week);
    final previousWeekStart = now.subtract(AppRanges.fortnight);
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = monthStart.subtract(AppRanges.instant);

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
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.dailySnapshots)
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
        primaryDeepGreen: context.colors.primary,
        warmAmber: context.colors.accent,
        offWhite: context.colors.background,
      ),
    );

    if (result == null) return;

    setState(() {
      _rangeStart = result['start']!;
      _rangeEnd = result['end']!;
    });

    await _openLedgerSession();
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: paymentProvider.ledgerController,
              builder: (context, _) {
                final controller = paymentProvider.ledgerController;
                final filtered = controller.entries;
                final total = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

                // Group by calendar day, preserving descending order.
                final Map<String, List<LedgerEntry>> grouped = {};
                for (final e in filtered) {
                  final key = DateFormat(DataKeys.isoDay).format(e.timestamp);
                  grouped.putIfAbsent(key, () => []).add(e);
                }

                if (controller.error != null && filtered.isEmpty) {
                  return Center(child: FirestoreErrorView(error: controller.error));
                }

                return controller.isLoading && filtered.isEmpty
                    ? Center(child: CircularProgressIndicator(color: context.colors.primary))
                    : Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.initialClientId == null) ...[
                              _buildMetricsRow(),
                              const SizedBox(height: AppSpacing.s16),
                            ],
                            if (controller.newEntriesAvailable > 0)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                                color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                                child: Row(
                                  children: [
                                    Icon(Icons.fiber_new, size: AppIconSize.i18, color: context.colors.primary),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Text(
                                        '${controller.newEntriesAvailable} new entr'
                                        '${controller.newEntriesAvailable == 1 ? 'y' : 'ies'} available',
                                        style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.primary),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => controller.refreshSession(),
                                      child: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              ),
                            _buildToolbarRow(total),
                            const SizedBox(height: AppSpacing.s16),
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Text('No payments in this period.', style: TextStyle(color: context.colors.textMuted)),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
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
                      );
              },
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
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _metricCard('Today', _todayMetric)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: _metricCard('This Week', _weekMetric)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: _metricCard('This Month', _monthMetric)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: _outstandingCard()),
        ],
      ),
    );
  }

  Widget _metricCard(String title, _PaymentMetric? metric) {
    final isLoading = _isMetricsLoading && metric == null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s4),
          AnimatedSwitcher(
            duration: AppMotion.slow,
            child: isLoading
                ? SizedBox(key: const ValueKey('loading'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary))
                : Column(
                    key: const ValueKey('loaded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            Money.symbolPlain(metric?.amount ?? 0),
                            style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold),
                          ),
                          if (metric?.trendPercent != null) ...[
                            const SizedBox(width: AppSpacing.s8),
                            _trendPill(metric!.trendPercent!),
                          ],
                        ],
                      ),
                      Text('${metric?.count ?? 0} payments', style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
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
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s4),
          AnimatedSwitcher(
            duration: AppMotion.slow,
            child: isLoading
                ? SizedBox(key: const ValueKey('loading'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary))
                : Column(
                    key: const ValueKey('loaded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            Money.symbolPlain(_outstandingAmount ?? 0),
                            style: TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold, color: context.colors.accent),
                          ),
                          if (trendPercent != null) ...[
                            const SizedBox(width: AppSpacing.s8),
                            _trendPill(trendPercent, invertColors: true),
                          ],
                        ],
                      ),
                      Text('${_outstandingCount ?? 0} debts', style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
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
    final color = isGood ? context.colors.successStrong : context.colors.dangerStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: color),
          const SizedBox(width: AppSpacing.s2),
          Text('${percent.abs().toStringAsFixed(1)}%', style: TextStyle(
                  fontSize: AppFontSize.f10_5, color: color, fontWeight: AppFontWeight.semibold)),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(
          fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
    );
  }

  Widget _buildDetailsPanel(LedgerEntry e) {
    final recordedBy = e.paidById != null ? _userNames[e.paidById] : null;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Details', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i20),
                  onPressed: () => setState(() => _selectedEntry = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                  color: context.colors.success.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 13, color: context.colors.successStrong),
                  const SizedBox(width: AppSpacing.s4),
                  Text('Payment Received', style: TextStyle(
                      fontSize: AppFontSize.f11_5, color: context.colors.successStrong, fontWeight: AppFontWeight.semibold)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(Money.symbolPlain(e.amount), style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f22)),
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
              child: Text(e.description, style: TextStyle(
                  fontSize: AppFontSize.f11_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: AppIconSize.i12, color: context.colors.textMuted),
                const SizedBox(width: AppSpacing.s4),
                Text(
                  '${AppDateFormat.date.format(e.timestamp)}, ${AppDateFormat.time12.format(e.timestamp)}',
                  style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
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
                      Text(e.clientName ?? '-', style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14)),
                      if (e.clientPhone != null) Text(e.clientPhone!, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                    ],
                  ),
                ),
                if (e.clientPhone != null)
                  IconButton(
                    icon: Icon(Icons.phone_outlined, size: AppIconSize.i18, color: context.colors.primary),
                    tooltip: 'Call',
                    onPressed: () async {
                      final uri = AppLinks.tel(e.clientPhone!);
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched) {
                        AppFeedback.info("Couldn't open the dialer");
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            FutureBuilder<(String?, String?)>(
              future: _getSourceDetailsFuture(e),
              builder: (context, snapshot) {
                final reference = snapshot.data?.$1;
                final notes = snapshot.data?.$2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailLabel('Source'),
                    Text('${e.description}${reference != null ? ' $reference' : ''}', style: const TextStyle(fontSize: AppFontSize.f14)),
                    const SizedBox(height: AppSpacing.s16),
                    _detailLabel('Payment Method'),
                    Text(e.paymentMethod ?? '-', style: const TextStyle(fontSize: AppFontSize.f14)),
                    const SizedBox(height: AppSpacing.s16),
                    _detailLabel('Recorded By'),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: AppIconSize.i16, color: context.colors.textMuted),
                        const SizedBox(width: AppSpacing.s6),
                        Text(recordedBy ?? '-', style: const TextStyle(fontSize: AppFontSize.f14)),
                      ],
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s16),
                      _detailLabel('Notes'),
                      Text(notes, style: const TextStyle(fontSize: AppFontSize.f13_5)),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _printReceiptFor(e),
                icon: const Icon(Icons.print_outlined, size: AppIconSize.i18),
                label: const Text('Print Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Text(label, style: TextStyle(
          fontSize: AppFontSize.f11_5, color: context.colors.textMuted, fontWeight: AppFontWeight.semibold)),
    );
  }

  Widget _buildToolbarRow(double total) {
    final hasActiveFilters = _selectedTypeFilter != 'All' || _selectedMethodFilter != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search payer, reference, invoice...',
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
                      onPressed: () {
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = '');
                        _searchController.clear();
                        _openLedgerSession();
                      },
                    ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
              _searchDebounce?.cancel();
              _searchDebounce = Timer(AppTimeouts.searchDebounce, _openLedgerSession);
            },
          ),
        ),
        if (widget.initialClientId == null) ...[
          const SizedBox(width: AppSpacing.s10),
          _toolbarDropdown<String>(
            value: _selectedTypeFilter,
            items: _typeTabs.map((t) => t.$1).toList(),
            label: 'Type',
            onChanged: (val) {
              setState(() => _selectedTypeFilter = val);
              _openLedgerSession();
            },
          ),
          const SizedBox(width: AppSpacing.s10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.r10),
              border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedMethodFilter,
                hint: const Text('All Methods', style: TextStyle(fontSize: AppFontSize.f13)),
                icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
                style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Method: All')),
                  ...kPaymentMethods.map((m) => DropdownMenuItem<String?>(value: m, child: Text('Method: $m'))),
                ],
                onChanged: (val) {
                  setState(() => _selectedMethodFilter = val);
                  _openLedgerSession();
                },
              ),
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: AppSpacing.s8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedTypeFilter = 'All';
                  _selectedMethodFilter = null;
                });
                _openLedgerSession();
              },
              child: const Text('Clear', style: TextStyle(fontSize: AppFontSize.f13)),
            ),
          ],
        ],
        const SizedBox(width: AppSpacing.s16),
        Text(
          'Total: ${Money.symbolPlain(total)}',
          style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.bold, color: context.colors.primary),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
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
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.initialClientName != null ? 'Payments - ${widget.initialClientName}' : 'Payments',
            style: TextStyle(
                fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary),
          ),
          Text('All payments received across your business',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: OutlinedButton.icon(
            onPressed: _showDateRangeDialog,
            icon: const Icon(Icons.date_range_outlined, size: AppIconSize.i16),
            label: Text(
              '${AppDateFormat.date.format(_rangeStart)} - ${AppDateFormat.date.format(_rangeEnd)}',
              style: const TextStyle(fontSize: AppFontSize.f12_5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayGroup(String dayKey, List<LedgerEntry> entries, double dayTotal) {
    final date = DateTime.parse(dayKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(AppRanges.day);

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = AppDateFormat.dateLongPadded.format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
            color: context.colors.primary.withValues(alpha: AppAlpha.a05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$label - ${AppDateFormat.date.format(date)}',
                  style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12_5, color: context.colors.primary),
                ),
                Text(
                  Money.symbolPlain(dayTotal),
                  style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.bold, color: context.colors.primary),
                ),
              ],
            ),
          ),
          ...entries.map(_buildEntryTile),
        ],
      ),
    );
  }

  Widget _buildEntryTile(LedgerEntry e) {
    final recordedBy = e.paidById != null ? _userNames[e.paidById] : null;
    final isSelected = _selectedEntry == e;
    return InkWell(
      onTap: () => setState(() => _selectedEntry = e),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
        border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a10))),
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
                  backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                  child: Icon(_iconFor(e.type), size: AppIconSize.i14, color: context.colors.primary),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(AppDateFormat.time12.format(e.timestamp), style: const TextStyle(fontSize: AppFontSize.f13)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(e.clientName ?? '-', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
              decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
              child: Text(e.description, style: TextStyle(
                  fontSize: AppFontSize.f10_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
            ),
          ),
          Expanded(
            flex: 2,
            child: FutureBuilder<(String?, String?)>(
              future: _getSourceDetailsFuture(e),
              builder: (context, snapshot) {
                final ref = snapshot.data?.$1;
                return Text(ref ?? '-', style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSecondary));
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(e.paymentMethod ?? '-', style: const TextStyle(fontSize: AppFontSize.f13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Money.symbolPlain(e.amount),
              style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13, color: context.colors.primary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(recordedBy ?? '-', style: const TextStyle(fontSize: AppFontSize.f13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          const Text('Start Date:', style: TextStyle(fontWeight: AppFontWeight.bold)),
          const SizedBox(height: AppSpacing.s8),
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
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.borderStrong),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                  const SizedBox(width: AppSpacing.s12),
                  Text(AppDateFormat.date.format(_start)),
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
                initialDate: _end,
                firstDate: _start,
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _end = picked);
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
                  Text(AppDateFormat.date.format(_end)),
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
