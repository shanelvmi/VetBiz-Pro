import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting

import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool _isSaving = false;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  String? type = 'other income';

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final AuthService _authService = AuthService();

  final formatter = NumberFormat('#,##0', 'en_US');

  // For formatting input with thousand separators while typing
  void _onAmountChanged(String value) {
    String newValue = value.replaceAll(',', '');
    if (newValue.isEmpty) {
      amountController.value = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    final number = int.tryParse(newValue);
    if (number == null) return;

    final newText = formatter.format(number);

    // Calculate new cursor position
    int selectionIndex = newText.length - (value.length - amountController.selection.end);

    if (selectionIndex < 0) selectionIndex = 0;

    amountController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

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
    final rawAmount = amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount) ?? 0.0;
    final category = categoryController.text.trim();

    if (description.isEmpty || amount <= 0 || type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    if (widget.transaction != null) {
      // Editing - keep the original date and who recorded it; only the
      // fields the user can actually change here get updated.
      final updated = widget.transaction!.copyWith(
        description: description,
        amount: amount,
        type: type!,
        category: category,
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
    }

    amountController.addListener(() {
      // Only format if user input differs from formatted text
      String currentText = amountController.text;
      String unformatted = currentText.replaceAll(',', '');
      if (currentText != formatter.format(int.tryParse(unformatted) ?? 0)) {
        _onAmountChanged(currentText);
      }
    });
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
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: primaryDeepGreen),
  );

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
      title: Text(widget.transaction != null ? 'Edit Transaction' : 'Add Transaction'),
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
            decoration: InputDecoration(
              labelText: 'Type',
              labelStyle: TextStyle(color: primaryDeepGreen),
              focusedBorder: inputBorder,
              enabledBorder: inputBorder,
            ),
            dropdownColor: offWhite,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: primaryDeepGreen),
              focusedBorder: inputBorder,
              enabledBorder: inputBorder,
            ),
            cursorColor: primaryDeepGreen,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: 'Amount (Tsh)',
              labelStyle: TextStyle(color: primaryDeepGreen),
              focusedBorder: inputBorder,
              enabledBorder: inputBorder,
            ),
            keyboardType: TextInputType.number,
            cursorColor: primaryDeepGreen,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: categoryController,
            decoration: InputDecoration(
              labelText: 'Category (optional)',
              labelStyle: TextStyle(color: primaryDeepGreen),
              focusedBorder: inputBorder,
              enabledBorder: inputBorder,
            ),
            cursorColor: primaryDeepGreen,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveTransaction(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: warmAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
  );
 }
}
