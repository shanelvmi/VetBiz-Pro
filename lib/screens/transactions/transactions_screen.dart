import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/transaction.dart';
import '../../services/dashboard_summary_service.dart';
import '../../widgets/date_range_dialog.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/payment_method_selector.dart';
import 'add_transaction_screen.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  static const Color offWhite = Color(0xFFFDFDF9);

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  String? _filterType; // null = no filter, else 'other income' or 'expense'

  String _searchQuery = '';
  bool _isSearchExpanded = false;
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
  bool _isSummaryLoading = false;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = now.subtract(const Duration(days: 30));
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
        primaryDeepGreen: TransactionScreen.primaryDeepGreen,
        warmAmber: TransactionScreen.warmAmber,
        offWhite: TransactionScreen.offWhite,
      ),
    );

    if (result == null) return;

    setState(() {
      _rangeStart = result['start']!;
      _rangeEnd = result['end']!;
    });

    await _loadPeriodTotals();
  }

  Future<void> _loadPeriodTotals() async {
    final facilityId = _facilityId;
    if (facilityId == null) return;

    setState(() => _isSummaryLoading = true);

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
    final formatter = NumberFormat.decimalPattern();

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
      backgroundColor: TransactionScreen.offWhite,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Range display - the cards below always reflect exactly this
          // period, whatever it's set to (defaults to Last 30 Days).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${DateFormat('dd MMM yyyy').format(_rangeStart)} - ${DateFormat('dd MMM yyyy').format(_rangeEnd)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryCard(
                  label: 'Other Income',
                  amount: _otherIncomeTotal,
                  color: TransactionScreen.warmAmber,
                  isSelected: _filterType == 'other income',
                  isLoading: _isSummaryLoading,
                  onTap: () {
                    setState(() {
                      _filterType = _filterType == 'other income' ? null : 'other income';
                    });
                  },
                  formatter: formatter,
                ),
                _SummaryCard(
                  label: 'Expenses',
                  amount: _expensesTotal,
                  color: Colors.red[400]!,
                  isSelected: _filterType == 'expense',
                  isLoading: _isSummaryLoading,
                  onTap: () {
                    setState(() {
                      _filterType = _filterType == 'expense' ? null : 'expense';
                    });
                  },
                  formatter: formatter,
                ),
                _SummaryCard(
                  label: 'Sub Profit',
                  amount: subProfit,
                  color: subProfit >= 0 ? Colors.green : Colors.red,
                  isSelected: false,
                  isLoading: _isSummaryLoading,
                  onTap: () {}, // No filtering on sub profit
                  formatter: formatter,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_filterType != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filter'),
                    onPressed: () => setState(() => _filterType = null),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '${filteredTransactions.length} transaction${filteredTransactions.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions${_filterType != null ? ' for ${toTitleCase(_filterType!)}' : ''}.',
                      style: const TextStyle(
                          fontSize: 16, color: TransactionScreen.primaryDeepGreen),
                    ),
                  )
                : _buildTransactionsGrid(filteredTransactions, transactionProvider, formatter),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TransactionScreen.primaryDeepGreen,
        foregroundColor: TransactionScreen.offWhite,
        hoverColor: TransactionScreen.warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        onPressed: () {
          showAddTransactionScreen(context);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: TransactionScreen.primaryDeepGreen,
      foregroundColor: TransactionScreen.offWhite,
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: TransactionScreen.offWhite,
              style: const TextStyle(color: TransactionScreen.offWhite),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(
                    color: TransactionScreen.offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: TransactionScreen.offWhite),
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
          : const Text('Transactions'),
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
                foregroundColor: TransactionScreen.offWhite,
                backgroundColor: TransactionScreen.offWhite.withValues(alpha: 0.15),
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

  Widget _buildTransactionsGrid(List<TransactionModel> transactions,
      TransactionProvider transactionProvider, NumberFormat formatter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;
        final itemCount = transactions.length + 1;

        Widget itemBuilder(BuildContext context, int index) {
          if (index == transactions.length) {
            return _buildLoadMoreFooter(transactionProvider);
          }
          return _buildTransactionCard(transactions[index], transactionProvider, formatter);
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

  Widget _buildTransactionCard(TransactionModel tx,
      TransactionProvider transactionProvider, NumberFormat formatter) {
    final isIncome = tx.type.toLowerCase() == 'other income';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TransactionScreen.offWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isIncome ? TransactionScreen.warmAmber : Colors.redAccent,
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: TransactionScreen.offWhite,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${toTitleCase(tx.type)}: Tsh ${formatter.format(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIncome
                          ? TransactionScreen.primaryDeepGreen
                          : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Description: ${tx.description}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Category: ${tx.category.isEmpty ? 'N/A' : tx.category}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Date: ${tx.date.toLocal().toString().split('.')[0]}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Recorded By: ${tx.recordedBy.isEmpty ? 'Unknown' : tx.recordedBy}',
                style: const TextStyle(fontSize: 13)),
            if (tx.paymentMethod != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Payment Method: ', style: TextStyle(fontSize: 13)),
                  Icon(iconForPaymentMethod(tx.paymentMethod!), size: 14, color: Colors.grey[700]),
                  const SizedBox(width: 3),
                  Text(tx.paymentMethod!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () async {
                    try {
                      await transactionProvider.deleteTransaction(context, tx.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction deleted'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    showAddTransactionScreen(context, transaction: tx);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return TransactionScreen.warmAmber;
                      }
                      return TransactionScreen.primaryDeepGreen;
                    }),
                    foregroundColor: WidgetStateProperty.all(TransactionScreen.offWhite),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final NumberFormat formatter;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.isSelected,
    this.isLoading = false,
    required this.onTap,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    // Unselected: a quiet, light tint with a colored border and colored
    // text - the card reads as "available to tap" without shouting.
    // Selected: a solid, full-strength fill with white text, a shadow
    // lifting it off the page, and a checkmark - unmistakably "this is
    // the active filter", not just a slightly darker version of the same
    // tint as before.
    // Unselected: a very light, quiet tint with a thin colored border.
    // Selected: a moderate (not solid/neon) tint, a thicker colored
    // border, and bold checkmark + darker text - separation comes from
    // border weight and a checkmark, not from a jarring full-brightness
    // fill.
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.darken(0.05) : color.withValues(alpha: 0.35),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.check_circle, size: 16, color: color.darken(0.15)),
                ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.darken(0.3),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              if (isLoading)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color.darken(0.3),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Tsh ${formatter.format(amount)}',
                    style: TextStyle(
                      color: color.darken(0.3),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension method to darken a color by [amount] (0 to 1)
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
