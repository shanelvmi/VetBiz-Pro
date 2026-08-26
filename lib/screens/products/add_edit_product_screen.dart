import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../utils/activity_logger.dart';
import '../../utils/navigator_key.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import 'view_batches_screen.dart';
import 'add_batch_screen.dart';
import '../../constants/product_categories.dart';
import '../../constants/product_units.dart';
import '../../constants/product_types.dart';

import '../store/stockstore_screen.dart';

enum ProductDestination {
  sellable,
  stockStore,
}

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final ProductDestination? presetDestination; // 🆕 NEW: Auto-destination
  final bool isModal;

  const AddEditProductScreen({
    super.key,
    this.product,
    this.presetDestination, // 🆕 Pass from calling screen
    this.isModal = false,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

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

  final List<String> _types = kProductTypes;

  final List<String> _units = kProductUnits;

  final List<String> _categories = kProductCategories;

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

    if (widget.product != null) {
      _loadBatchesForQuantityEditor();
    }
  }

  // Simple, single quantity editor shown right on this screen - covers
  // the common case (one batch, or no batch yet on a legacy product)
  // without sending the user to a separate screen. Only when a product
  // genuinely has more than one batch does this hand off to the more
  // detailed batch management screen, since a single "quantity" number
  // wouldn't mean anything clear at that point.
  List<ProductBatch> _batches = [];
  bool _loadingBatches = false;
  late final TextEditingController _warehouseQtyController =
      TextEditingController(text: widget.product?.stockQty.toString() ?? '0');
  late final TextEditingController _shelfQtyController =
      TextEditingController(text: widget.product?.sellableQty.toString() ?? '0');

  Future<void> _loadBatchesForQuantityEditor() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null || widget.product == null) return;

    setState(() => _loadingBatches = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(widget.product!.id)
          .collection('batches')
          .get();

      final batches = snap.docs
          .map((doc) => ProductBatch.fromFirestore(doc.data(), doc.id, widget.product!.id))
          .toList();

      if (mounted) {
        setState(() {
          _batches = batches;
          _loadingBatches = false;
          if (batches.length == 1) {
            _warehouseQtyController.text = batches.first.stockQty.toString();
            _shelfQtyController.text = batches.first.sellableQty.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBatches = false);
    }
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
    _warehouseQtyController.dispose();
    _shelfQtyController.dispose();
    super.dispose();
  }

  Widget _buildSupplierBatchExpiryFields(bool isNarrow) {
    final supplierField = TextFormField(
      controller: _supplierController,
      decoration: _inputDecoration('Supplier'),
      cursorColor: primaryDeepTealGreen,
    );
    final batchField = TextFormField(
      controller: _batchController,
      decoration: _inputDecoration('Batch No'),
      cursorColor: primaryDeepTealGreen,
    );
    final expiryField = TextFormField(
      controller: _expiryController,
      readOnly: true,
      decoration: _inputDecoration('Expiry').copyWith(
          suffixIcon: Icon(Icons.calendar_today, color: primaryDeepTealGreen)),
      onTap: _pickExpiryDate,
      cursorColor: primaryDeepTealGreen,
    );

    if (isNarrow) {
      return Column(
        children: [
          supplierField,
          const SizedBox(height: 12),
          batchField,
          const SizedBox(height: 12),
          expiryField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: supplierField),
        const SizedBox(width: 12),
        Expanded(child: batchField),
        const SizedBox(width: 12),
        Expanded(child: expiryField),
      ],
    );
  }

  Widget _buyPriceField(bool fieldsLocked) {
    return TextFormField(
      controller: _buyPriceController,
      decoration: _inputDecoration('Buying Price (Tsh)', required: true),
      keyboardType: TextInputType.number,
      cursorColor: primaryDeepTealGreen,
      enabled: !fieldsLocked,
      validator: (value) {
        final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
        if (parsed == null) return 'Enter a valid buying price';
        if (parsed <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }

  Widget _sellPriceField(bool fieldsLocked) {
    return TextFormField(
      controller: _sellPriceController,
      decoration: _inputDecoration('Selling Price (Tsh)', required: true),
      keyboardType: TextInputType.number,
      cursorColor: primaryDeepTealGreen,
      enabled: !fieldsLocked,
      validator: (value) {
        final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
        if (parsed == null) return 'Enter a valid selling price';
        if (parsed <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }

  Widget _quantityField() {
    return TextFormField(
      controller: _stockController,
      decoration: _inputDecoration('Quantity', required: true),
      keyboardType: TextInputType.number,
      cursorColor: primaryDeepTealGreen,
      validator: (value) {
        final parsed = int.tryParse((value ?? '').trim());
        if (parsed == null) return 'Enter a valid quantity';
        if (parsed < 0) return 'Cannot be negative';
        return null;
      },
    );
  }

  Widget _unitDropdown(bool fieldsLocked) {
    return DropdownButtonFormField(
      initialValue: _unit,
      items: _units.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
      decoration: _inputDecoration('Unit'),
      onChanged: fieldsLocked ? null : (String? value) => setState(() => _unit = value!),
    );
  }

  InputDecoration _inputDecoration(String label, {bool required = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
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

  Future<void> _selectCategoryDialog() {
    return showDialog(
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
    if (_isSaving) return; // guards against a double-tap firing two saves at once
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
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
      final isEditingProduct = widget.product != null;

      final newProduct = Product(
        id: widget.product?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        supplier: _supplierController.text.trim(),
        // Batch number, expiry, and quantity are only set here when adding
        // a brand-new product - editing an existing one never touches
        // these, since that's exactly the "new batch overwrites old
        // expiry" bug this whole restructure fixes. Use "Add New Batch"
        // instead to record new stock.
        batchNo: isEditingProduct ? widget.product!.batchNo : _batchController.text.trim(),
        expiry: isEditingProduct ? widget.product!.expiry : _selectedExpiry,
        description: _descriptionController.text.trim(),
        buyPrice:
            double.tryParse(_buyPriceController.text.replaceAll(',', '')) ?? 0,
        sellPrice:
            double.tryParse(_sellPriceController.text.replaceAll(',', '')) ?? 0,
        stockQty: isEditingProduct
            ? widget.product!.stockQty
            : (destination == ProductDestination.stockStore
                ? int.tryParse(_stockController.text.trim()) ?? 0
                : 0),
        sellableQty: isEditingProduct
            ? widget.product!.sellableQty
            : (destination == ProductDestination.sellable
                ? int.tryParse(_stockController.text.trim()) ?? 0
                : 0),
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

        // Persist the quantity fields from the simple editor above -
        // only meaningful for the common case (no batch yet, or exactly
        // one). Multiple batches are handled through "Manage Batches"
        // instead, since a single number wouldn't mean anything clear.
        if (_batches.length <= 1) {
          final newWarehouseQty = int.tryParse(_warehouseQtyController.text.trim()) ?? 0;
          final newShelfQty = int.tryParse(_shelfQtyController.text.trim()) ?? 0;

          if (_batches.length == 1) {
            await provider.adjustExistingBatch(
              facilityId: facilityId,
              productId: widget.product!.id,
              batchId: _batches.first.id,
              mode: 'set',
              stockQty: newWarehouseQty,
              sellableQty: newShelfQty,
            );
          } else {
            // Legacy product, no batch on file yet - a direct, simple
            // update, same as how this worked before batch tracking
            // existed.
            await FirebaseFirestore.instance
                .collection('facilities')
                .doc(facilityId)
                .collection('products')
                .doc(widget.product!.id)
                .update({'stockQty': newWarehouseQty, 'sellableQty': newShelfQty});
          }
        }

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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    // 🆕 Dynamic AppBar title
    final isEditing = widget.product != null;
    // Assistants can freely adjust quantity/batches on an existing
    // product, but editing its price, category, or other core details
    // is admin-only - the Quantity section below is never affected by
    // this, only the fields handled here.
    final fieldsLocked = isEditing && Provider.of<UserRoleProvider>(context).isAssistant;
    final appBarTitle = isEditing ? 'Edit Product' : 'Add Product';
    final buttonText = isEditing ? 'Update Product' : 'Save Product';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryDeepTealGreen,
        iconTheme: IconThemeData(color: offWhite),
        centerTitle: true,
        title: Text(appBarTitle, style: TextStyle(color: offWhite)),
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: Icon(Icons.close, color: offWhite),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Product Name - with live duplicate detection. Typing a
              // name that matches an existing product shows a clear
              // notice with a direct path to "Add New Batch" instead of
              // letting a genuine duplicate slip through as a brand-new,
              // disconnected product record.
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Product Name', required: true),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Product name is required' : null,
                cursorColor: primaryDeepTealGreen,
                enabled: !fieldsLocked,
                autofillHints: const [],
                onChanged: (_) => setState(() {}),
              ),
              if (!isEditing && _nameController.text.trim().length >= 2)
                Builder(builder: (context) {
                  final query = _nameController.text.trim().toLowerCase();
                  final exactMatch = provider.products
                      .where((p) => p.name.toLowerCase() == query)
                      .toList();
                  final similar = provider.products
                      .where((p) =>
                          p.name.toLowerCase() != query &&
                          p.name.toLowerCase().contains(query))
                      .take(4)
                      .toList();

                  if (exactMatch.isEmpty && similar.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final match = exactMatch.isNotEmpty ? exactMatch.first : null;

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: warmAmber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(left: BorderSide(color: warmAmber, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (match != null) ...[
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '"${match.name}" already exists',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adding new stock for it, or updating its quantity? Open it below - '
                            'you can edit its details and quantity right there.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await Future.delayed(const Duration(milliseconds: 300));
                                final rootContext = navigatorKey.currentContext;
                                if (rootContext != null) {
                                  showAddEditProductScreen(rootContext, product: match);
                                }
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Open This Product'),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered)) return warmAmber;
                                  return primaryDeepTealGreen;
                                }),
                                foregroundColor: WidgetStateProperty.all(offWhite),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.search, size: 18, color: Colors.orange[800]),
                              const SizedBox(width: 6),
                              Text(
                                'Similar products already exist',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900], fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...similar.map((p) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                                    TextButton(
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await Future.delayed(const Duration(milliseconds: 300));
                                        final rootContext = navigatorKey.currentContext;
                                        if (rootContext != null) {
                                          showAddEditProductScreen(rootContext, product: p);
                                        }
                                      },
                                      child: const Text('Open', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),

              // Type
              DropdownButtonFormField(
                initialValue: _type,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                decoration: _inputDecoration('Type'),
                onChanged: fieldsLocked ? null : (String? value) => setState(() => _type = value!),
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
                    isEditing
                        ? TextFormField(
                            controller: _supplierController,
                            decoration: _inputDecoration('Supplier'),
                            cursorColor: primaryDeepTealGreen,
                            enabled: !fieldsLocked,
                          )
                        : _buildSupplierBatchExpiryFields(isNarrow),
                    if (isEditing) ...[
                      const SizedBox(height: 14),
                      const Text('Current Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (_loadingBatches)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_batches.length <= 1) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _warehouseQtyController,
                                decoration: _inputDecoration('Warehouse Qty', required: true),
                                keyboardType: TextInputType.number,
                                cursorColor: primaryDeepTealGreen,
                                validator: (value) {
                                  final parsed = int.tryParse((value ?? '').trim());
                                  if (parsed == null) return 'Invalid';
                                  if (parsed < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _shelfQtyController,
                                decoration: _inputDecoration('Shelf Qty', required: true),
                                keyboardType: TextInputType.number,
                                cursorColor: primaryDeepTealGreen,
                                validator: (value) {
                                  final parsed = int.tryParse((value ?? '').trim());
                                  if (parsed == null) return 'Invalid';
                                  if (parsed < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Editing these corrects the actual quantity on hand right now.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'This product has ${_batches.length} separate batches - manage them individually for accuracy.',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  showViewBatchesScreen(context, product: widget.product!);
                                },
                                child: const Text('Manage Batches'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          showAddBatchScreen(context, product: widget.product!);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add New Batch (new delivery, different expiry)'),
                        style: OutlinedButton.styleFrom(foregroundColor: primaryDeepTealGreen),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _inputDecoration('Description'),
                      maxLines: 2,
                      cursorColor: primaryDeepTealGreen,
                      enabled: !fieldsLocked,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Buy & Sell Price
              isNarrow
                  ? Column(
                      children: [_buyPriceField(fieldsLocked), const SizedBox(height: 12), _sellPriceField(fieldsLocked)],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buyPriceField(fieldsLocked)),
                        const SizedBox(width: 12),
                        Expanded(child: _sellPriceField(fieldsLocked)),
                      ],
                    ),
              const SizedBox(height: 12),

              // Stock & Unit
              isNarrow
                  ? Column(
                      children: [
                        if (!isEditing) ...[
                          _quantityField(),
                          const SizedBox(height: 12),
                        ],
                        _unitDropdown(fieldsLocked),
                      ],
                    )
                  : Row(
                      children: [
                        if (!isEditing) ...[
                          Expanded(child: _quantityField()),
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: _unitDropdown(fieldsLocked)),
                      ],
                    ),

              const SizedBox(height: 12),

              // Category
              FormField<String>(
                initialValue: _category,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please select a category' : null,
                builder: (formFieldState) {
                  return InkWell(
                    onTap: fieldsLocked
                        ? null
                        : () async {
                            await _selectCategoryDialog();
                            formFieldState.didChange(_category);
                          },
                    child: InputDecorator(
                      decoration: _inputDecoration('Category', required: true).copyWith(
                        errorText: formFieldState.errorText,
                      ),
                      child: Text(
                        _category.isEmpty ? 'Select Category' : _category,
                        style: TextStyle(
                            color: _category.isEmpty ? Colors.grey : (fieldsLocked ? Colors.grey[600] : Colors.black87)),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Save/Update Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProduct,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(isEditing ? Icons.update : Icons.save),
                label: Text(_isSaving ? 'Saving...' : buttonText),
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
            ),
          );
        },
      ),
    );
  }
}
/// The one entry point for opening Add/Edit Product - a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. Same reasoning as showAddSaleScreen -
/// a quick, frequent action shouldn't need a full page navigation away
/// from wherever it was triggered.
Future<void> showAddEditProductScreen(
  BuildContext context, {
  Product? product,
  ProductDestination? presetDestination,
}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(product: product, presetDestination: presetDestination),
      ),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: product != null ? 'Edit Product' : 'Add Product',
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
              child: AddEditProductScreen(
                product: product,
                presetDestination: presetDestination,
                isModal: true,
              ),
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
