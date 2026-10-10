import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_defaults.dart';
import '../../config/payment_methods.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/app_feedback.dart';

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
  String? type = 'expense';
  String? paymentMethod;


  final AuthService _authService = AuthService();


  Future<String?> _fetchCurrentUserFullName() async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection(Collections.users).doc(user.uid).get();
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
      AppFeedback.warning('Fill in all required fields correctly');
      return;
    }

    if (paymentMethod == null) {
      AppFeedback.warning('Select how this transaction was paid');
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
        AppFeedback.success('Transaction updated');
        Navigator.pop(context);
      } catch (e, st) {
        AppFeedback.error("Couldn't update the transaction", error: e, stackTrace: st);
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

      AppFeedback.success('Transaction saved');

      Navigator.pop(context);
    } catch (e, st) {
      AppFeedback.error("Couldn't save the transaction", error: e, stackTrace: st);
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
      amountController.text = Money.plain(tx.amount.round());
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
      backgroundColor: context.colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: context.colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: context.colors.onPrimary, size: AppIconSize.i22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(isEditing ? 'Edit Transaction' : 'Record Transaction',
                      style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onPrimary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  BackButton(color: context.colors.onPrimary),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= AppBreakpoints.formTwoColumn;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: isTwoColumn
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildTransactionDetailsCard()),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(flex: 1, child: _buildAmountPaymentCard()),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _buildTransactionDetailsCard(),
                          const SizedBox(height: AppSpacing.s16),
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
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.colors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.swap_horiz, 'Transaction Details'),
          const SizedBox(height: AppSpacing.s14),
          const Text('Type *', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
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
          const SizedBox(height: AppSpacing.s14),
          const Text('Category *', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r10),
            onTap: _showCategoryPickerDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCategory ?? 'Select category...',
                      style: TextStyle(
                        fontSize: AppFontSize.f14,
                        color: selectedCategory != null ? context.colors.textPrimary : context.colors.textHint,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s14),
          const Text('Description *', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: descriptionController,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: _fieldDecoration(hintText: 'What was this for?'),
          ),
          const SizedBox(height: AppSpacing.s14),
          const Text('Reference/Note (optional)', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: noteController,
            maxLines: 4,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: _fieldDecoration(hintText: 'Add any additional information'),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.receipt_long_outlined, 'Amount & Payment'),
          const SizedBox(height: AppSpacing.s14),
          const Text('Amount (${AppDefaults.currencySymbol}) *', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: _fieldDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: AppAlpha.a05),
                borderRadius: BorderRadius.circular(AppRadius.r12),
                border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card_outlined, size: AppIconSize.i16, color: context.colors.primary),
                      const SizedBox(width: AppSpacing.s8),
                      Text('Payment Method',
                          style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13, color: context.colors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  PopupMenuButton<String>(
                    initialValue: paymentMethod,
                    onSelected: (method) => setState(() => paymentMethod = method),
                    itemBuilder: (context) => kPaymentMethods.map((method) {
                      return PopupMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(iconForPaymentMethod(method), size: AppIconSize.i18, color: context.colors.primary),
                            const SizedBox(width: AppSpacing.s10),
                            Text(method),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                      ),
                      child: Row(
                        children: [
                          Icon(iconForPaymentMethod(paymentMethod ?? PaymentMethod.cash.key), size: AppIconSize.i18, color: context.colors.primary),
                          const SizedBox(width: AppSpacing.s10),
                          Expanded(child: Text(paymentMethod ?? 'Select method')),
                          Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
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
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s12, AppSpacing.s4, AppSpacing.s4),
                            child: Text(entry.key,
                                style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12_5, color: context.colors.primary)),
                          ),
                          ...entry.value.map((category) => ListTile(
                                dense: true,
                                title: Text(category),
                                trailing: selectedCategory == category
                                    ? Icon(Icons.check, size: AppIconSize.i18, color: context.colors.primary)
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
                                    ? Icon(Icons.check, size: AppIconSize.i18, color: context.colors.primary)
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
                        prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: AppSpacing.s12),
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
      padding: EdgeInsets.fromLTRB(
          AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppIconSize.i16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _saveTransaction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a50),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: AppIconSize.i16),
                      const SizedBox(width: AppSpacing.s8),
                      Text(isEditing ? 'Update Transaction' : 'Record Transaction'),
                      const SizedBox(width: AppSpacing.s6),
                      const Icon(Icons.arrow_forward, size: AppIconSize.i16),
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
  final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

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
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      final modalHeight = (screenSize.height * 0.88).clamp(0, 820).toDouble();
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
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
