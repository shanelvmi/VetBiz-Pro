// AddEditServiceScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/service.dart';
import '../../models/client.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
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

  final List<String> _categories = [
    'Surgical',
    'Treatment',
    'Management',
    'Consultation',
    'Diagnostics',
    'Vaccination',
    'Other'
  ];

  // THEME COLORS
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final Color darkTeal = const Color(0xFF2F5D62);

  final NumberFormat _tshFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 0);

  bool _isLoading = false;

  final List<Map<String, TextEditingController>> _itemsUsedControllers = [];

  @override
  void initState() {
    super.initState();

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
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemsUsedControllers[index]['name']!.dispose();
      _itemsUsedControllers[index]['price']!.dispose();
      _itemsUsedControllers.removeAt(index);
    });
  }

  List<Map<String, dynamic>> _collectItemsUsed() {
    return _itemsUsedControllers.map((item) {
      return {
        'itemName': item['name']!.text.trim(),
        'price': _parseAmount(item['price']!.text),
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
              TypeAheadFormField<Client>(
                textFieldConfiguration: TextFieldConfiguration(
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
                ),
                suggestionsCallback: (pattern) {
                  if (pattern.isEmpty) return [];
                  return clientProvider.clients.where((client) =>
                      client.name.toLowerCase().contains(pattern.toLowerCase()));
                },
                itemBuilder: (_, Client suggestion) {
                  return ListTile(
                    title: Text(suggestion.name),
                    subtitle: Text(suggestion.phone),
                  );
                },
                onSuggestionSelected: (Client suggestion) {
                  _selectedClient = suggestion;
                  _clientTextController.text = suggestion.name;
                },
                validator: (value) {
                  if (_selectedClient == null) {
                    return 'Please select a client';
                  }
                  return null;
                },
                noItemsFoundBuilder: (_) => ListTile(
                  title: const Text('No client found'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addNewClient(context),
                  ),
                ),
              ),

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

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: item['name'],
                          decoration: _inputDecoration('Item Name'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter name' : null,
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
