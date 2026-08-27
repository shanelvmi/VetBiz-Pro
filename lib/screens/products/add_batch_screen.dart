import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../utils/thousands_input_formatter.dart';

/// Records a new delivery of an existing product as its own batch - a
/// separate batch number, expiry, and quantity, never overwriting an
/// existing batch's real data. This is the fix for "adding stock changes
/// the expiry of stock already there".
class AddBatchScreen extends StatefulWidget {
  final Product product;
  final bool isModal;
  const AddBatchScreen({super.key, required this.product, this.isModal = false});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _batchController;
  late final TextEditingController _quantityController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _expiryController;
  DateTime? _selectedExpiry;
  bool _isSaving = false;
  // Real deliveries don't always go through the warehouse first - a
  // small top-up picked up on the way to the counter can go straight to
  // the shelf instead.
  String _destination = 'stock';

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController();
    _quantityController = TextEditingController();
    _buyPriceController = TextEditingController(
      text: NumberFormat.decimalPattern('en_US').format(widget.product.buyPrice.round()),
    );
    _expiryController = TextEditingController();
  }

  @override
  void dispose() {
    _batchController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiry = picked;
        _expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isSaving = true);

    try {
      final wasMerged = await Provider.of<ProductProvider>(context, listen: false).addBatch(
        facilityId: facilityId,
        productId: widget.product.id,
        batchNo: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
        expiry: _selectedExpiry,
        buyPrice: _buyPriceController.text.trim().isEmpty
            ? widget.product.buyPrice
            : parseThousands(_buyPriceController.text),
        stockQty: int.tryParse(_quantityController.text.trim()) ?? 0,
        destination: _destination,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasMerged
                ? 'Added to the existing batch with this number and expiry'
                : 'New batch added',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add batch: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Batch'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Choose where this delivery goes - this is recorded as its own batch, '
                  'separate from any existing stock.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _batchController,
                  decoration: const InputDecoration(labelText: 'Batch No (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _pickExpiry,
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Add This Stock To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Stock Store (warehouse)'),
                  subtitle: const Text('Needs a separate "Release" step before it can be sold', style: TextStyle(fontSize: 11.5)),
                  value: 'stock',
                  groupValue: _destination,
                  activeColor: primaryColor,
                  onChanged: (value) => setState(() => _destination = value!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Sellable (straight to the shelf)'),
                  subtitle: const Text('Ready to sell immediately', style: TextStyle(fontSize: 11.5)),
                  value: 'sellable',
                  groupValue: _destination,
                  activeColor: primaryColor,
                  onChanged: (value) => setState(() => _destination = value!),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Quantity Received', border: OutlineInputBorder()),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid quantity';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _buyPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Buy Price (Tsh)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Add Batch'),
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

/// The one entry point for opening Add Batch - same reasoning and
/// threshold as showAddSaleScreen elsewhere in this app: a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens.
Future<void> showAddBatchScreen(BuildContext context, {required Product product}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBatchScreen(product: product)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Batch',
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
              child: AddBatchScreen(product: product, isModal: true),
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
