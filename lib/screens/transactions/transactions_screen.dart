import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/transaction.dart';
import '../../services/dashboard_summary_service.dart';
import '../../widgets/date_range_dialog.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/payment_method_selector.dart';
import '../../services/receipt_printer_service.dart';
import '../settings/printer_settings_screen.dart';
import 'add_transaction_screen.dart';
import '../../config/money.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../data/data_keys.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  static const Color primaryDeepGreen = AppPalette.primary;
  static const Color warmAmber = AppPalette.accent;
  static const Color offWhite = AppPalette.background;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  String? _filterType; // null = no filter, else 'other income' or 'expense'

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Period totals for the 3 summary cards - deliberately NOT derived from
  // whatever transactions happen to be paginated/loaded below (same
  // reasoning as the Sales screen's summary). Defaults to Last 30 Days,
  // same as before, but is now a real selectable range - previously the
  // cards silently stayed fixed at 30 days even if the list below showed
  // much older transactions, so the two could quietly disagree.
  final DashboardSummaryService _summaryService = DashboardSummaryService();
  String? _facilityId;
  double _otherIncomeTotal = 0;
  double _expensesTotal = 0;
  // Once true, a refresh keeps showing the last-known totals instead of
  // blanking them out with a loading spinner - only the very first load
  // should look like loading.
  bool _hasLoadedSummaryOnce = false;
  bool _isSummaryLoading = false;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  TransactionModel? _selectedTransaction;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = now.subtract(AppRanges.defaultListRange);
    _rangeEnd = now;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      _facilityId = facilityId;
      // Real-time, paginated listener - previously this screen called a
      // full one-time fetch of the ENTIRE transaction history on every
      // open, bypassing the pagination work entirely.
      Provider.of<TransactionProvider>(context, listen: false)
          .listenToTransactions(facilityId);
      _loadPeriodTotals();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showDateRangeDialog() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => DateRangeDialog(
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
      _hasLoadedSummaryOnce = false;
    });

    await _loadPeriodTotals();
  }

  Future<void> _loadPeriodTotals() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    if (!_hasLoadedSummaryOnce) setState(() => _isSummaryLoading = true);

    try {
      final totals = await _summaryService.getTransactionRangeTotals(
        facilityId: facilityId,
        start: _rangeStart,
        end: _rangeEnd,
      );
      if (mounted) {
        setState(() {
          _otherIncomeTotal = totals['totalOtherIncome'] ?? 0;
          _expensesTotal = totals['totalExpense'] ?? 0;
          _isSummaryLoading = false;
          _hasLoadedSummaryOnce = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading transaction period totals: $e');
      if (mounted) setState(() => _isSummaryLoading = false);
    }
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);

    final subProfit = _otherIncomeTotal - _expensesTotal;

    // Apply filter + search to the (paginated) list shown below the
    // summary cards.
    final filteredTransactions = transactionProvider.transactions.where((tx) {
      final matchesType = _filterType == null || tx.type.toLowerCase() == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          tx.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.recordedBy.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricsRow(subProfit),
                  const SizedBox(height: AppSpacing.s16),
                  _buildToolbarRow(filteredTransactions.length),
                  const SizedBox(height: AppSpacing.s16),
                  Expanded(
                    child: filteredTransactions.isEmpty
                        ? Center(
                            child: Text(
                              'No transactions${_filterType != null ? ' for ${toTitleCase(_filterType!)}' : ''}.',
                              style: TextStyle(fontSize: AppFontSize.f16, color: context.colors.primary),
                            ),
                          )
                        : _buildTransactionsTable(filteredTransactions, transactionProvider),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedTransaction != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _buildDetailsPanel(_selectedTransaction!),
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
          Text('Transactions', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('All income and expense transactions', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s8),
          child: OutlinedButton.icon(
            onPressed: _showDateRangeDialog,
            icon: const Icon(Icons.date_range_outlined, size: AppIconSize.i16),
            label: Text(
              '${AppDateFormat.date.format(_rangeStart)} - ${AppDateFormat.date.format(_rangeEnd)}',
              style: const TextStyle(fontSize: AppFontSize.f12_5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () async {
              await showAddTransactionScreen(context);
              await _loadPeriodTotals();
            },
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: const Text('Record Transaction'),
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

  Widget _buildMetricsRow(double subProfit) {
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _metricCard('Other Income', _otherIncomeTotal, context.colors.accent),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _metricCard('Expenses', _expensesTotal, context.colors.dangerSoft),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _metricCard(
              'Other Income vs Expenses',
              subProfit,
              subProfit >= 0 ? context.colors.successStrong : context.colors.dangerSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, double amount, Color color) {
    final isLoading = _isSummaryLoading;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s6),
                decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
                child: Icon(Icons.account_balance_wallet_outlined, size: AppIconSize.i14, color: color),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          AnimatedSwitcher(
            duration: AppMotion.slow,
            child: isLoading
                ? SizedBox(key: const ValueKey('loading'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Text(
                    Money.symbolDecimal(amount),
                    key: const ValueKey('loaded'),
                    style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarRow(int count) {
    final hasActiveFilter = _filterType != null;
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
              hintText: 'Search by description, category...',
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
                      }),
                    ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
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
              value: _filterType,
              hint: const Text('Type: All', style: TextStyle(fontSize: AppFontSize.f13)),
              icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
              style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Type: All')),
                DropdownMenuItem<String?>(value: 'other income', child: Text('Type: Other Income')),
                DropdownMenuItem<String?>(value: 'expense', child: Text('Type: Expense')),
              ],
              onChanged: (val) => setState(() => _filterType = val),
            ),
          ),
        ),
        if (hasActiveFilter) ...[
          const SizedBox(width: AppSpacing.s8),
          TextButton(
            onPressed: () => setState(() => _filterType = null),
            child: const Text('Clear', style: TextStyle(fontSize: AppFontSize.f13)),
          ),
        ],
        const SizedBox(width: AppSpacing.s16),
        Text('$count transaction${count == 1 ? '' : 's'}', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
      ],
    );
  }

  Widget _buildTransactionsTable(List<TransactionModel> transactions,
      TransactionProvider transactionProvider) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      final key = DateFormat(DataKeys.isoDay).format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
          child: Row(
            children: [
              _headerCell('Date & Time', flex: 3),
              _headerCell('Category', flex: 2),
              _headerCell('Description', flex: 3),
              _headerCell('Method', flex: 2),
              _headerCell('Amount', flex: 2),
              _headerCell('Recorded By', flex: 2),
              _headerCell('', flex: 1),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ...grouped.entries.map((dayEntry) {
                final dayTotal = dayEntry.value.fold<double>(0.0, (sum, tx) => sum + tx.amount);
                return _buildDayGroup(dayEntry.key, dayEntry.value, dayTotal);
              }),
              _buildLoadMoreFooter(transactionProvider),
            ],
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

  Widget _buildDayGroup(String dayKey, List<TransactionModel> transactions, double dayTotal) {
    final date = DateFormat(DataKeys.isoDay).parse(dayKey);
    final isProfit = dayTotal >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: TransactionScreen.primaryDeepGreen.withValues(alpha: 0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppDateFormat.date.format(date),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: TransactionScreen.primaryDeepGreen),
              ),
              Text(
                'Total: ${Money.symbolDecimal(dayTotal)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isProfit ? Colors.green[700] : Colors.red[400],
                ),
              ),
            ],
          ),
        ),
        ...transactions.map((tx) => _buildTransactionRow(tx, transactionProvider: Provider.of<TransactionProvider>(context, listen: false))),
      ],
    );
  }

  Widget _buildTransactionRow(TransactionModel tx, {required TransactionProvider transactionProvider}) {
    final isIncome = tx.type.toLowerCase() == 'other income';
    final accentColor = isIncome ? TransactionScreen.warmAmber : Colors.redAccent;
    final isSelected = _selectedTransaction?.id == tx.id;

    return InkWell(
      onTap: () => setState(() => _selectedTransaction = tx),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? TransactionScreen.primaryDeepGreen.withValues(alpha: 0.06) : null,
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
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: accentColor),
                ),
                const SizedBox(width: 8),
                Text(AppDateFormat.time12.format(tx.date), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: tx.category.isEmpty
                ? const Text('-', style: TextStyle(fontSize: 13))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(tx.category, style: TextStyle(fontSize: 10.5, color: accentColor, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tx.description.isEmpty ? toTitleCase(tx.type) : tx.description,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(tx.paymentMethod ?? '-', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Money.symbolDecimal(tx.amount),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: accentColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(tx.recordedBy.isEmpty ? 'Unknown' : tx.recordedBy, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
              onSelected: (value) async {
                if (value == 'view') {
                  setState(() => _selectedTransaction = tx);
                } else if (value == 'edit') {
                  await showAddTransactionScreen(context, transaction: tx);
                  await _loadPeriodTotals();
                } else if (value == 'delete') {
                  _confirmDeleteTransaction(tx, transactionProvider);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (Provider.of<UserRoleProvider>(context, listen: false).isAdmin)
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red[400]))),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(
      TransactionModel tx, TransactionProvider transactionProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(
          '"${tx.description.isEmpty ? toTitleCase(tx.type) : tx.description}" - '
          '${Money.symbolDecimal(tx.amount)}\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await transactionProvider.deleteTransaction(context, tx.id);
      if (!mounted) return;
      if (_selectedTransaction?.id == tx.id) setState(() => _selectedTransaction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _printTransaction(TransactionModel tx) async {
    setState(() => _isPrinting = true);
    final printerService = ReceiptPrinterService();

    try {
      final connected = await printerService.isConnected;

      if (!connected) {
        if (!mounted) return;
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Printer Connected'),
            content: const Text('Connect a Bluetooth receipt printer in Printer Settings first.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Go to Printer Settings'),
              ),
            ],
          ),
        );
        if (goToSettings == true && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
        }
        return;
      }

      final success = await printerService.printTransactionReceipt(tx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Receipt sent to printer' : 'Printer did not accept the receipt'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Widget _buildDetailsPanel(TransactionModel tx) {
    final isIncome = tx.type.toLowerCase() == 'other income';
    final accentColor = isIncome ? TransactionScreen.warmAmber : Colors.redAccent;
    final reference = tx.receiptNumber != null
        ? '${isIncome ? 'OI' : 'EXP'}-${tx.receiptNumber.toString().padLeft(6, '0')}'
        : null;

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
                const Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedTransaction = null),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(toTitleCase(tx.type), style: TextStyle(fontSize: 11.5, color: accentColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Text(
              Money.symbolDecimal(tx.amount),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: accentColor),
            ),
            const SizedBox(height: 4),
            Text(
              tx.description.isEmpty ? toTitleCase(tx.type) : tx.description,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${AppDateFormat.date.format(tx.date)}, ${AppDateFormat.time12.format(tx.date)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(height: 32),
            if (tx.category.isNotEmpty) ...[
              _detailLabel('Category'),
              Text(tx.category, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
            ],
            if (tx.paymentMethod != null) ...[
              _detailLabel('Payment Method'),
              Row(
                children: [
                  Icon(iconForPaymentMethod(tx.paymentMethod!), size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(tx.paymentMethod!, style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _detailLabel('Recorded By'),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(tx.recordedBy.isEmpty ? 'Unknown' : tx.recordedBy, style: const TextStyle(fontSize: 14)),
              ],
            ),
            if (reference != null) ...[
              const SizedBox(height: 16),
              _detailLabel('Reference'),
              Text(reference, style: const TextStyle(fontSize: 14)),
            ],
            if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _detailLabel('Notes'),
              Text(tx.note!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : () => _printTransaction(tx),
                icon: _isPrinting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TransactionScreen.primaryDeepGreen,
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

  Widget _buildLoadMoreFooter(TransactionProvider transactionProvider) {
    if (transactionProvider.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: TransactionScreen.primaryDeepGreen),
          ),
        ),
      );
    }
    if (!transactionProvider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Showing all recent transactions',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => transactionProvider.loadMoreTransactions(),
          style: OutlinedButton.styleFrom(
            foregroundColor: TransactionScreen.primaryDeepGreen,
            side: const BorderSide(color: TransactionScreen.primaryDeepGreen),
          ),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more transactions'),
        ),
      ),
    );
  }

}
