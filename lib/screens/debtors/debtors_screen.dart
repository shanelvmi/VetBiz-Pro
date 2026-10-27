import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../utils/export_texts.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/client.dart';
import '../../models/debt.dart';
import '../../providers/facility_provider.dart';
import '../../providers/client_provider.dart';
import '../../services/cursor_paginated_list_controller.dart';
import '../../widgets/firestore_error_view.dart';
import 'add_payment_screen.dart';
import '../payments/payments_screen.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_date_format.dart';
import '../../data/data_keys.dart';
import '../../config/app_links.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../l10n/l10n.dart';

class DebtorsScreen extends StatefulWidget {
  /// Null: the app's own Firestore. Tests pass an in-memory one (PH2a).
  final FirebaseFirestore? firestore;

  const DebtorsScreen({super.key, this.firestore});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  // Null widget.firestore: the app's own Firestore (PH2a seam).
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;



  String _searchQuery = '';
  String _statusFilter = 'All';
  String _overdueRangeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Which debtor (by clientId) is shown in the details panel.
  String? _selectedClientId;
  String? _facilityId;
  double? _paidThisMonth;
  bool _isPaidThisMonthLoading = false;

  Timer? _searchDebounce;
  // Periodically checks (never a live listener) whether new debtors
  // have appeared since this browsing session's snapshot moment.
  Timer? _newRecordsCheckTimer;

  // Facility-wide totals for the metrics row - loaded once via real
  // aggregate queries (see ClientProvider.fetchDebtorsMetrics), not
  // recomputed from whichever page happens to be loaded.
  ({int totalDebtors, double totalOwed, int overdueDebtors})? _metrics;
  bool _isMetricsLoading = false;

  // Lazy-loaded, per-client cache of debtor notes - only fetched once
  // a given debtor's details panel is actually opened, then cached.
  // Cleared for a client whenever a new note is added, so the panel
  // picks up the fresh list on the next read.
  final Map<String, Future<List<Map<String, dynamic>>>> _notesFutureByClient = {};

  // Debt itself has no invoice/receipt number - only a saleId or
  // serviceId reference. Lazy-loaded and cached per debt id, since
  // this needs its own fetch of the original sale/service document.
  final Map<String, Future<int?>> _receiptNumberFutureByDebt = {};

  // This client's own real, individual unpaid debt records - loaded
  // only once their details panel is opened, and only ever this one
  // client's debts (a small, targeted query), never the whole
  // facility's. Powers the exact overdue amount shown there, computed
  // from each debt's own timestamp rather than approximated from the
  // client-level balance/oldestUnpaidDebtDate summary fields.
  String? _detailsDebtsClientId;
  Future<List<Debt>>? _detailsDebtsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';

