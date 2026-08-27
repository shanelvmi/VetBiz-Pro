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
import '../../widgets/hover_elevate_card.dart';
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
                  icon: Icons.arrow_downward,
                  isSelected: _filterType == 'other income',
                  isLoading: _isSummaryLoading,
                  onTap: () {
                    setState(() {
                      _filterType = _filterType == 'other income' ? null : 'other income';
                    });
                  },
                  formatter: formatter,
                ),
                const SizedBox(width: 10),
                _SummaryCard(
                  label: 'Expenses',
                  amount: _expensesTotal,
                  color: Colors.red[400]!,
                  icon: Icons.arrow_upward,
                  isSelected: _filterType == 'expense',
                  isLoading: _isSummaryLoading,
                  onTap: () {
                    setState(() {
                      _filterType = _filterType == 'expense' ? null : 'expense';
                    });
                  },
                  formatter: formatter,
                ),
                const SizedBox(width: 10),
                _SummaryCard(
                  label: 'Sub Profit',
                  amount: subProfit,
                  color: subProfit >= 0 ? Colors.green : Colors.red,
                  icon: Icons.account_balance_wallet,
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
        label: const Text('Record Transaction'),
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
    final accentColor = isIncome ? TransactionScreen.warmAmber : Colors.redAccent;

    return HoverElevateCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tx.description.isEmpty ? toTitleCase(tx.type) : tx.description,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tsh ${formatter.format(tx.amount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(label: toTitleCase(tx.type)),
                if (tx.category.isNotEmpty) _MetaChip(label: tx.category),
                Text(
                  DateFormat('d MMM yyyy, HH:mm').format(tx.date.toLocal()),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (tx.paymentMethod != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(iconForPaymentMethod(tx.paymentMethod!), size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(tx.paymentMethod!, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                ],
              ),
            ],
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recorded by ${tx.recordedBy.isEmpty ? 'Unknown' : tx.recordedBy}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (Provider.of<UserRoleProvider>(context).isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete this transaction?'),
                              content: Text(
                                '"${tx.description.isEmpty ? toTitleCase(tx.type) : tx.description}" - '
                                'Tsh ${formatter.format(tx.amount)}\n\nThis cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          if (!context.mounted) return;

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
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 19, color: TransactionScreen.primaryDeepGreen),
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        showAddTransactionScreen(context, transaction: tx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, quiet label pill - used for the transaction's type and
/// category, sitting inline with the date rather than each on its own
/// separate labeled line as before.
class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontWeight: FontWeight.w500)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final NumberFormat formatter;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isSelected,
    this.isLoading = false,
    required this.onTap,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    // A white card base with a real shadow and a colored icon, rather
    // than a flat colored-tint box - matches the stat-card language
    // used elsewhere in the app. Selected state adds a colored border
    // and a light tint plus a checkmark, so "this is the active
    // filter" reads clearly against the plain white unselected look.
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color.darken(0.05) : Colors.grey.shade200,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color.darken(0.1)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, size: 14, color: color.darken(0.15)),
                ],
              ),
              const SizedBox(height: 4),
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tsh ${formatter.format(amount)}',
                    style: TextStyle(
                      color: color.darken(0.3),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
