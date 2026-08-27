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
  final TextEditingController categoryController = TextEditingController();
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
    final category = categoryController.text.trim();

    if (description.isEmpty || amount <= 0 || type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    if (type == 'other income' && paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select how this income was received')),
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
        paymentMethod: type == 'other income' ? paymentMethod : null,
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
      paymentMethod: type == 'other income' ? paymentMethod : null,
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
      categoryController.text = tx.category;
      amountController.text = formatter.format(tx.amount.round());
      paymentMethod = tx.paymentMethod;
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryDeepGreen),
      filled: true,
      fillColor: primaryDeepGreen.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryDeepGreen, width: 1.5),
      ),
    );
  }

  final dropdownOptions = ['other income', 'expense'];

  // Title case (capitalize each word)
  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  return Scaffold(
    backgroundColor: offWhite,
    appBar: AppBar(
      title: Text(widget.transaction != null ? 'Edit Transaction' : 'Record Transaction'),
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      centerTitle: true,
      automaticallyImplyLeading: !widget.isModal,
      leading: widget.isModal
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Text(
            widget.transaction != null ? 'Edit Transaction Details' : 'Transaction Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryDeepGreen),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: dropdownOptions.map((val) {
              return DropdownMenuItem(
                value: val,
                child: Text(
                  toTitleCase(val),
                  style: TextStyle(color: primaryDeepGreen),
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => type = val),
            decoration: fieldDecoration('Type'),
            dropdownColor: offWhite,
          ),
          if (type == 'other income') ...[
            const SizedBox(height: 16),
            PaymentMethodSelector(
              value: paymentMethod,
              activeColor: primaryDeepGreen,
              onChanged: (method) => setState(() => paymentMethod = method),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: descriptionController,
            decoration: fieldDecoration('Description'),
            cursorColor: primaryDeepGreen,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amountController,
            decoration: fieldDecoration('Amount (Tsh)'),
            keyboardType: TextInputType.number,
            cursorColor: primaryDeepGreen,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: categoryController,
            decoration: fieldDecoration('Category (optional)'),
            cursorColor: primaryDeepGreen,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveTransaction(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryDeepGreen;
                }),
                foregroundColor: WidgetStateProperty.all(offWhite),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.transaction != null ? 'Update Transaction' : 'Save Transaction',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
      return Center(
        child: SizedBox(
          width: screenSize.width * 0.8,
          height: screenSize.height * 0.85,
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