    if (facilityId.isNotEmpty && facilityId != _facilityId) {
      _facilityId = facilityId;
      _loadPaidThisMonth();
      _loadMetrics();
      _openDebtorsListSession();
      _newRecordsCheckTimer ??= Timer.periodic(
        AppTimeouts.newRecordsPoll,
        (_) => Provider.of<ClientProvider>(context, listen: false).debtorsListController.checkForNewRecords(),
      );
    }
  }

  /// Records the toolbar's current filters onto ClientProvider, then
  /// (re)opens the browsing session for them - a no-op if the
  /// signature hasn't actually changed and a session's already open.
  void _openDebtorsListSession({bool forceRefresh = false}) {
    final facilityId = _facilityId;
    if (facilityId == null) return;
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;
    final signature = provider.updateDebtorsListFilters(
      facilityId: facilityId,
      searchTerm: _searchQuery,
      statusFilter: _statusFilter,
      overdueRangeFilter: _overdueRangeFilter,
      overdueDays: overdueDays,
    );
    provider.debtorsListController.openSession(signature, forceRefresh: forceRefresh);
  }

  Future<void> _loadMetrics() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;
    setState(() => _isMetricsLoading = true);
    try {
      final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;
      final metrics = await Provider.of<ClientProvider>(context, listen: false)
          .fetchDebtorsMetrics(facilityId, overdueDays: overdueDays);
      if (mounted) setState(() => _metrics = metrics);
    } catch (e) {
      debugPrint('Error loading debtors metrics: $e');
    } finally {
      if (mounted) setState(() => _isMetricsLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _newRecordsCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaidThisMonth() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isPaidThisMonthLoading = true);
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snap = await _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.payments)
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
    final clientProvider = Provider.of<ClientProvider>(context);
    final overdueDays = Provider.of<FacilityProvider>(context).debtOverdueDays;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: ListenableBuilder(
        listenable: clientProvider.debtorsListController,
        builder: (context, _) {
                final controller = clientProvider.debtorsListController;
                final debtors = controller.items.map((c) => _DebtorRow(c, overdueDays)).toList();

                _DebtorRow? selectedDebtor;
                if (_selectedClientId != null) {
                  for (final d in debtors) {
                    if (d.clientId == _selectedClientId) {
                      selectedDebtor = d;
                      break;
                    }
                  }
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
                            child: _buildMetricsRow(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                            child: _buildFiltersToolbar(),
                          ),
                          if (controller.newRecordsAvailable > 0)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                              child: Row(
                                children: [
                                  Icon(Icons.fiber_new, size: AppIconSize.i18, color: context.colors.primary),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Text(
                                      context.l10n.debtors_newRecords(controller.newRecordsAvailable),
                                      style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.primary),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => controller.refreshSession(),
                                    child: Text(context.l10n.common_refresh),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: controller.error != null && debtors.isEmpty
                                ? Center(child: FirestoreErrorView(error: controller.error))
                                : controller.isLoading && debtors.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : debtors.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.people_outline, size: AppIconSize.i64, color: context.colors.textDisabled),
                                            const SizedBox(height: AppSpacing.s16),
                                            Text(
                                              _searchQuery.isEmpty
                                                  ? context.l10n.debtors_emptyNone
                                                  : context.l10n.debtors_emptySearch,
                                              style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _buildDebtorsTable(debtors),
                          ),
                          _buildPaginationBar(controller),
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
                );
        },
      ),
    );
  }

  // ==================== METRICS ROW ====================

  Widget _buildMetricsRow() {
    final isPaidLoading = _paidThisMonth == null && _isPaidThisMonthLoading;
    final facilityMetrics = _metrics;
    final isMetricsLoading = facilityMetrics == null && _isMetricsLoading;
    final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;

    final metrics = [
      (
        context.l10n.debtors_totalDebtors,
        isMetricsLoading ? '' : '${facilityMetrics?.totalDebtors ?? 0}',
        Icons.people_outline,
        context.colors.primary,
        context.l10n.debtors_withBalance,
        isMetricsLoading,
      ),
      (
        context.l10n.debtors_totalOwed,
        isMetricsLoading ? '' : Money.format(facilityMetrics?.totalOwed ?? 0),
        Icons.account_balance_wallet_outlined,
        context.colors.warning,
        context.l10n.debtors_outstandingBalance,
        isMetricsLoading,
      ),
      (
        context.l10n.debtors_overdueDebtors,
        isMetricsLoading ? '' : '${facilityMetrics?.overdueDebtors ?? 0}',
        Icons.error_outline,
        context.colors.danger,
        context.l10n.debtors_overDays(overdueDays),
        isMetricsLoading,
      ),
      (
        context.l10n.debtors_paidThisMonth,
        Money.format(_paidThisMonth ?? 0),
        Icons.account_balance_outlined,
        context.colors.success,
        context.l10n.debtors_fromDebtPayments,
        isPaidLoading,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < AppBreakpoints.compact;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 2 : 4,
            mainAxisExtent: 90,
            crossAxisSpacing: AppSpacing.s12,
            mainAxisSpacing: AppSpacing.s12,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
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
                      BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r7)),
                  child: Icon(icon, color: color, size: AppIconSize.i14),
                ),
                const SizedBox(width: AppSpacing.s8),
                isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(value, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16, color: color)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
            Text(subtitle, style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textDisabled)),
          ],
        ),
      ),
    );
  }

  /// All current debtors, fetched fresh - used only by the "Record
  /// Payment" picker in the app bar, which needs to offer every
  /// debtor, not just whichever page the main list has loaded. A
  /// deliberate, infrequent action, so loading everyone once here is
  /// an acceptable trade-off, unlike the main browsing list itself.
  Future<List<Client>> _fetchAllDebtorClients() async {
    final facilityId = _facilityId;
    if (facilityId == null) return [];
    final snap = await _db
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.clients)
        .where('balance', isGreaterThan: 0)
        .get();
    return snap.docs.map((d) => Client.fromMap(d.id, d.data())).toList();
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
          Text(context.l10n.debtors_title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text(context.l10n.debtors_subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () async {
              final debtorClients = await _fetchAllDebtorClients();
              if (!mounted) return;
              final debtorBalances = {for (final c in debtorClients) c.id: c.balance};
              final result = await showAddPaymentScreen(
                context,
                facilityId: _facilityId,
                debtorClients: debtorClients,
                debtorBalances: debtorBalances,
              );
              if (result == true && _facilityId != null && mounted) {
                Provider.of<ClientProvider>(context, listen: false)
                    .debtorsListController
                    .refreshSession();
                _loadMetrics();
              }
            },
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: Text(context.l10n.debtors_recordPayment),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== FILTERS TOOLBAR ====================

  static const List<String> _statusFilterOptions = ['All', 'Overdue', 'Current'];
  // Stable keys - never shown directly. bucket1 = 1x the facility's
  // threshold past due, bucket2 = 1x-2x past due, bucket3 = beyond 2x.
  static const List<String> _overdueRangeOptions = ['All', 'bucket1', 'bucket2', 'bucket3'];

  /// The dropdown's actual displayed text for a given key, computed
  /// from the facility's own configured threshold - e.g. with a
  /// 30-day threshold, bucket1 reads "1-30 days overdue"; with a
  /// 60-day threshold, the same key reads "1-60 days overdue".
  String _overdueRangeLabel(String key, int overdueDays) {
    switch (key) {
      case 'bucket1':
        return context.l10n.debtors_rangeDays(1, overdueDays);
      case 'bucket2':
        return context.l10n.debtors_rangeDays(overdueDays + 1, overdueDays * 2);
      case 'bucket3':
        return context.l10n.debtors_rangeDaysPlus(overdueDays * 2 + 1);
      default:
        return context.l10n.common_all;
    }
  }

  // The status filter's values stay English (ClientProvider compares
  // them); this is what each one shows.
  String _statusFilterLabel(String value) => switch (value) {
        'Overdue' => context.l10n.debtors_overdue,
        'Current' => context.l10n.debtors_current,
        _ => context.l10n.common_all,
      };

  Widget _buildFiltersToolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    final hasActiveFilters = _searchQuery.isNotEmpty || _statusFilter != 'All' || _overdueRangeFilter != 'All';
    final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.debtors_searchHint,
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
                        _openDebtorsListSession();
                      },
                    ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
              _searchDebounce?.cancel();
              _searchDebounce = Timer(AppTimeouts.searchDebounce, _openDebtorsListSession);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        _toolbarDropdown<String>(
          value: _statusFilter,
          items: _statusFilterOptions,
          label: context.l10n.common_status,
          display: _statusFilterLabel,
          onChanged: (val) {
            setState(() => _statusFilter = val);
            _openDebtorsListSession();
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
            child: DropdownButton<String>(
              value: _overdueRangeFilter,
              icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
              style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
              items: _overdueRangeOptions
                  .map((key) => DropdownMenuItem(
                        value: key,
                        child: Text(context.l10n.common_filterValue(context.l10n.debtors_colOverdue, _overdueRangeLabel(key, overdueDays))),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _overdueRangeFilter = val);
                _openDebtorsListSession();
              },
            ),
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: AppSpacing.s10),
          TextButton(
            onPressed: () {
              _searchDebounce?.cancel();
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _statusFilter = 'All';
                _overdueRangeFilter = 'All';
              });
              _openDebtorsListSession();
            },
            child: Text(context.l10n.common_reset),
          ),
        ],
        const SizedBox(width: AppSpacing.s10),
        OutlinedButton.icon(
          onPressed: () => _exportDebtors(),
          icon: const Icon(Icons.download_outlined, size: AppIconSize.i16),
          label: Text(context.l10n.common_export),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
        ),
      ],
    );
  }

  Widget _toolbarDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    // What an item shows; the dropdown keeps the item itself as its value.
    required String Function(T value) display,
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
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(context.l10n.common_filterValue(label, display(v))))).toList(),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
          child: Row(
            children: [
              _headerCell(context.l10n.debtors_debtor, flex: 3),
              _headerCell(context.l10n.debtors_totalOwed, flex: 2),
              _headerCell(context.l10n.debtors_colOverdue, flex: 2),
              _headerCell(context.l10n.debtors_oldestDebtSince, flex: 2),
              _headerCell(context.l10n.common_status, flex: 2),
              _headerCell(context.l10n.common_actions, flex: 2),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: debtors.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
            itemBuilder: (context, index) => _buildDebtorRow(debtors[index]),
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

  Widget _buildDebtorRow(_DebtorRow debtor) {
    final isSelected = _selectedClientId == debtor.clientId;
    final isOverdue = debtor.isOverdue;

    return InkWell(
      onTap: () => setState(() => _selectedClientId = debtor.clientId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
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
                    backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a15),
                    child: Text(
                      debtor.clientName.isNotEmpty ? debtor.clientName[0].toUpperCase() : '?',
                      style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debtor.clientName, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (debtor.clientPhone.isNotEmpty)
                          Text(debtor.clientPhone, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(Money.format(debtor.totalOwed),
                  style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.danger)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                isOverdue ? context.l10n.debtors_daysCount(debtor.daysSinceOldestDebt) : '\u2014',
                style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: isOverdue ? context.colors.danger : context.colors.textMuted),
              ),
            ),
            Expanded(
              flex: 2,
              child: debtor.client.oldestUnpaidDebtDate != null
                  ? Text(
                      AppDateFormat.date.format(debtor.client.oldestUnpaidDebtDate!),
                      style: const TextStyle(fontSize: AppFontSize.f13),
                    )
                  : Text('—', style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint)),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: (isOverdue ? context.colors.danger : context.colors.success).withValues(alpha: AppAlpha.a10),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                ),
                child: Text(isOverdue ? context.l10n.debtors_overdue : context.l10n.debtors_current,
                    style: TextStyle(color: isOverdue ? context.colors.danger : context.colors.success, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_active_outlined, size: AppIconSize.i18, color: context.colors.warningStrong),
                    tooltip: context.l10n.debtors_sendReminder,
                    onPressed: debtor.clientPhone.isEmpty
                        ? null
                        : () => _showReminderOptions(context, debtor.clientName, debtor.clientPhone, debtor.totalOwed),
                  ),
                  IconButton(
                    icon: Icon(Icons.history, size: AppIconSize.i18, color: context.colors.primary),
                    tooltip: context.l10n.debtors_paymentHistory,
                    onPressed: () => _openPaymentHistory(debtor),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: AppIconSize.i18, color: context.colors.textMuted),
                    onSelected: (value) {
                      if (value == 'view') setState(() => _selectedClientId = debtor.clientId);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'view', child: Text(context.l10n.common_viewDetails)),
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

  Widget _buildPaginationBar(CursorPaginatedListController<Client> controller) {
    final pageSize = controller.pageSize;
    final itemCount = controller.items.length;
    final pageStart = itemCount == 0 ? 0 : (controller.currentPage - 1) * pageSize + 1;
    final pageEnd = (controller.currentPage - 1) * pageSize + itemCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            itemCount == 0 ? context.l10n.debtors_none : context.l10n.common_showingRange(pageStart, pageEnd),
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text(context.l10n.common_perPage(n))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) controller.setPageSize(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.hasPreviousPage ? () => controller.goToPreviousPage() : null,
              ),
              Text(context.l10n.common_page(controller.currentPage), style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: controller.isLoading
                    ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed:
                    controller.hasNextPage && !controller.isLoading ? () => controller.goToNextPage() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DEBTOR DETAILS PANEL ====================

  Future<List<Debt>> _getDetailsDebtsFuture(String clientId) {
    if (_detailsDebtsClientId != clientId || _detailsDebtsFuture == null) {
      _detailsDebtsClientId = clientId;
      final facilityId = _facilityId;
      _detailsDebtsFuture = facilityId == null
          ? Future.value(<Debt>[])
          : _db
              .collection(Collections.facilities)
              .doc(facilityId)
              .collection(Collections.debts)
              .where('clientId', isEqualTo: clientId)
              .orderBy('timestamp', descending: true)
              .get()
              .then((snap) => snap.docs.map((d) => Debt.fromMap(d.id, d.data())).toList());
    }
    return _detailsDebtsFuture!;
  }

  /// Called after recording a payment against a debtor whose panel is
  /// currently open, so it re-fetches fresh debt records instead of
  /// showing what's now stale.
  void _refreshDetailsDebts(String clientId) {
    if (_detailsDebtsClientId == clientId) {
      setState(() {
        _detailsDebtsClientId = null;
        _detailsDebtsFuture = null;
      });
    }
  }

  Widget _buildDebtorDetailsPanel(_DebtorRow debtor) {
    final isOverdue = debtor.isOverdue;

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
                Text(context.l10n.debtors_detailsTitle, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i20),
                  onPressed: () => setState(() => _selectedClientId = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a15),
                  child: Text(
                    debtor.clientName.isNotEmpty ? debtor.clientName[0].toUpperCase() : '?',
                    style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debtor.clientName, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                      if (debtor.clientPhone.isNotEmpty)
                        Text(debtor.clientPhone, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: (isOverdue ? context.colors.danger : context.colors.success).withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                  ),
                  child: Text(isOverdue ? context.l10n.debtors_overdue : context.l10n.debtors_current,
                      style: TextStyle(color: isOverdue ? context.colors.danger : context.colors.success, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: debtor.clientPhone.isEmpty
                        ? null
                        : () => _showReminderOptions(context, debtor.clientName, debtor.clientPhone, debtor.totalOwed),
                    icon: const Icon(Icons.send_outlined, size: AppIconSize.i16),
                    label: Text(context.l10n.debtors_sendReminder, style: const TextStyle(fontSize: AppFontSize.f12_5)),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPaymentHistory(debtor),
                    icon: const Icon(Icons.history, size: AppIconSize.i16),
                    label: Text(context.l10n.debtors_paymentHistory, style: const TextStyle(fontSize: AppFontSize.f12_5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),
            Text(context.l10n.common_summary, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
            const SizedBox(height: AppSpacing.s10),
            _totalsRow(context.l10n.debtors_totalOwed, Money.format(debtor.totalOwed), color: context.colors.danger),
            FutureBuilder<List<Debt>>(
              future: _getDetailsDebtsFuture(debtor.clientId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: FirestoreErrorView(error: snapshot.error),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final clientDebts = [...snapshot.data!]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final now = DateTime.now();
                final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;
                final overdueAmount = clientDebts
                    .where((d) => now.difference(d.timestamp).inDays > overdueDays)
                    .fold<double>(0, (total, d) => total + d.amountOwed);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _totalsRow(context.l10n.debtors_overdueAmount, Money.format(overdueAmount), color: context.colors.danger),
                    if (clientDebts.isNotEmpty)
                      _totalsRow(context.l10n.debtors_lastTransaction, AppDateFormat.date.format(clientDebts.first.timestamp)),
                    const SizedBox(height: AppSpacing.s20),
                    Text(context.l10n.debtors_outstandingDebts(clientDebts.length),
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                    const SizedBox(height: AppSpacing.s10),
                    ...clientDebts.map((debt) => _buildDebtTile(debtor, debt)),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.common_notes, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                TextButton.icon(
                  onPressed: () => _addNote(debtor),
                  icon: const Icon(Icons.add, size: AppIconSize.i16),
                  label: Text(context.l10n.debtors_addNote),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getNotesFuture(debtor.clientId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                    child: Text(context.l10n.common_noNotes, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
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
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note['text'] as String? ?? '', style: const TextStyle(fontSize: AppFontSize.f13)),
                          if (ts != null)
                            Text(AppDateFormat.dateTime12.format(ts.toDate()),
                                style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s20),
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
                  totalOwed: debtor.totalOwed,
                );
                if (result == true && _facilityId != null && mounted) {
                  Provider.of<ClientProvider>(context, listen: false)
                      .debtorsListController
                      .refreshSession();
                  _refreshDetailsDebts(debtor.clientId);
                  _loadMetrics();
                }
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, size: AppIconSize.i16),
              label: Text(context.l10n.debtors_recordPayment),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.background,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtTile(_DebtorRow debtor, Debt debt) {
    final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;
    final isOverdue = DateTime.now().difference(debt.timestamp).inDays > overdueDays;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
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
              Expanded(
                child: FutureBuilder<int?>(
                  future: _getReceiptNumberFuture(debt),
                  builder: (context, snapshot) {
                    final receiptNumber = snapshot.data;
                    final invoiceText = receiptNumber != null
                        ? '${_debtInvoicePrefix(debt)}-${receiptNumber.toString().padLeft(6, '0')}'
                        : '${_debtInvoicePrefix(debt)}-......';
                    return Text(
                      context.l10n.debtors_invoiceLine(invoiceText, AppDateFormat.date.format(debt.timestamp)),
                      style: const TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold),
                    );
                  },
                ),
              ),
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(color: context.colors.danger.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
                  child: Text(context.l10n.debtors_overdue, style: TextStyle(color: context.colors.danger, fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(_debtDescription(debt), style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.common_amount, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
                  Text(Money.format(debt.amountOwed),
                      style: TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.bold, color: context.colors.danger)),
                ],
              ),
              ElevatedButton(
                onPressed: () => _payDebt(debtor, debt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.background,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s10),
                ),
                child: Text(context.l10n.debtors_pay),
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
      Provider.of<ClientProvider>(context, listen: false).debtorsListController.refreshSession();
      _refreshDetailsDebts(debtor.clientId);
      _loadMetrics();
    }
  }

  Future<int?> _getReceiptNumberFuture(Debt debt) {
    return _receiptNumberFutureByDebt.putIfAbsent(debt.id, () async {
      final facilityId = _facilityId;
      if (facilityId == null) return null;
      try {
        if (debt.source == 'Sale' && debt.saleId != null) {
          final doc = await _db
              .collection(Collections.facilities)
              .doc(facilityId)
              .collection(Collections.sales)
              .doc(debt.saleId)
              .get();
          return (doc.data()?['receiptNumber'] as num?)?.toInt();
        } else if (debt.source == 'Service' && debt.serviceId != null) {
          final doc = await _db
              .collection(Collections.facilities)
              .doc(facilityId)
              .collection(Collections.services)
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
    if (debt.items.isEmpty) return context.l10n.debtSourceLabel(debt.source);
    if (debt.source == 'Service') {
      final item = debt.items.first;
      if (item is Map) {
        final name = item['serviceName'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
      return context.l10n.debtSourceLabel(debt.source);
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
    return parts.isEmpty ? context.l10n.debtSourceLabel(debt.source) : parts.join(', ');
  }

  Future<List<Map<String, dynamic>>> _getNotesFuture(String clientId) {
    return _notesFutureByClient.putIfAbsent(clientId, () async {
      final facilityId = _facilityId;
      if (facilityId == null) return [];
      final doc = await _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.clients)
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

  Future<void> _exportDebtors() async {
    final clients = await _fetchAllDebtorClients();
    if (!mounted) return;
    final overdueDays = Provider.of<FacilityProvider>(context, listen: false).debtOverdueDays;
    final debtors = clients.map((c) => _DebtorRow(c, overdueDays)).toList()
      ..sort((a, b) => b.totalOwed.compareTo(a.totalOwed));

    final rows = <List<String>>[
      ['Debtor', 'Phone', 'Total Owed', 'Days Overdue', 'Oldest Debt Since', 'Status'],
      for (final d in debtors)
        [
          d.clientName,
          d.clientPhone,
          d.totalOwed.toStringAsFixed(0),
          d.isOverdue ? '${d.daysSinceOldestDebt}' : '',
          d.client.oldestUnpaidDebtDate != null
              ? AppDateFormat.date.format(d.client.oldestUnpaidDebtDate!)
              : '',
          d.isOverdue ? 'Overdue' : 'Current',
        ],
    ];

    final csvString = rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
    final bytes = Uint8List.fromList(utf8.encode(csvString));

    try {
      final xfile = XFile.fromData(
        bytes,
        name: 'active_debts_${DateFormat(DataKeys.fileDateStamp).format(DateTime.now())}.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], text: ExportTexts.activeDebtsShareText);
    } catch (e, st) {
      AppFeedback.error(L10n.current.debtors_exportFailed, error: e, stackTrace: st);
    }
  }

  Future<void> _addNote(_DebtorRow debtor) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.debtors_addNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [SentenceCapitalizationFormatter()],
          decoration: InputDecoration(hintText: context.l10n.debtors_noteHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    final facilityId = _facilityId;
    if (facilityId == null) return;

    try {
      await _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.clients)
          .doc(debtor.clientId)
          .set({
        'debtorNotes': FieldValue.arrayUnion([
          {'text': text, 'timestamp': Timestamp.now()},
        ]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _notesFutureByClient.remove(debtor.clientId));
    } catch (e, st) {
      AppFeedback.error(L10n.current.debtors_noteSaveFailed, error: e, stackTrace: st);
    }
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

  /// One-tap reminder, not automated bulk sending - opens WhatsApp or
  /// SMS with a pre-filled message ready to review and send. There's no
  /// backend here to send these on a schedule; this is a daily-follow-up
  /// convenience, one debtor at a time.
  Future<void> _showReminderOptions(
      BuildContext context, String clientName, String phone, double amountOwed) async {
    final facilityName =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityName ?? 'us';
    // Sent to the debtor, not shown in the app: left in English, not in
    // the language files, until the owner decides its language (2F-5).
    final message =
        'Hi $clientName, this is a reminder from $facilityName that you have an outstanding '
        'balance of ${Money.format(amountOwed)}. Kindly settle at your earliest '
        'convenience. Thank you!';

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.debtors_sendReminder),
        content: Text(context.l10n.debtors_reminderBody(clientName, Money.format(amountOwed))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text(context.l10n.common_cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, 'sms'),
            child: Text(context.l10n.debtors_viaSms),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'whatsapp'),
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.success, foregroundColor: context.colors.onPrimary),
            child: Text(context.l10n.debtors_viaWhatsApp),
          ),
        ],
      ),
    );

    if (choice == null) return;

    final uri = choice == 'whatsapp'
        ? AppLinks.whatsApp(phone, text: message)
        : AppLinks.sms(phone, body: message);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        AppFeedback.info(choice == 'whatsapp' ? L10n.current.debtors_whatsAppFailed : L10n.current.debtors_messagesFailed);
      }
    } catch (e, st) {
      AppFeedback.error(L10n.current.debtors_reminderFailed, error: e, stackTrace: st);
    }
  }
}

class _DebtorRow {
  final Client client;
  final int overdueDays;

  _DebtorRow(this.client, this.overdueDays);

  String get clientId => client.id;
  String get clientName => client.name.isNotEmpty ? client.name : 'Unknown';
  String get clientPhone => client.phone;
  double get totalOwed => client.balance;

  int get daysSinceOldestDebt {
    final oldest = client.oldestUnpaidDebtDate;
    if (oldest == null) return 0;
    return DateTime.now().difference(oldest).inDays;
  }

  bool get isOverdue => daysSinceOldestDebt > overdueDays;
}
