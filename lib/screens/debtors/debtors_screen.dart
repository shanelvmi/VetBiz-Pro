import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/client.dart';
import '../../models/debt.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import 'add_payment_screen.dart';
import '../payments/payments_screen.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _overdueRangeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // A debt older than this many days counts as "Overdue" - there's no
  // due-date field anywhere on Debt, so this is a convention we're
  // introducing, not something derived from existing app logic.
  static const int _overdueDays = 30;

  // Which debtor (by clientId) is shown in the details panel, and the
  // display pagination window - same pattern as the other rebuilt
  // screens.
  String? _selectedClientId;
  int _displayPageSize = 10;
  int _currentPageIndex = 0;
  String? _facilityId;
  double? _paidThisMonth;
  bool _isPaidThisMonthLoading = false;

  // Lazy-loaded, per-client cache of debtor notes - only fetched once
  // a given debtor's details panel is actually opened, then cached.
  // Cleared for a client whenever a new note is added, so the panel
  // picks up the fresh list on the next read.
  final Map<String, Future<List<Map<String, dynamic>>>> _notesFutureByClient = {};

  // Debt itself has no invoice/receipt number - only a saleId or
  // serviceId reference. Lazy-loaded and cached per debt id, since
  // this needs its own fetch of the original sale/service document.
  final Map<String, Future<int?>> _receiptNumberFutureByDebt = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';

    if (facilityId.isNotEmpty && facilityId != _facilityId) {
      _facilityId = facilityId;
      Provider.of<DebtProvider>(context, listen: false).listenToDebts(facilityId);
      _loadPaidThisMonth();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPaidThisMonth() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isPaidThisMonthLoading = true);
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      // "From debt payments" specifically - a payment made against a
      // fresh sale/service (no debtId) isn't a debt repayment, even
      // though it lives in the same collection.
      double total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['debtId'] != null) {
          total += ((data['amount'] ?? 0.0) as num).toDouble();
        }
      }

      if (!mounted) return;
      setState(() {
        _paidThisMonth = total;
        _isPaidThisMonthLoading = false;
      });
    } catch (e) {
      debugPrint('Could not load Paid This Month: $e');
      if (mounted) setState(() => _isPaidThisMonthLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtProvider = Provider.of<DebtProvider>(context);
    final debts = debtProvider.debts;
    final now = DateTime.now();

    // Group debts by clientId - clientName/clientPhone come straight
    // off the Debt record itself (denormalized at creation time),
    // rather than a live Firestore lookup per client on every render.
    final Map<String, List<Debt>> debtsByClient = {};
    for (final debt in debts) {
      debtsByClient.putIfAbsent(debt.clientId, () => []).add(debt);
    }

    final debtors = debtsByClient.entries.map((entry) {
      final clientDebts = entry.value;
      final totalOwed = clientDebts.fold<double>(0, (sum, d) => sum + d.amountOwed);
      final overdueAmount = clientDebts
          .where((d) => now.difference(d.timestamp).inDays > _overdueDays)
          .fold<double>(0, (sum, d) => sum + d.amountOwed);
      clientDebts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return _DebtorRow(
        clientId: entry.key,
        clientName: clientDebts.first.clientName ?? 'Unknown',
        clientPhone: clientDebts.first.clientPhone ?? '',
        totalOwed: totalOwed,
        overdueAmount: overdueAmount,
        lastTransaction: clientDebts.first.timestamp,
        lastSource: clientDebts.first.source,
        debts: clientDebts,
      );
    }).where((d) => d.totalOwed > 0).toList()
      ..sort((a, b) => b.totalOwed.compareTo(a.totalOwed));

    final filteredDebtors = debtors.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.clientPhone.contains(_searchQuery);

      final isOverdue = d.overdueAmount > 0;
      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Overdue' && isOverdue) ||
          (_statusFilter == 'Current' && !isOverdue);

      final matchesOverdueRange = switch (_overdueRangeFilter) {
        '1-30 days' => d.maxDaysOverdue >= 1 && d.maxDaysOverdue <= 30,
        '31-60 days' => d.maxDaysOverdue >= 31 && d.maxDaysOverdue <= 60,
        '60+ days' => d.maxDaysOverdue > 60,
        _ => true, // 'All'
      };

      return matchesSearch && matchesStatus && matchesOverdueRange;
    }).toList();

    // Same honest display-pagination window as the other rebuilt
    // screens - a page here is a view over the already-loaded, live
    // debtor list, not a true jump to an arbitrary page number.
    final totalPages = (filteredDebtors.length / _displayPageSize).ceil().clamp(1, 999999);
    if (_currentPageIndex >= totalPages) _currentPageIndex = totalPages - 1;
    if (_currentPageIndex < 0) _currentPageIndex = 0;
    final pageStart = _currentPageIndex * _displayPageSize;
    final pageEnd = (pageStart + _displayPageSize).clamp(0, filteredDebtors.length);
    final pageDebtors = filteredDebtors.sublist(pageStart.clamp(0, filteredDebtors.length), pageEnd);

    _DebtorRow? selectedDebtor;
    if (_selectedClientId != null) {
      for (final d in filteredDebtors) {
        if (d.clientId == _selectedClientId) {
          selectedDebtor = d;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(debtors),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildMetricsRow(debtors),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildFiltersToolbar(filteredDebtors),
                ),
                Expanded(
                  child: filteredDebtors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No outstanding debts' : 'No debtors match your search',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : _buildDebtorsTable(pageDebtors),
                ),
                _buildPaginationBar(
                  totalFiltered: filteredDebtors.length,
                  pageStart: pageStart,
                  pageEnd: pageEnd,
                  totalPages: totalPages,
                ),
              ],
            ),
          ),
          if (selectedDebtor != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: _buildDebtorDetailsPanel(selectedDebtor),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== METRICS ROW ====================

  Widget _buildMetricsRow(List<_DebtorRow> debtors) {
    final totalDebtors = debtors.length;
    final totalOwed = debtors.fold<double>(0, (sum, d) => sum + d.totalOwed);
    final overdueAmount = debtors.fold<double>(0, (sum, d) => sum + d.overdueAmount);
    final isPaidLoading = _paidThisMonth == null && _isPaidThisMonthLoading;

    final metrics = [
      ('Total Debtors', '$totalDebtors', Icons.people_outline, primaryDeepGreen, 'With outstanding balance', false),
      ('Total Owed', _moneyFormat.format(totalOwed), Icons.account_balance_wallet_outlined, Colors.orange, 'Outstanding balance', false),
      ('Overdue Amount', _moneyFormat.format(overdueAmount), Icons.error_outline, Colors.red, 'Overdue balance', false),
      (
        'Paid This Month',
        _moneyFormat.format(_paidThisMonth ?? 0),
        Icons.account_balance_outlined,
        Colors.green,
        'From debt payments',
        isPaidLoading,
      ),
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
            return _metricCard(m.$1, m.$2, m.$3, m.$4, m.$5, m.$6);
          },
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String subtitle, bool isLoading) {
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
                    : Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
            Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<_DebtorRow> debtors) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Active Debts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Track and manage all outstanding debts', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () async {
              final debtorClients = debtors
                  .map((d) => Client(
                        id: d.clientId,
                        name: d.clientName,
                        phone: d.clientPhone,
                        address: '',
                        balance: 0.0,
                        types: const [],
                      ))
                  .toList();
              final debtorBalances = {for (final d in debtors) d.clientId: d.totalOwed};
              final result = await showAddPaymentScreen(
                context,
                facilityId: _facilityId,
                debtorClients: debtorClients,
                debtorBalances: debtorBalances,
              );
              if (result == true && _facilityId != null && mounted) {
                Provider.of<DebtProvider>(context, listen: false).listenToDebts(_facilityId!);
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Record Payment'),
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

  // ==================== FILTERS TOOLBAR ====================

  static const List<String> _statusFilterOptions = ['All', 'Overdue', 'Current'];
  static const List<String> _overdueRangeOptions = ['All', '1-30 days', '31-60 days', '60+ days'];

  Widget _buildFiltersToolbar(List<_DebtorRow> debtors) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );
    final hasActiveFilters = _searchQuery.isNotEmpty || _statusFilter != 'All' || _overdueRangeFilter != 'All';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search debtor by name, phone, invoice...',
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
          value: _statusFilter,
          items: _statusFilterOptions,
          label: 'Status',
          onChanged: (val) => setState(() {
            _statusFilter = val;
            _currentPageIndex = 0;
          }),
        ),
        const SizedBox(width: 10),
        _toolbarDropdown<String>(
          value: _overdueRangeFilter,
          items: _overdueRangeOptions,
          label: 'Overdue',
          onChanged: (val) => setState(() {
            _overdueRangeFilter = val;
            _currentPageIndex = 0;
          }),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _statusFilter = 'All';
              _overdueRangeFilter = 'All';
              _currentPageIndex = 0;
            }),
            child: const Text('Reset'),
          ),
        ],
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: debtors.isEmpty ? null : () => _exportDebtors(debtors),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
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

  // ==================== TABLE ====================

  Widget _buildDebtorsTable(List<_DebtorRow> debtors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
          child: Row(
            children: [
              _headerCell('Debtor', flex: 3),
              _headerCell('Total Owed', flex: 2),
              _headerCell('Overdue', flex: 2),
              _headerCell('Last Transaction', flex: 2),
              _headerCell('Status', flex: 2),
              _headerCell('Actions', flex: 2),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: debtors.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
            itemBuilder: (context, index) => _buildDebtorRow(debtors[index]),
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

  Widget _buildDebtorRow(_DebtorRow debtor) {
    final isSelected = _selectedClientId == debtor.clientId;
    final isOverdue = debtor.overdueAmount > 0;

    return InkWell(
      onTap: () => setState(() => _selectedClientId = debtor.clientId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? primaryDeepGreen.withValues(alpha: 0.06) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryDeepGreen.withValues(alpha: 0.15),
                    child: Text(
                      debtor.clientName.isNotEmpty ? debtor.clientName[0].toUpperCase() : '?',
                      style: TextStyle(color: primaryDeepGreen, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debtor.clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (debtor.clientPhone.isNotEmpty)
                          Text(debtor.clientPhone, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                        Text('${debtor.debts.length} outstanding debt${debtor.debts.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 11, color: primaryDeepGreen)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(_moneyFormat.format(debtor.totalOwed),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
            ),
            Expanded(
              flex: 2,
              child: Text(_moneyFormat.format(debtor.overdueAmount),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : Colors.grey[600])),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd MMM yyyy').format(debtor.lastTransaction), style: const TextStyle(fontSize: 13)),
                  Text(debtor.lastSource, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOverdue ? Colors.red : Colors.green).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(isOverdue ? 'Overdue' : 'Current',
                    style: TextStyle(color: isOverdue ? Colors.red : Colors.green, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_active_outlined, size: 18, color: Colors.orange[700]),
                    tooltip: 'Send Reminder',
                    onPressed: debtor.clientPhone.isEmpty
                        ? null
                        : () => _showReminderOptions(context, debtor.clientName, debtor.clientPhone, debtor.totalOwed),
                  ),
                  IconButton(
                    icon: Icon(Icons.history, size: 18, color: primaryDeepGreen),
                    tooltip: 'Payment History',
                    onPressed: () => _openPaymentHistory(debtor),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'view') setState(() => _selectedClientId = debtor.clientId);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Text('View Details')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPaymentHistory(_DebtorRow debtor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentsScreen(initialClientId: debtor.clientId, initialClientName: debtor.clientName),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalFiltered == 0 ? 'No debtors' : 'Showing ${pageStart + 1} to $pageEnd of $totalFiltered debtors',
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
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPageIndex < totalPages - 1 ? () => setState(() => _currentPageIndex++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DEBTOR DETAILS PANEL ====================

  Widget _buildDebtorDetailsPanel(_DebtorRow debtor) {
    final isOverdue = debtor.overdueAmount > 0;

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
                const Text('Debtor Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedClientId = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryDeepGreen.withValues(alpha: 0.15),
                  child: Text(
                    debtor.clientName.isNotEmpty ? debtor.clientName[0].toUpperCase() : '?',
                    style: TextStyle(color: primaryDeepGreen, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debtor.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (debtor.clientPhone.isNotEmpty)
                        Text(debtor.clientPhone, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOverdue ? Colors.red : Colors.green).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isOverdue ? 'Overdue' : 'Current',
                      style: TextStyle(color: isOverdue ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: debtor.clientPhone.isEmpty
                        ? null
                        : () => _showReminderOptions(context, debtor.clientName, debtor.clientPhone, debtor.totalOwed),
                    icon: const Icon(Icons.send_outlined, size: 15),
                    label: const Text('Send Reminder', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPaymentHistory(debtor),
                    icon: const Icon(Icons.history, size: 15),
                    label: const Text('Payment History', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 10),
            _totalsRow('Total Owed', _moneyFormat.format(debtor.totalOwed), color: Colors.red),
            _totalsRow('Overdue Amount', _moneyFormat.format(debtor.overdueAmount), color: Colors.red),
            _totalsRow('Last Transaction', DateFormat('dd MMM yyyy').format(debtor.lastTransaction)),
            const SizedBox(height: 20),
            Text('Outstanding Debts (${debtor.debts.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 10),
            ...debtor.debts.map((debt) => _buildDebtTile(debtor, debt)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                TextButton.icon(
                  onPressed: () => _addNote(debtor),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Note'),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getNotesFuture(debtor.clientId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No notes added', style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                  );
                }
                final sorted = [...notes]
                  ..sort((a, b) {
                    final aTs = a['timestamp'] as Timestamp?;
                    final bTs = b['timestamp'] as Timestamp?;
                    return (bTs?.toDate() ?? DateTime(2000)).compareTo(aTs?.toDate() ?? DateTime(2000));
                  });
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sorted.map((note) {
                    final ts = note['timestamp'] as Timestamp?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note['text'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                          if (ts != null)
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate()),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final selectedClient = Client(
                  id: debtor.clientId,
                  name: debtor.clientName,
                  phone: debtor.clientPhone,
                  address: '',
                  balance: 0.0,
                  types: const [],
                );
                final result = await showAddPaymentScreen(
                  context,
                  preselectedClient: selectedClient,
                  facilityId: _facilityId,
                );
                if (result == true && _facilityId != null && mounted) {
                  Provider.of<DebtProvider>(context, listen: false).listenToDebts(_facilityId!);
                }
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
              label: const Text('Record Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDeepGreen,
                foregroundColor: offWhite,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtTile(_DebtorRow debtor, Debt debt) {
    final isOverdue = DateTime.now().difference(debt.timestamp).inDays > _overdueDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: FutureBuilder<int?>(
                  future: _getReceiptNumberFuture(debt),
                  builder: (context, snapshot) {
                    final receiptNumber = snapshot.data;
                    final invoiceText = receiptNumber != null
                        ? '${_debtInvoicePrefix(debt)}-${receiptNumber.toString().padLeft(6, '0')}'
                        : '${_debtInvoicePrefix(debt)}-......';
                    return Text(
                      'Invoice: $invoiceText \u2022 ${DateFormat('dd MMM yyyy').format(debt.timestamp)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Overdue', style: TextStyle(color: Colors.red, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_debtDescription(debt), style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  Text(_moneyFormat.format(debt.amountOwed),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              ElevatedButton(
                onPressed: () => _payDebt(debtor, debt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDeepGreen,
                  foregroundColor: offWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Pay'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _payDebt(_DebtorRow debtor, Debt debt) async {
    final selectedClient = Client(
      id: debtor.clientId,
      name: debtor.clientName,
      phone: debtor.clientPhone,
      address: '',
      balance: 0.0,
      types: const [],
    );
    final result = await showAddPaymentScreen(
      context,
      preselectedClient: selectedClient,
      debtDocId: debt.id,
      amountOwed: debt.amountOwed,
      facilityId: _facilityId,
    );

    if (result == true && _facilityId != null && mounted) {
      Provider.of<DebtProvider>(context, listen: false).listenToDebts(_facilityId!);
    }
  }

  Future<int?> _getReceiptNumberFuture(Debt debt) {
    return _receiptNumberFutureByDebt.putIfAbsent(debt.id, () async {
      final facilityId = _facilityId;
      if (facilityId == null) return null;
      try {
        if (debt.source == 'Sale' && debt.saleId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('sales')
              .doc(debt.saleId)
              .get();
          return (doc.data()?['receiptNumber'] as num?)?.toInt();
        } else if (debt.source == 'Service' && debt.serviceId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('services')
              .doc(debt.serviceId)
              .get();
          return (doc.data()?['receiptNumber'] as num?)?.toInt();
        }
      } catch (e) {
        debugPrint('Could not load receipt number for debt ${debt.id}: $e');
      }
      return null;
    });
  }

  /// "SL-" for a sale, "SV-" for a service - matches the same prefix
  /// convention already used on the Sales and Services screens, so the
  /// same underlying invoice looks identical wherever it's shown.
  String _debtInvoicePrefix(Debt debt) => debt.source == 'Service' ? 'SV' : 'SL';

  /// What was actually bought or serviced, not just "Sale" or
  /// "Service" - a sale debt lists each product and quantity; a
  /// service debt names the specific service performed.
  String _debtDescription(Debt debt) {
    if (debt.items.isEmpty) return debt.source;
    if (debt.source == 'Service') {
      final item = debt.items.first;
      if (item is Map) {
        final name = item['serviceName'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
      return debt.source;
    }
    // Sale: list each product × quantity, e.g. "Amoxicillin x2, Syringe x1"
    final parts = <String>[];
    for (final item in debt.items) {
      if (item is Map) {
        final name = item['name'] as String?;
        final qty = item['quantity'];
        if (name != null && name.isNotEmpty) {
          parts.add(qty != null ? '$name x$qty' : name);
        }
      }
    }
    return parts.isEmpty ? debt.source : parts.join(', ');
  }

  Future<List<Map<String, dynamic>>> _getNotesFuture(String clientId) {
    return _notesFutureByClient.putIfAbsent(clientId, () async {
      final facilityId = _facilityId;
      if (facilityId == null) return [];
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(clientId)
          .get();
      final raw = doc.data()?['debtorNotes'] as List? ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }

  Future<void> _exportDebtors(List<_DebtorRow> debtors) async {
    final rows = <List<String>>[
      ['Debtor', 'Phone', 'Total Owed', 'Overdue Amount', 'Last Transaction', 'Last Source', 'Status', 'Outstanding Debts'],
      for (final d in debtors)
        [
          d.clientName,
          d.clientPhone,
          d.totalOwed.toStringAsFixed(0),
          d.overdueAmount.toStringAsFixed(0),
          DateFormat('dd MMM yyyy').format(d.lastTransaction),
          d.lastSource,
          d.overdueAmount > 0 ? 'Overdue' : 'Current',
          '${d.debts.length}',
        ],
    ];

    final csvString = rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
    final bytes = Uint8List.fromList(utf8.encode(csvString));

    try {
      final xfile = XFile.fromData(
        bytes,
        name: 'active_debts_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], text: 'Active Debts Export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not export: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _addNote(_DebtorRow debtor) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'e.g. Promised to pay by Friday'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    final facilityId = _facilityId;
    if (facilityId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(debtor.clientId)
          .set({
        'debtorNotes': FieldValue.arrayUnion([
          {'text': text, 'timestamp': Timestamp.now()},
        ]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _notesFutureByClient.remove(debtor.clientId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save note: $e'), backgroundColor: Colors.redAccent));
    }
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

  /// One-tap reminder, not automated bulk sending - opens WhatsApp or
  /// SMS with a pre-filled message ready to review and send. There's no
  /// backend here to send these on a schedule; this is a daily-follow-up
  /// convenience, one debtor at a time.
  Future<void> _showReminderOptions(
      BuildContext context, String clientName, String phone, double amountOwed) async {
    final facilityName =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityName ?? 'us';
    final formatter = NumberFormat('#,##0', 'en_US');
    final message =
        'Hi $clientName, this is a reminder from $facilityName that you have an outstanding '
        'balance of Tsh ${formatter.format(amountOwed)}. Kindly settle at your earliest '
        'convenience. Thank you!';

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Text('Remind $clientName about their Tsh ${formatter.format(amountOwed)} balance via:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'sms'),
            child: const Text('SMS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'whatsapp'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encodedMessage = Uri.encodeComponent(message);

    final uri = choice == 'whatsapp'
        ? Uri.parse('https://wa.me/${digitsOnly.replaceAll('+', '')}?text=$encodedMessage')
        : Uri.parse('sms:$digitsOnly?body=$encodedMessage');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${choice == 'whatsapp' ? 'WhatsApp' : 'Messages'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reminder: $e')),
        );
      }
    }
  }
}

class _DebtorRow {
  final String clientId;
  final String clientName;
  final String clientPhone;
  final double totalOwed;
  final double overdueAmount;
  final DateTime lastTransaction;
  final String lastSource;
  final List<Debt> debts;

  _DebtorRow({
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.totalOwed,
    required this.overdueAmount,
    required this.lastTransaction,
    required this.lastSource,
    required this.debts,
  });

  // The oldest debt determines how overdue this debtor is overall.
  int get maxDaysOverdue {
    if (debts.isEmpty) return 0;
    final oldest = debts.map((d) => d.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(oldest).inDays;
  }
}
