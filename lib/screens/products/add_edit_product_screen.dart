import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../utils/activity_logger.dart';
import '../../utils/navigator_key.dart';
import '../../utils/thousands_input_formatter.dart';
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

import '../../theme/app_palette.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';

enum ProductDestination {
  sellable,
  stockStore,
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRectPainter({required this.color, this.radius = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        Radius.circular(radius),
      ));
    const dashLength = 7.0;
    const gapLength = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashLength > metric.length ? metric.length : distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
  bool _isWatchlisted = false;

  late TextEditingController _nameController;
  late TextEditingController _supplierController;
  late TextEditingController _batchController;
  late TextEditingController _expiryController;
  late TextEditingController _descriptionController;
  late TextEditingController _buyPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;

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

  final Color primaryDeepTealGreen = AppPalette.primary;
  final Color warmAmber = AppPalette.accent;
  final Color offWhite = AppPalette.background;

  // Optional product photo/icon - a local preview shows immediately
  // after picking, while _imageUrl (the persisted download URL) only
  // updates once the upload actually finishes. When editing an
  // existing product, this starts as whatever photo it already has.
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isUploadingImage = false;

  Future<void> _pickProductImage() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null || facilityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No facility selected. Please select a facility first.')),
      );
      return;
    }

    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _isUploadingImage = true;
    });

    try {
      // A filename independent of the product's own id - a brand-new
      // product doesn't have one yet at this point (it's only
      // generated on save), so the upload can't wait on that. Scoped
      // under the facility's own id so the storage rule can verify the
      // uploader is actually a member of that facility, rather than a
      // flat path any authenticated user could write to.
      final storageRef =
          FirebaseStorage.instance.ref().child('product_images/$facilityId/${const Uuid().v4()}.jpg');
      await storageRef.putData(bytes);
      final downloadUrl = await storageRef.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _imageUrl = downloadUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload image: $e')),
      );
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryDeepTealGreen.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 16, color: primaryDeepTealGreen),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepTealGreen)),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasPreview = _imageBytes != null;
    final hasUploadedUrl = !hasPreview && _imageUrl != null && _imageUrl!.isNotEmpty;
    final hasImage = hasPreview || hasUploadedUrl;

    // A rectangle that fills its column rather than a round avatar - a
    // product photo is a picture of an object, not a face, and a wide
    // frame shows far more of it. Capped so it doesn't stretch absurdly
    // wide when the form is a single, roomy column.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: GestureDetector(
        onTap: _isUploadingImage ? null : _pickProductImage,
        child: CustomPaint(
          // Dashed outline only while empty - a chosen photo gets a
          // plain, thin border instead.
          foregroundPainter:
              hasImage ? null : _DashedRectPainter(color: primaryDeepTealGreen.withValues(alpha: 0.5)),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: primaryDeepTealGreen.withValues(alpha: 0.08),
              border: hasImage ? Border.all(color: Colors.grey.withValues(alpha: 0.3)) : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasPreview)
                  Image.memory(_imageBytes!, fit: BoxFit.cover)
                else if (hasUploadedUrl)
                  Image.network(
                    _imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _photoPlaceholder(),
                  )
                else
                  _photoPlaceholder(),
                if (_isUploadingImage)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                if (hasImage && !_isUploadingImage)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryDeepTealGreen,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What the empty photo frame shows - the prompt lives inside the
  /// rectangle now rather than in a caption underneath it.
  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 36, color: primaryDeepTealGreen.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text(
          'Add photo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryDeepTealGreen),
        ),
        Text('Optional', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    _imageUrl = widget.product?.imageUrl;
    _isWatchlisted = widget.product?.isWatchlisted ?? false;

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
    _minStockController = TextEditingController(
        text: widget.product?.lowStockThreshold?.toString() ?? '');

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
  late final TextEditingController _storeQtyController =
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
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.products)
          .doc(widget.product!.id)
          .collection(Collections.batches)
          .get();

      final batches = snap.docs
          .map((doc) => ProductBatch.fromFirestore(doc.data(), doc.id, widget.product!.id))
          .toList();

      if (mounted) {
        setState(() {
          _batches = batches;
          _loadingBatches = false;
          if (batches.length == 1) {
            _storeQtyController.text = batches.first.stockQty.toString();
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
    _minStockController.dispose();
    _storeQtyController.dispose();
    _shelfQtyController.dispose();
    super.dispose();
  }

  /// [compact] is for a half-width column (the two-column layout): supplier
  /// on its own line, then batch and expiry side by side - three fields
  /// in one row would be too cramped at that width.
  Widget _buildSupplierBatchExpiryFields(bool isNarrow, {bool compact = false}) {
    final supplierField = _supplierField(enabled: true);
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

    if (compact) {
      return Column(
        children: [
          supplierField,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: batchField),
              const SizedBox(width: 12),
              Expanded(child: expiryField),
            ],
          ),
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

  Widget _typeField({required bool enabled}) {
    return InkWell(
      onTap: enabled ? _selectTypeDialog : null,
      child: InputDecorator(
        decoration: _inputDecoration('Type', required: true),
        child: Text(
          _type.isEmpty ? 'Select Type' : _type,
          style: TextStyle(color: _type.isEmpty ? Colors.grey : (enabled ? Colors.black87 : Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _categoryField({required bool enabled}) {
    return FormField<String>(
      initialValue: _category,
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Please select a category' : null,
      builder: (formFieldState) {
        return InkWell(
          onTap: enabled
              ? () async {
                  await _selectCategoryDialog();
                  formFieldState.didChange(_category);
                }
              : null,
          child: InputDecorator(
            decoration: _inputDecoration('Category', required: true).copyWith(
              errorText: formFieldState.errorText,
            ),
            child: Text(
              _category.isEmpty ? 'Select Category' : _category,
              style: TextStyle(
                  color: _category.isEmpty ? Colors.grey : (enabled ? Colors.black87 : Colors.grey[600])),
            ),
          ),
        );
      },
    );
  }

  Widget _supplierField({required bool enabled}) {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _supplierController.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) return const Iterable<String>.empty();
        final query = textEditingValue.text.trim().toLowerCase();
        final suppliers = provider.products
            .map((p) => p.supplier)
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .where((s) => s.toLowerCase().contains(query))
            .toList()
          ..sort();
        return suppliers.take(6);
      },
      onSelected: (selection) => _supplierController.text = selection,
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: _inputDecoration('Supplier'),
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [SentenceCapitalizationFormatter()],
          cursorColor: primaryDeepTealGreen,
          enabled: enabled,
          onChanged: (value) => _supplierController.text = value,
        );
      },
    );
  }

  Widget _buyPriceField(bool fieldsLocked) {
    return TextFormField(
      controller: _buyPriceController,
      decoration: _inputDecoration('Buying Price (Tsh)', required: true),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
      cursorColor: primaryDeepTealGreen,
      enabled: !fieldsLocked,
      validator: (value) {
        final parsed = parseThousands(value ?? '');
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
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
      cursorColor: primaryDeepTealGreen,
      enabled: !fieldsLocked,
      validator: (value) {
        final parsed = parseThousands(value ?? '');
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          constraints: const BoxConstraints(
            maxHeight: 340,
            maxWidth: 340,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Select Category',
                  style: TextStyle(
                    color: offWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _categories.map((cat) {
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        cat,
                        style: TextStyle(color: offWhite, fontSize: 13),
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

  Future<void> _selectTypeDialog() {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: primaryDeepTealGreen.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          constraints: const BoxConstraints(
            maxHeight: 340,
            maxWidth: 340,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Select Type',
                  style: TextStyle(
                    color: offWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _types.map((t) {
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        t,
                        style: TextStyle(color: offWhite, fontSize: 13),
                      ),
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _type = t;
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
          const SnackBar(content: Text('Product name already exists!')),
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
        // Quantity is only set here when adding a brand-new product -
        // editing an existing one never touches it, since that's
        // exactly the "new batch overwrites old expiry" bug this whole
        // restructure fixes. Use "Add New Batch" instead to record new
        // stock.
        //
        // batchNo/expiry follow the same rule, with one deliberate
        // exception: if the product was saved with no batch number or
        // no expiry at all (never set, not "set to something else"),
        // whatever's now in the form is allowed through - there was
        // previously no way to ever fill these in after the fact, since
        // "Add New Batch" creates a separate, additional batch rather
        // than correcting the existing one. An already-set value is
        // still never touched here, for the same reason as always -
        // see the batch-sync just below, which keeps the one matching
        // batch record (if there's exactly one) in step with this.
        batchNo: isEditingProduct
            ? (widget.product!.batchNo == null || widget.product!.batchNo!.isEmpty)
                ? _batchController.text.trim()
                : widget.product!.batchNo
            : _batchController.text.trim(),
        imageUrl: _imageUrl,
        expiry: isEditingProduct
            ? widget.product!.expiry ?? _selectedExpiry
            : _selectedExpiry,
        description: _descriptionController.text.trim(),
        buyPrice: parseThousands(_buyPriceController.text),
        sellPrice: parseThousands(_sellPriceController.text),
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
        hasEverHadStock: isEditingProduct
            ? (widget.product!.hasEverHadStock || widget.product!.stockQty > 0 || widget.product!.sellableQty > 0)
            : (destination == ProductDestination.stockStore
                ? (int.tryParse(_stockController.text.trim()) ?? 0) > 0
                : destination == ProductDestination.sellable
                    ? (int.tryParse(_stockController.text.trim()) ?? 0) > 0
                    : false),
        unit: _unit,
        type: _type,
        category: _category,
        facilityId: facilityId,
        lowStockThreshold: _minStockController.text.trim().isEmpty
            ? null
            : int.tryParse(_minStockController.text.trim()),
        target: destination == ProductDestination.sellable
            ? ProductTarget.sellable
            : ProductTarget.stockStore,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
        isWatchlisted: _isWatchlisted,
      );

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      final userId = userInfo[Fields.userId]!;
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

        // Persist the quantity fields from the simple editor above - but
        // only if the person actually changed one of them. These
        // controllers are seeded once, when the screen opens, from
        // whatever the product's numbers were at that moment - if stock
        // moved in the background since then (a sale, for instance) and
        // the person only meant to edit something unrelated like the
        // name or price, blindly re-writing these fields back would
        // silently overwrite that real, live stock change with the
        // stale snapshot this form started with. Comparing against the
        // original values catches that and skips the write entirely
        // when nothing here was actually touched.
        if (_batches.length <= 1) {
          final newStoreQty = int.tryParse(_storeQtyController.text.trim()) ?? 0;
          final newShelfQty = int.tryParse(_shelfQtyController.text.trim()) ?? 0;
          final originalStoreQty = widget.product?.stockQty ?? 0;
          final originalShelfQty = widget.product?.sellableQty ?? 0;
          final quantityWasEdited = newStoreQty != originalStoreQty || newShelfQty != originalShelfQty;

          if (quantityWasEdited) {
            if (_batches.length == 1) {
              await provider.adjustExistingBatch(
                facilityId: facilityId,
                productId: widget.product!.id,
                batchId: _batches.first.id,
                mode: 'set',
                stockQty: newStoreQty,
                sellableQty: newShelfQty,
              );
            } else {
              // Legacy product, no batch on file yet - a direct, simple
              // update, same as how this worked before batch tracking
              // existed.
              await FirebaseFirestore.instance
                  .collection(Collections.facilities)
                  .doc(facilityId)
                  .collection(Collections.products)
                  .doc(widget.product!.id)
                  .update({'stockQty': newStoreQty, 'sellableQty': newShelfQty});
            }

            // A real, structured record of this specific change - who,
            // when, before and after - rather than leaving the Daily
            // Report to infer that something happened from a leftover
            // number with no explanation attached to it.
            await FirebaseFirestore.instance
                .collection(Collections.facilities)
                .doc(facilityId)
                .collection(Collections.stockAdjustments)
                .add({
              'productId': widget.product!.id,
              'productName': newProduct.name,
              'oldStockQty': originalStoreQty,
              'oldSellableQty': originalShelfQty,
              'newStockQty': newStoreQty,
              'newSellableQty': newShelfQty,
              Fields.userId: userId,
              'userName': userName,
              'source': 'Product edit',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }

        // Fills in a batch number/expiry that was never set, the one
        // time it's now allowed through (see the comment on newProduct
        // above) - keeps the single matching batch record in step with
        // the product's own field, since every other screen (View
        // Batches, FIFO deduction) reads expiry from there, not from
        // the product document. Only the one, originally-auto-created
        // batch is touched - with more than one on file there's no
        // longer a single, unambiguous batch this correction could mean,
        // so it's left for "Add New Batch" instead, same as quantity
        // above.
        final batchNoWasFilledIn = (widget.product!.batchNo == null || widget.product!.batchNo!.isEmpty) &&
            newProduct.batchNo != null &&
            newProduct.batchNo!.isNotEmpty;
        final expiryWasFilledIn = widget.product!.expiry == null && newProduct.expiry != null;
        if ((batchNoWasFilledIn || expiryWasFilledIn) && _batches.length == 1) {
          final batchUpdate = <String, dynamic>{};
          if (batchNoWasFilledIn) batchUpdate['batchNo'] = newProduct.batchNo;
          if (expiryWasFilledIn) batchUpdate['expiry'] = Timestamp.fromDate(newProduct.expiry!);
          await FirebaseFirestore.instance
              .collection(Collections.facilities)
              .doc(facilityId)
              .collection(Collections.products)
              .doc(widget.product!.id)
              .collection(Collections.batches)
              .doc(_batches.first.id)
              .update(batchUpdate);
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
                    ? 'Product added to Sellable Catalog'
                    : 'Product added to Stock Store')
                : 'Product updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back (don't redirect, just pop)
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save product: $e')),
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
        centerTitle: false,
        // Icon before the title, same as Add Sale's header.
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: offWhite, size: 22),
            const SizedBox(width: 12),
            Text(appBarTitle, style: TextStyle(color: offWhite, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        automaticallyImplyLeading: !widget.isModal,
        actions: widget.isModal
            ? [
                IconButton(
                  icon: Icon(Icons.close, color: offWhite),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : null,
      ),
      backgroundColor: offWhite,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          // Same breakpoint Add Sale uses for its own two-column layout,
          // so the two modals always switch layouts at the same width.
          final isTwoColumn = constraints.maxWidth >= 860;

          final List<Widget> imageItems = [
            Center(child: _buildImagePicker()),
          ];

          // Each section's contents, unchanged from before - only where
          // they're placed (one column vs two) is decided below.
          final List<Widget> basicInfoItems = [
              _sectionHeader('Basic Information', Icons.info_outline),
              // Product Name - with live duplicate detection. Typing a
              // name that matches an existing product shows a clear
              // notice with a direct path to "Add New Batch" instead of
              // letting a genuine duplicate slip through as a brand-new,
              // disconnected product record.
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Product Name', required: true),
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [SentenceCapitalizationFormatter()],
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

              // Type & Category
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _typeField(enabled: !fieldsLocked)),
                  const SizedBox(width: 12),
                  Expanded(child: _categoryField(enabled: !fieldsLocked)),
                ],
              ),
              const SizedBox(height: 12),

          ];

          final List<Widget> detailsItems = [
              // Product Details
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Product Details', Icons.folder_outlined),
                    isEditing
                        ? _supplierField(enabled: !fieldsLocked)
                        : _buildSupplierBatchExpiryFields(isNarrow, compact: isTwoColumn),
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
                                controller: _storeQtyController,
                                decoration: _inputDecoration('Store Qty', required: true),
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
                      decoration: _inputDecoration('Description').copyWith(alignLabelWithHint: true),
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [SentenceCapitalizationFormatter()],
                      // Adding, in two columns: the right-hand column (photo,
                      // pricing, settings) is much taller than what sits above
                      // this on the left, so this grows to fill the gap and the
                      // two columns end together. Editing already has the extra
                      // quantity and batch controls on the left, which balance
                      // the columns on their own.
                      minLines: (isTwoColumn && !isEditing) ? 5 : 2,
                      maxLines: (isTwoColumn && !isEditing) ? 9 : 4,
                      cursorColor: primaryDeepTealGreen,
                      enabled: !fieldsLocked,
                    ),
                  ],
                ),

          ];

          final List<Widget> pricingItems = [
              // Pricing & Stock Box
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Pricing & Stock', Icons.attach_money),
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
                  ],
                ),

          ];

          final List<Widget> additionalItems = [
              // Additional Information Box
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Additional Information', Icons.label_outline),
                    // Minimum Stock Level - a per-product low-stock threshold.
                    // Always editable (unlike quantity above, which is
                    // batch-managed once editing), since this is a product-level
                    // setting, not something tied to a specific delivery/batch.
                    TextFormField(
                controller: _minStockController,
                decoration: _inputDecoration('Minimum Stock Level').copyWith(
                  hintText: 'e.g. 5 (defaults to ${Product.defaultLowStockThreshold} if left blank)',
                ),
                keyboardType: TextInputType.number,
                cursorColor: primaryDeepTealGreen,
                enabled: !fieldsLocked,
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) return null; // optional
                  final parsed = int.tryParse(trimmed);
                  if (parsed == null) return 'Invalid';
                  if (parsed < 0) return 'Cannot be negative';
                  return null;
                },
              ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Track in Daily Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Watch-listed products need a physical stock count before the daily closing report can be submitted.',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(Icons.star_outline, color: primaryDeepTealGreen),
                    value: _isWatchlisted,
                    activeColor: primaryDeepTealGreen,
                    onChanged: fieldsLocked ? null : (value) => setState(() => _isWatchlisted = value),
                  ),
                  ],
                ),

          ];

          Widget group(List<Widget> items) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);

          final Widget content = isTwoColumn
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: who/what the product is.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          group(basicInfoItems),
                          group(detailsItems),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: picture, money, and settings.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          group(imageItems),
                          const SizedBox(height: 16),
                          group(pricingItems),
                          const SizedBox(height: 12),
                          group(additionalItems),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    group(imageItems),
                    const SizedBox(height: 20),
                    group(basicInfoItems),
                    group(detailsItems),
                    const SizedBox(height: 12),
                    group(pricingItems),
                    const SizedBox(height: 12),
                    group(additionalItems),
                  ],
                );

          return Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                // Fills the modal's width (it's never wider than this) -
                // was capped at 700, leaving dead space on both sides.
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildFooter(isEditing: isEditing, buttonText: buttonText),
    );
  }

  /// Full-width footer pinned to the bottom of the modal, same as Add
  /// Sale's: Cancel at the far left, the primary action at the far right.
  Widget _buildFooter({required bool isEditing, required String buttonText}) {
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
            onPressed: _isSaving ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepTealGreen,
              foregroundColor: offWhite,
              disabledBackgroundColor: primaryDeepTealGreen.withValues(alpha: 0.5),
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
                      Icon(isEditing ? Icons.update : Icons.save, size: 16),
                      const SizedBox(width: 8),
                      Text(buttonText),
                    ],
                  ),
          ),
        ],
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
      // Same formula as showAddSaleScreen's modal, for consistency
      // across every full-screen-style modal in the app - was
      // previously a fixed 620px (with no floor on height for a short
      // window), rather than scaling with the screen the way every
      // other modal of this kind does.
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
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
