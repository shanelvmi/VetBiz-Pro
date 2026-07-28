import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    await transactionProvider.fetchTransactionsFromFirestore(context);
    setState(() => _isLoading = false);
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

    // Compute totals based on all transactions
    final otherIncomeTotal = transactionProvider.transactions
        .where((tx) => tx.type.toLowerCase() == 'other income')
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final expensesTotal = transactionProvider.transactions
        .where((tx) => tx.type.toLowerCase() == 'expense')
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final subProfit = otherIncomeTotal - expensesTotal;

    // Apply filter to transactions if any
    final filteredTransactions = _filterType == null
        ? transactionProvider.transactions
        : transactionProvider.transactions
            .where((tx) => tx.type.toLowerCase() == _filterType)
            .toList();

    return Scaffold(
      backgroundColor: TransactionScreen.offWhite,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: TransactionScreen.primaryDeepGreen,
        foregroundColor: TransactionScreen.offWhite,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: TransactionScreen.primaryDeepGreen,
              ),
            )
          : Column(
              children: [
                // Summary panel
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SummaryCard(
                        label: 'Other Income',
                        amount: otherIncomeTotal,
                        color: TransactionScreen.warmAmber,
                        isSelected: _filterType == 'other income',
                        onTap: () {
                          setState(() {
                            _filterType = _filterType == 'other income'
                                ? null
                                : 'other income';
                          });
                        },
                        formatter: formatter,
                      ),
                      _SummaryCard(
                        label: 'Expenses',
                        amount: expensesTotal,
                        color: Colors.redAccent,
                        isSelected: _filterType == 'expense',
                        onTap: () {
                          setState(() {
                            _filterType =
                                _filterType == 'expense' ? null : 'expense';
                          });
                        },
                        formatter: formatter,
                      ),
                      _SummaryCard(
                        label: 'Sub Profit',
                        amount: subProfit,
                        color:
                            subProfit >= 0 ? Colors.green : Colors.red,
                        isSelected: false,
                        onTap: () {}, // No filtering on sub profit
                        formatter: formatter,
                      ),
                    ],
                  ),
                ),

                if (_filterType != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Filter'),
                      onPressed: () {
                        setState(() {
                          _filterType = null;
                        });
                      },
                    ),
                  ),

                Expanded(
                  child: filteredTransactions.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions${_filterType != null ? ' for ${toTitleCase(_filterType!)}' : ''}.',
                            style: const TextStyle(
                                fontSize: 16,
                                color: TransactionScreen.primaryDeepGreen),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = filteredTransactions[index];
                            final isIncome =
                                tx.type.toLowerCase() == 'other income';

                            return Card(
                              elevation: 2,
                              margin:
                                  const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: isIncome
                                      ? TransactionScreen.warmAmber
                                      : Colors.redAccent,
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: TransactionScreen.offWhite,
                                  ),
                                ),
                                title: Text(
                                  '${toTitleCase(tx.type)}: Tsh ${formatter.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome
                                        ? TransactionScreen.primaryDeepGreen
                                        : Colors.redAccent,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Description: ${tx.description}'),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Category: ${tx.category.isEmpty ? 'N/A' : tx.category}'),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Date: ${tx.date.toLocal().toString().split('.')[0]}'),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Recorded By: ${tx.recordedBy.isEmpty ? 'Unknown' : tx.recordedBy}'),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            tooltip: 'Delete transaction',
                                            onPressed: () {
                                              transactionProvider
                                                  .deleteTransaction(
                                                      context, tx.id);
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: TransactionScreen.warmAmber,
        foregroundColor: Colors.black,
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final NumberFormat formatter;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color:
              isSelected ? color.withValues(alpha: 0.7) : color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : color.darken(0.3),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tsh ${formatter.format(amount)}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : color.darken(0.3),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
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
