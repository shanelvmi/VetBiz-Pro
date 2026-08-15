// AddEditServiceScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/service.dart';
import '../../constants/service_categories.dart';
import '../../models/client.dart';
import '../../models/product.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../clients/add_client_screen.dart';

class AddEditServiceScreen extends StatefulWidget {
  final Service? service;
  const AddEditServiceScreen({super.key, this.service});

  @override
  State<AddEditServiceScreen> createState() => _AddEditServiceScreenState();
}

class _AddEditServiceScreenState extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalAmountController;
  late TextEditingController _totalPaidController;
  late TextEditingController _providedByController;
  late TextEditingController _clientTextController;

  Client? _selectedClient;
  String? _selectedCategory;
  DateTime? _serviceDate;

  final List<String> _categories = kServiceCategories;

  // THEME COLORS
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final Color darkTeal = const Color(0xFF2F5D62);

  final NumberFormat _tshFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 0);

  bool _isLoading = false;

  final List<Map<String, TextEditingController>> _itemsUsedControllers = [];
  // Parallel to _itemsUsedControllers - null unless that row's name field
  // matched a real product from the catalog. Set on selection, cleared
  // the moment the vet edits the name field afterward (typing breaks the
  // match, so it correctly falls back to a plain expense line).
  final List<String?> _itemsUsedProductIds = [];
  // Which item row (by index) currently has its suggestion list open -
  // only one at a time, since only one field can be actively typed into.
  int? _activeSuggestionRow;
  // Same idea as the item-row suggestions, for the client search field.
  bool _showClientSuggestions = false;

  @override
  void initState() {
    super.initState();

    // Defensive: makes sure the item-name autocomplete below has real
    // product data even if this screen is somehow reached before
    // Products/Stock Store have been visited. Safe to call repeatedly -
    // ProductProvider no-ops if already listening to this facility.
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null && facilityId.isNotEmpty) {
      Provider.of<ProductProvider>(context, listen: false).listenToProducts(facilityId);
    }

    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.service?.description ?? '');
    _providedByController =
        TextEditingController(text: widget.service?.providedByName ?? '');
    _clientTextController =
        TextEditingController(text: widget.service?.clientName ?? '');

    _selectedCategory = widget.service?.category ?? _categories.first;

    // Prefill date: today if new, original if editing
    _serviceDate = widget.service?.serviceDate ?? DateTime.now();

    double totalAmount = widget.service?.totalAmount ?? 0.0;

    _totalAmountController =
        TextEditingController(text: _tshFormat.format(totalAmount));

    _totalPaidController = TextEditingController(
      text: widget.service?.totalPaid != null
          ? _tshFormat.format(widget.service!.totalPaid)
          : _tshFormat.format(totalAmount),
    );

    // Load items if editing
    if (widget.service?.itemsUsed.isNotEmpty ?? false) {
      for (var item in widget.service!.itemsUsed) {
        final nameCtrl = TextEditingController(text: item['itemName'] ?? '');
        final priceCtrl = TextEditingController(
          text: _tshFormat.format(item['price'] ?? 0),
        );

        // LIVE update
        priceCtrl.addListener(() => setState(() {}));

        _itemsUsedControllers.add({
          'name': nameCtrl,
          'price': priceCtrl,
        });
        _itemsUsedProductIds.add(item['productId'] as String?);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _totalPaidController.dispose();
    _providedByController.dispose();
    _clientTextController.dispose();

    for (var item in _itemsUsedControllers) {
      item['name']!.dispose();
      item['price']!.dispose();
    }

    super.dispose();
  }

  double _parseAmount(String input) =>
      double.tryParse(input.replaceAll(',', '')) ?? 0.0;

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: darkTeal, width: 2),
      ),
      labelStyle: TextStyle(color: darkTeal),
    );
  }

  Future<void> _addNewClient(BuildContext context) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientScreen()),
    );
    if (added == true) setState(() {});
  }

  // ❌ No future dates allowed
  Future<void> _pickServiceDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _serviceDate = picked);
  }

  void _addItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    // LIVE update listener
    priceCtrl.addListener(() => setState(() {}));

    setState(() {
      _itemsUsedControllers.add({
        'name': nameCtrl,
        'price': priceCtrl,
      });
      _itemsUsedProductIds.add(null);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemsUsedControllers[index]['name']!.dispose();
      _itemsUsedControllers[index]['price']!.dispose();
      _itemsUsedControllers.removeAt(index);
      _itemsUsedProductIds.removeAt(index);
    });
  }

  List<Map<String, dynamic>> _collectItemsUsed() {
    return _itemsUsedControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return {
        'itemName': item['name']!.text.trim(),
        'price': _parseAmount(item['price']!.text),
        // Present only when this line was matched to a real product -
        // this is what ServiceProvider uses to decide "deduct from
        // stock, no new expense" vs "just a plain expense line".
        'productId': _itemsUsedProductIds[index],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientProvider = Provider.of<ClientProvider>(context);
    final serviceProvider =
        Provider.of<ServiceProvider>(context, listen: false);
    final facilityProvider =
        Provider.of<FacilityProvider>(context, listen: false);
    final isEditing = widget.service != null;

    double itemsTotal = _itemsUsedControllers.fold(
      0.0,
      (sum, item) => sum + _parseAmount(item['price']!.text),
    );

    return Theme(
  data: Theme.of(context).copyWith(
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: darkTeal,                   // caret color
      selectionColor: darkTeal.withValues(alpha: 0.3), // text selection background
      selectionHandleColor: darkTeal,          // handles when selecting text
    ),
  ),
  child: Scaffold(
    backgroundColor: offWhite,
    appBar: AppBar(
        title: Text(isEditing ? 'Edit Service' : 'Add Service',
            style: TextStyle(color: offWhite)),
        backgroundColor: primaryDeepGreen,
        iconTheme: IconThemeData(color: offWhite),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            primary: true,
            children: [
              // CLIENT FIELD
              TextFormField(
                controller: _clientTextController,
                decoration: InputDecoration(
                  hintText: 'Select Client',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: darkTeal, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addNewClient(context),
                  ),
                ),
                style: TextStyle(color: darkTeal),
                onTap: () => setState(() {
                  _showClientSuggestions = _clientTextController.text.trim().isNotEmpty;
                }),
                onChanged: (val) {
                  setState(() {
                    _selectedClient = null; // typing clears any prior selection
                    _showClientSuggestions = val.trim().isNotEmpty;
                  });
                },
                validator: (value) {
                  if (_selectedClient == null) {
                    return 'Please select a client';
                  }
                  return null;
                },
              ),
              if (_showClientSuggestions && _clientTextController.text.trim().isNotEmpty)
                Builder(builder: (context) {
                  final query = _clientTextController.text.toLowerCase();
                  final matches = clientProvider.clients
                      .where((c) => c.name.toLowerCase().contains(query))
                      .take(6)
                      .toList();

                  if (matches.isEmpty) {
                    return ListTile(
                      title: const Text('No client found'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addNewClient(context),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: matches.map((client) {
                        return ListTile(
                          title: Text(client.name),
                          subtitle: Text(client.phone),
                          onTap: () {
                            setState(() {
                              _selectedClient = client;
                              _clientTextController.text = client.name;
                              _showClientSuggestions = false;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // SERVICE NAME
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Service Name'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter service name' : null,
              ),

              const SizedBox(height: 10),

              // DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
              ),

              const SizedBox(height: 10),

              // CATEGORY
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _inputDecoration('Category'),
                items: _categories
                    .map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),

              const SizedBox(height: 20),

              // PROVIDED BY + DATE
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _providedByController,
                      decoration: _inputDecoration('Provided By'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Enter provider'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickServiceDate(context),
                      child: InputDecorator(
                        decoration: _inputDecoration('Service Date'),
                        child: Text(
                          DateFormat.yMMMMd().format(_serviceDate!),
                          style: TextStyle(color: darkTeal),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // TOTAL + PAID
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalAmountController,
                      decoration: _inputDecoration('Total Amount (Tsh)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter()
                      ],
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter total amount' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _totalPaidController,
                      decoration: _inputDecoration('Total Paid (Tsh)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter()
                      ],
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter paid amount' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ITEMS USED HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Expenses (Items Used)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.add, color: darkTeal),
                    label: Text('Add Item', style: TextStyle(color: darkTeal)),
                    style: ButtonStyle(
                      overlayColor: WidgetStateProperty.all(
                        warmAmber.withValues(alpha: 0.2),
                      ),
                    ),
                    onPressed: _addItem,
                  ),
                ],
              ),

              // ITEMS LIST
              ..._itemsUsedControllers.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                final matchedProductId = _itemsUsedProductIds[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: item['name'],
                              decoration: _inputDecoration('Item Name'),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Enter name' : null,
                              onTap: () => setState(() => _activeSuggestionRow = index),
                              onChanged: (val) {
                                setState(() {
                                  // Typing after a match means the vet
                                  // changed their mind / made a typo -
                                  // falls back to a plain expense line.
                                  if (matchedProductId != null) {
                                    _itemsUsedProductIds[index] = null;
                                  }
                                  _activeSuggestionRow = val.trim().isEmpty ? null : index;
                                });
                              },
                            ),
                            if (_activeSuggestionRow == index &&
                                item['name']!.text.trim().isNotEmpty)
                              Builder(builder: (context) {
                                final query = item['name']!.text.toLowerCase();
                                final matches = Provider.of<ProductProvider>(context,
                                        listen: false)
                                    .products
                                    .where((p) => p.name.toLowerCase().contains(query))
                                    .take(5)
                                    .toList();

                                if (matches.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4, left: 4),
                                    child: Text(
                                      'No matching product - will be recorded as a plain expense.',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  );
                                }

                                return Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: matches.map((product) {
                                      return ListTile(
                                        dense: true,
                                        title: Text(product.name),
                                        subtitle: Text(
                                          'Sellable: ${product.sellableQty} ${product.unit}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onTap: () {
                                          item['name']!.text = product.name;
                                          item['price']!.text =
                                              _tshFormat.format(product.sellPrice);
                                          setState(() {
                                            _itemsUsedProductIds[index] = product.id;
                                            _activeSuggestionRow = null;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),
                            if (matchedProductId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 13, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'In stock - will deduct, no expense recorded',
                                      style: TextStyle(fontSize: 11, color: Colors.green[700]),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: item['price'],
                          decoration: _inputDecoration('Price'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ThousandsSeparatorInputFormatter()
                          ],
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter price' : null,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _removeItem(index),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // TOTAL ITEM COST LIVE
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total Items Cost: Tsh ${NumberFormat.decimalPattern().format(itemsTotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ---- SUBMIT BUTTON ----
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (states) => states.contains(WidgetState.hovered)
                                ? warmAmber
                                : darkTeal,
                          ),
                          foregroundColor:
                              WidgetStateProperty.all<Color>(offWhite),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        onPressed: () async {
                          if (_isLoading) return; // guards against a double-tap firing two saves at once
                          if (!_formKey.currentState!.validate()) return;

                          setState(() => _isLoading = true);

                          final totalAmount =
                              _parseAmount(_totalAmountController.text);
                          final totalPaid =
                              _parseAmount(_totalPaidController.text);

                          if (totalPaid > totalAmount) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Total Paid cannot exceed Total Amount'),
                              ),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }

                          final service = Service(
                            id: widget.service?.id ?? '',
                            category: _selectedCategory ?? 'Other',
                            name: _nameController.text.trim(),
                            description: _descriptionController.text.trim(),
                            totalAmount: totalAmount,
                            totalPaid: totalPaid,
                            clientId: _selectedClient?.id,
                            clientName: _clientTextController.text.trim(),
                            serviceDate: _serviceDate,
                            providedByName:
                                _providedByController.text.trim(),
                            updatedAt: DateTime.now(),
                            itemsUsed: _collectItemsUsed(),
                          );

                          try {
                            final facilityId =
                                facilityProvider.selectedFacilityId;

                            if (facilityId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No facility selected'),
                                ),
                              );
                              setState(() => _isLoading = false);
                              return;
                            }

                            serviceProvider.listenToServices(facilityId);

                            if (widget.service == null) {
                              await serviceProvider.addService(service);
                            } else {
                              await serviceProvider.updateService(service);
                            }

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEditing
                                    ? 'Service updated'
                                    : 'Service added'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save service: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                        child: Text(isEditing ? 'Update' : 'Add'),
                      ),
                    ),
            ],
          ),
        ),
      ),
     )
    );
  }
}

// Thousand separator formatting
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('en_US');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final intValue = int.parse(digitsOnly);
    final newText = _formatter.format(intValue);

    int selectionIndex =
        newText.length - (oldValue.text.length - oldValue.selection.end);
    if (selectionIndex < 0) selectionIndex = 0;
    if (selectionIndex > newText.length) selectionIndex = newText.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
