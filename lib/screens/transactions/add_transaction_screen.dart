import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting

import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/thousands_input_formatter.dart';

// Expense categories, grouped for the picker - matches the proposed
// structure exactly. Kept local to this file rather than centralized,
// since these are specific to transaction categorization only.
const Map<String, List<String>> kExpenseCategoryGroups = {
  'Administration': ['Meals & Refreshments', 'Salaries & Wages', 'Office Supplies'],
  'Premises & Utilities': ['Electricity', 'Water', 'Rent'],
  'Operations': ['Drugs & Medicines', 'Vaccines', 'Veterinary Supplies'],
  'Transport': ['Fuel', 'Vehicle Maintenance'],
  'Business': ['Marketing', 'Licences & Registration'],
  'Other': ['Miscellaneous'],
};

// Income categories - flat, no grouping needed for this shorter list.
const List<String> kIncomeCategories = [
  'Commission Income',
  'Delivery Income',
  'Training Income',
  'Consultancy Income',
  'Rental Income',
  'Interest Income',
  'Refunds Received',
  'Discounts Received',
  'Asset Disposal Income',
  'Other Income',
];

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final bool isModal;

  const AddTransactionScreen({super.key, this.transaction, this.isModal = false});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool _isSaving = false;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String? selectedCategory;
  String? type = 'other income';
  String? paymentMethod;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final AuthService _authService = AuthService();

  final formatter = NumberFormat('#,##0', 'en_US');

  Future<String?> _fetchCurrentUserFullName() async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return data['fullName'] as String?;
  }

  void _saveTransaction(BuildContext context) async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once

    final description = descriptionController.text.trim();

    // Remove commas to parse
    final amount = parseThousands(amountController.text);
    final category = selectedCategory ?? '';
    final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

    if (description.isEmpty || amount <= 0 || type == null || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    if (paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select how this transaction was paid')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    if (widget.transaction != null) {
      // Editing - keep the original id, date, and who recorded it; only
      // the fields the user can actually change here get updated. Built
      // directly rather than via copyWith, since copyWith's standard
      // null-coalescing can't actually clear paymentMethod back to null
      // when switching from other income to expense - it would just
      // silently keep the stale value instead.
      final updated = TransactionModel(
        id: widget.transaction!.id,
        date: widget.transaction!.date,
        description: description,
        amount: amount,
        type: type!,
        category: category,
        recordedBy: widget.transaction!.recordedBy,
        paymentMethod: paymentMethod,
        note: note,
      );
      try {
        await provider.updateTransaction(updated, context);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e'), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    String? userName = await _fetchCurrentUserFullName();
    if (userName == null || userName.isEmpty) {
      userName = 'Unknown User';
    }

    final newTx = TransactionModel(
      id: '',
      date: DateTime.now(),
      description: description,
      amount: amount,
      type: type!, // stored lowercase
      category: category,
      recordedBy: userName,
      paymentMethod: paymentMethod,
      note: note,
    );

    try {
      await provider.addTransaction(newTx, context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save transaction: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      final tx = widget.transaction!;
      type = tx.type;
      descriptionController.text = tx.description;
      selectedCategory = tx.category.isEmpty ? null : tx.category;
      amountController.text = formatter.format(tx.amount.round());
      paymentMethod = tx.paymentMethod;
      noteController.text = tx.note ?? '';
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;

    return Scaffold(
      backgroundColor: offWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: primaryDeepGreen,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isEditing ? 'Edit Transaction' : 'Record Transaction',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const BackButton(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= 860;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: isTwoColumn
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildTransactionDetailsCard()),
                            const SizedBox(width: 16),
                            Expanded(flex: 1, child: _buildAmountPaymentCard()),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _buildTransactionDetailsCard(),
                          const SizedBox(height: 16),
                          _buildAmountPaymentCard(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildFooter(isEditing),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDeepGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen)),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
      ),
    );
  }

  // Title case (capitalize each word)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  Widget _buildTransactionDetailsCard() {
    const dropdownOptions = ['other income', 'expense'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.swap_horiz, 'Transaction Details'),
          const SizedBox(height: 14),
          const Text('Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: dropdownOptions.map((val) {
              return DropdownMenuItem(value: val, child: Text(_toTitleCase(val)));
            }).toList(),
            onChanged: (val) => setState(() {
              type = val;
              // A category picked under one type rarely makes sense
              // under the other (an expense category shouldn't
              // silently persist after switching to income) - clear it
              // rather than leave a mismatched selection in place.
              selectedCategory = null;
            }),
            decoration: _fieldDecoration(),
          ),
          const SizedBox(height: 14),
          const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _showCategoryPickerDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCategory ?? 'Select category...',
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedCategory != null ? Colors.black87 : Colors.grey[500],
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: descriptionController,
            decoration: _fieldDecoration(hintText: 'What was this for?'),
          ),
          const SizedBox(height: 14),
          const Text('Reference/Note (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: noteController,
            maxLines: 4,
            minLines: 4,
            decoration: _fieldDecoration(hintText: 'Add any additional information'),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.receipt_long_outlined, 'Amount & Payment'),
          const SizedBox(height: 14),
          const Text('Amount (Tsh) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: _fieldDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryDeepGreen.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card_outlined, size: 16, color: primaryDeepGreen),
                      const SizedBox(width: 8),
                      Text('Payment Method',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryDeepGreen)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PopupMenuButton<String>(
                    initialValue: paymentMethod,
                    onSelected: (method) => setState(() => paymentMethod = method),
                    itemBuilder: (context) => kPaymentMethods.map((method) {
                      return PopupMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(iconForPaymentMethod(method), size: 18, color: primaryDeepGreen),
                            const SizedBox(width: 10),
                            Text(method),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(iconForPaymentMethod(paymentMethod ?? 'Cash'), size: 18, color: primaryDeepGreen),
                          const SizedBox(width: 10),
                          Expanded(child: Text(paymentMethod ?? 'Select method')),
                          Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // The category picker - grouped section headers for expenses
  // (matching the proposed structure), a flat list for income. Same
  // dialog pattern already established for Browse Products elsewhere
  // in this app: a search field plus a scrollable list, rather than a
  // cramped inline dropdown that can't comfortably hold 15+ grouped
  // options.
  Future<void> _showCategoryPickerDialog() async {
    final isExpense = type == 'expense';
    String query = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final lowerQuery = query.trim().toLowerCase();

            Widget content;
            if (isExpense) {
              final filteredGroups = <String, List<String>>{};
              for (final entry in kExpenseCategoryGroups.entries) {
                final matches = entry.value.where((c) => c.toLowerCase().contains(lowerQuery)).toList();
                if (matches.isNotEmpty) filteredGroups[entry.key] = matches;
              }
              content = filteredGroups.isEmpty
                  ? const Center(child: Text('No categories found'))
                  : ListView(
                      children: filteredGroups.entries.expand((entry) {
                        return [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                            child: Text(entry.key,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: primaryDeepGreen)),
                          ),
                          ...entry.value.map((category) => ListTile(
                                dense: true,
                                title: Text(category),
                                trailing: selectedCategory == category
                                    ? Icon(Icons.check, size: 18, color: primaryDeepGreen)
                                    : null,
                                onTap: () {
                                  setState(() => selectedCategory = category);
                                  Navigator.pop(dialogContext);
                                },
                              )),
                        ];
                      }).toList(),
                    );
            } else {
              final filtered = kIncomeCategories.where((c) => c.toLowerCase().contains(lowerQuery)).toList();
              content = filtered.isEmpty
                  ? const Center(child: Text('No categories found'))
                  : ListView(
                      children: filtered
                          .map((category) => ListTile(
                                dense: true,
                                title: Text(category),
                                trailing: selectedCategory == category
                                    ? Icon(Icons.check, size: 18, color: primaryDeepGreen)
                                    : null,
                                onTap: () {
                                  setState(() => selectedCategory = category);
                                  Navigator.pop(dialogContext);
                                },
                              ))
                          .toList(),
                    );
            }

            return AlertDialog(
              title: const Text('Select Category'),
              content: SizedBox(
                width: 420,
                height: 440,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: content),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _saveTransaction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: offWhite,
              disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(isEditing ? 'Update Transaction' : 'Record Transaction'),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The one entry point for opening Add/Edit Transaction - same
/// reasoning and threshold as showAddSaleScreen elsewhere in this app:
/// a full-screen push on mobile, a large, centered, dismissable modal
/// on desktop/tablet-width screens.
Future<void> showAddTransactionScreen(BuildContext context, {TransactionModel? transaction}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: transaction)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: transaction != null ? 'Edit Transaction' : 'Record Transaction',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      final modalHeight = (screenSize.height * 0.88).clamp(0, 820).toDouble();
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              child: AddTransactionScreen(transaction: transaction, isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
