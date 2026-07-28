import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../utils/activity_logger.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';

import '../store/stockstore_screen.dart';

enum ProductDestination {
  sellable,
  stockStore,
}

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final ProductDestination? presetDestination; // 🆕 NEW: Auto-destination

  const AddEditProductScreen({
    super.key,
    this.product,
    this.presetDestination, // 🆕 Pass from calling screen
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _supplierController;
  late TextEditingController _batchController;
  late TextEditingController _expiryController;
  late TextEditingController _descriptionController;
  late TextEditingController _buyPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _stockController;

  DateTime? _selectedExpiry;

  String _unit = 'pcs';
  String _type = 'Injectable';
  String _category = '';

  final List<String> _types = [
    'Injectable',
    'Oral Liquid',
    'Powder',
    'Topical',
    'Feed',
    'Equipment',
  ];

  final List<String> _units = ['pcs', 'kg', 'litres', 'others'];

  final List<String> _categories = [
    'Antibiotic',
    'Anthelmintics',
    'Vitamin & Supplements',
    'Hormones & Reproductive',
    'Vaccines',
    'Disinfectant',
    'Feeds',
    'Anti-inflammatory',
    'Actoparasiticides',
    'Wound Management',
    'Surgical Supplies',
    'Farm Tools & Equipment',
    'Miscellaneous',
  ];

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Tsh ',
    decimalDigits: 0,
  );

  final Color primaryDeepTealGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _supplierController =
        TextEditingController(text: widget.product?.supplier ?? '');
    _batchController =
        TextEditingController(text: widget.product?.batchNo ?? '');
    _descriptionController =
        TextEditingController(text: widget.product?.description ?? '');
    _selectedExpiry = widget.product?.expiry;
    _expiryController = TextEditingController(
      text: _selectedExpiry != null
          ? DateFormat('yyyy-MM-dd').format(_selectedExpiry!)
          : '',
    );
    _buyPriceController = TextEditingController(
        text: widget.product?.buyPrice != null
            ? widget.product!.buyPrice.toStringAsFixed(0)
            : '');
    _sellPriceController = TextEditingController(
        text: widget.product?.sellPrice != null
            ? widget.product!.sellPrice.toStringAsFixed(0)
            : '');
    _stockController =
        TextEditingController(text: widget.product?.stockQty.toString() ?? '');

    _unit = widget.product?.unit ?? 'pcs';
    _type = widget.product?.type ?? 'Injectable';
    _category = widget.product?.category ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _supplierController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _descriptionController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[700]),
      floatingLabelStyle: TextStyle(color: primaryDeepTealGreen),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryDeepTealGreen, width: 2),
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExpiry ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedExpiry = pickedDate;
        _expiryController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  void _selectCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: primaryDeepTealGreen.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Category',
                style: TextStyle(
                  color: offWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: _categories.map((cat) {
                    return ListTile(
                      title: Text(
                        cat,
                        style: TextStyle(color: offWhite, fontSize: 14),
                      ),
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _category = cat;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🆕 IMPROVED: Only show dialog if no preset destination
  Future<ProductDestination?> _chooseDestination() async {
    // If preset destination exists, use it without asking
    if (widget.presetDestination != null) {
      return widget.presetDestination;
    }

    // If editing, keep current location
    if (widget.product != null) {
      return widget.product!.target == ProductTarget.sellable
          ? ProductDestination.sellable
          : ProductDestination.stockStore;
    }

    // Otherwise, ask user (for dashboard or unclear context)
    ProductDestination selected = ProductDestination.sellable;

    return await showDialog<ProductDestination>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Where should this product go?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ProductDestination>(
                activeColor: primaryDeepTealGreen,
                title: const Text('Sellable Product Catalog'),
                subtitle: const Text('Available for sales and transactions'),
                value: ProductDestination.sellable,
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
              RadioListTile<ProductDestination>(
                activeColor: primaryDeepTealGreen,
                title: const Text('Stock Store'),
                subtitle: const Text('Stored but not sellable yet'),
                value: ProductDestination.stockStore,
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                foregroundColor: primaryDeepTealGreen,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.hovered)
                      ? warmAmber
                      : primaryDeepTealGreen,
                ),
                foregroundColor: WidgetStateProperty.all(offWhite),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<ProductProvider>(context, listen: false);
    final existingNames =
        provider.products.map((p) => p.name.toLowerCase()).toList();

    // Prevent duplicate names (new product only)
    if (widget.product == null &&
        existingNames.contains(_nameController.text.trim().toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠ Product name already exists!')),
      );
      return;
    }

    // Get destination
    final destination = await _chooseDestination();
    if (destination == null) return; // user cancelled

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacilityId;

    if (facilityId == null || facilityId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No facility selected. Please select a facility first.'),
        ),
      );
      return;
    }

    final now = DateTime.now();

    final newProduct = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      supplier: _supplierController.text.trim(),
      batchNo: _batchController.text.trim(),
      expiry: _selectedExpiry,
      description: _descriptionController.text.trim(),
      buyPrice:
          double.tryParse(_buyPriceController.text.replaceAll(',', '')) ?? 0,
      sellPrice:
          double.tryParse(_sellPriceController.text.replaceAll(',', '')) ?? 0,
      stockQty: destination == ProductDestination.stockStore
          ? int.tryParse(_stockController.text.trim()) ?? 0
          : 0,
      sellableQty: destination == ProductDestination.sellable
          ? int.tryParse(_stockController.text.trim()) ?? 0
          : 0,
      unit: _unit,
      type: _type,
      category: _category,
      facilityId: facilityId,
      target: destination == ProductDestination.sellable
          ? ProductTarget.sellable
          : ProductTarget.stockStore,
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final userInfo = await ActivityLogger.getCurrentUserInfo();
      final userId = userInfo['userId']!;
      final userName = userInfo['userName']!;

      if (widget.product == null) {
        await provider.addProduct(newProduct, context);
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: userId,
          userName: userName,
          actionType: "Products",
          description: "Added new product: ${newProduct.name}",
        );
      } else {
        await provider.updateProduct(newProduct, context);
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: userId,
          userName: userName,
          actionType: "Products",
          description: "Updated product: ${newProduct.name}",
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.product == null
                ? (destination == ProductDestination.sellable
                    ? '✅ Product added to Sellable Catalog'
                    : '✅ Product added to Stock Store')
                : '✅ Product updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back (don't redirect, just pop)
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final productNames = provider.products.map((p) => p.name).toList();

    // 🆕 Dynamic AppBar title
    final isEditing = widget.product != null;
    final appBarTitle = isEditing ? 'Edit Product' : 'Add Product';
    final buttonText = isEditing ? 'Update Product' : 'Save Product';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryDeepTealGreen,
        iconTheme: IconThemeData(color: offWhite),
        title: Text(appBarTitle, style: TextStyle(color: offWhite)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Product Name with autocomplete
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return productNames.where((name) => name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  controller.text = _nameController.text;
                  controller.selection = _nameController.selection;
                  controller.addListener(() {
                    _nameController.text = controller.text;
                    _nameController.selection = controller.selection;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _inputDecoration('Product Name'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                    cursorColor: primaryDeepTealGreen,
                  );
                },
                onSelected: (selection) {
                  _nameController.text = selection;
                },
              ),
              const SizedBox(height: 12),

              // Type
              DropdownButtonFormField(
                initialValue: _type,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                decoration: _inputDecoration('Type'),
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 12),

              // Product Details Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: primaryDeepTealGreen.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryDeepTealGreen,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _supplierController,
                            decoration: _inputDecoration('Supplier'),
                            cursorColor: primaryDeepTealGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _batchController,
                            decoration: _inputDecoration('Batch No'),
                            cursorColor: primaryDeepTealGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            readOnly: true,
                            decoration: _inputDecoration('Expiry').copyWith(
                                suffixIcon: Icon(Icons.calendar_today,
                                    color: primaryDeepTealGreen)),
                            onTap: _pickExpiryDate,
                            cursorColor: primaryDeepTealGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _inputDecoration('Description'),
                      maxLines: 2,
                      cursorColor: primaryDeepTealGreen,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Buy & Sell Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyPriceController,
                      decoration: _inputDecoration('Buying Price (Tsh)'),
                      keyboardType: TextInputType.number,
                      cursorColor: primaryDeepTealGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellPriceController,
                      decoration: _inputDecoration('Selling Price (Tsh)'),
                      keyboardType: TextInputType.number,
                      cursorColor: primaryDeepTealGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock & Unit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: _inputDecoration('Quantity'),
                      keyboardType: TextInputType.number,
                      cursorColor: primaryDeepTealGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField(
                      initialValue: _unit,
                      items: _units
                          .map((unit) => DropdownMenuItem(
                              value: unit, child: Text(unit)))
                          .toList(),
                      decoration: _inputDecoration('Unit'),
                      onChanged: (value) => setState(() => _unit = value!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Category
              InkWell(
                onTap: _selectCategoryDialog,
                child: InputDecorator(
                  decoration: _inputDecoration('Category'),
                  child: Text(
                    _category.isEmpty ? 'Select Category' : _category,
                    style: TextStyle(
                        color: _category.isEmpty ? Colors.grey : Colors.black87),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save/Update Button
              ElevatedButton.icon(
                onPressed: _saveProduct,
                icon: Icon(isEditing ? Icons.update : Icons.save),
                label: Text(buttonText),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.hovered)
                          ? warmAmber
                          : primaryDeepTealGreen),
                  foregroundColor: WidgetStateProperty.all<Color>(offWhite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}