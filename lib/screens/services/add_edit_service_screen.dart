// AddEditServiceScreen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/service.dart';
import '../../constants/service_categories.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../models/client.dart';
import '../../models/product.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../widgets/payment_method_selector.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../clients/add_client_screen.dart';

class AddEditServiceScreen extends StatefulWidget {
  final Service? service;
  final bool isModal;
  const AddEditServiceScreen({super.key, this.service, this.isModal = false});

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
  late TextEditingController _transactionIdController;
  String? _paymentMethod;

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
  Timer? _clientSearchDebounce;
  List<Client> _clientSearchResults = [];
  bool _isSearchingClients = false;

  // Used to measure the client field's actual on-screen position, so
  // the suggestions overlay below can be placed precisely under it
  // rather than guessing a fixed pixel offset - same pattern as Add
  // Sale's client field overlay.
  final GlobalKey _clientFieldKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

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
    _transactionIdController =
        TextEditingController(text: widget.service?.transactionId ?? '');

    _selectedCategory = widget.service?.category ?? _categories.first;

    // Prefill date: today if new, original if editing
    _serviceDate = widget.service?.serviceDate ?? DateTime.now();
    _paymentMethod = widget.service?.paymentMethod;

    double totalAmount = widget.service?.totalAmount ?? 0.0;

    _totalAmountController =
        TextEditingController(text: _tshFormat.format(totalAmount));

    _totalPaidController = TextEditingController(
      text: widget.service?.totalPaid != null
          ? _tshFormat.format(widget.service!.totalPaid)
          : _tshFormat.format(totalAmount),
    );
    _totalPaidController.addListener(() => setState(() {}));

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
    _clientSearchDebounce?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _totalPaidController.dispose();
    _providedByController.dispose();
    _clientTextController.dispose();
    _transactionIdController.dispose();

    for (var item in _itemsUsedControllers) {
      item['name']!.dispose();
      item['price']!.dispose();
    }

    super.dispose();
  }

  // Debounced, server-side client search - waits for a brief pause in
  // typing before actually querying Firestore, and only once at least
  // 2 characters have been entered (a single character matches too
  // broadly to be useful, and would fire a query on every keystroke
  // for no benefit). Replaces filtering clientProvider.clients, which
  // held the facility's entire client list in memory regardless of
  // how large it was.
  void _onClientSearchChanged(String query) {
    _clientSearchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      setState(() {
        _clientSearchResults = [];
        _isSearchingClients = false;
      });
      return;
    }

    setState(() => _isSearchingClients = true);
    _clientSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId == null) {
        if (mounted) setState(() => _isSearchingClients = false);
        return;
      }
      try {
        final results =
            await Provider.of<ClientProvider>(context, listen: false).searchClientsByName(facilityId, trimmed);
        if (!mounted) return;
        setState(() {
          _clientSearchResults = results;
          _isSearchingClients = false;
        });
      } catch (e) {
        debugPrint('Client search error: $e');
        if (mounted) setState(() => _isSearchingClients = false);
      }
    });
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
    final added = await showAddClientScreen(context);
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
          cursorColor: darkTeal,
          selectionColor: darkTeal.withValues(alpha: 0.3),
          selectionHandleColor: darkTeal,
        ),
      ),
      child: Scaffold(
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
                  const Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(isEditing ? 'Edit Visit' : 'Record Visit',
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
            return Stack(
              key: _stackKey,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: isTwoColumn
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 2, child: _buildLeftColumn(itemsTotal)),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 1, child: _buildVisitSummaryCard()),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  _buildLeftColumn(itemsTotal),
                                  const SizedBox(height: 16),
                                  _buildVisitSummaryCard(),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                _buildClientSuggestionsOverlay(),
              ],
            );
          },
        ),
        bottomNavigationBar: _buildFooter(isEditing, serviceProvider, facilityProvider),
      ),
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

  Widget _buildClientInfoCard() {
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
          _sectionHeader(Icons.person_outline, 'Client Information'),
          const SizedBox(height: 12),
          const Text('Select Client *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            key: _clientFieldKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _clientTextController,
                  decoration: InputDecoration(
                    hintText: 'Search or select client...',
                    hintStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                  ),
                  onTap: () => setState(() {
                    _showClientSuggestions = _clientTextController.text.trim().length >= 2;
                  }),
                  onChanged: (val) {
                    setState(() {
                      _selectedClient = null; // typing clears any prior selection
                      _showClientSuggestions = val.trim().length >= 2;
                    });
                    _onClientSearchChanged(val);
                  },
                  validator: (value) {
                    if (_selectedClient == null) {
                      return 'Please select a client';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Add New Client',
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(),
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return warmAmber;
                    return primaryDeepGreen;
                  }),
                ),
                onPressed: () => _addNewClient(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(double itemsTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientInfoCard(),
        const SizedBox(height: 16),
        _buildVisitDetailsCard(),
        const SizedBox(height: 16),
        _buildExpensesCard(itemsTotal),
      ],
    );
  }

  Widget _buildVisitDetailsCard() {
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
          _sectionHeader(Icons.description_outlined, 'Visit Details'),
          const SizedBox(height: 12),
              // SERVICE NAME
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Service Name'),
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [SentenceCapitalizationFormatter()],
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter service name' : null,
              ),

              const SizedBox(height: 10),

              // DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [SentenceCapitalizationFormatter()],
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
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [SentenceCapitalizationFormatter()],
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

        ],
      ),
    );
  }

  Widget _buildExpensesCard(double itemsTotal) {
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
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [SentenceCapitalizationFormatter()],
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
        ],
      ),
    );
  }

  Widget _buildVisitSummaryCard() {
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
          _sectionHeader(Icons.receipt_long_outlined, 'Visit Summary'),
          const SizedBox(height: 14),
          const Text('Total Amount (Tsh) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _totalAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(
              hintText: '0.00',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter total amount' : null,
          ),
          const SizedBox(height: 14),
          const Text('Total Paid (Tsh) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _totalPaidController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(
              hintText: '0.00',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter paid amount' : null,
          ),
          if (_parseAmount(_totalPaidController.text) > 0) ...[
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
                    initialValue: _paymentMethod,
                    onSelected: (method) => setState(() => _paymentMethod = method),
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
                          Icon(iconForPaymentMethod(_paymentMethod ?? 'Cash'), size: 18, color: primaryDeepGreen),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_paymentMethod ?? 'Select method')),
                          Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_paymentMethod != null && _paymentMethod != 'Cash') ...[
              const SizedBox(height: 14),
              const Text('Transaction ID (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _transactionIdController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(bool isEditing, ServiceProvider serviceProvider, FacilityProvider facilityProvider) {
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
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    if (_isLoading) return; // guards against a double-tap firing two saves at once
                    if (!_formKey.currentState!.validate()) return;

                    setState(() => _isLoading = true);

                    final totalAmount = _parseAmount(_totalAmountController.text);
                    final totalPaid = _parseAmount(_totalPaidController.text);

                    if (totalPaid > totalAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Total Paid cannot exceed Total Amount')),
                      );
                      setState(() => _isLoading = false);
                      return;
                    }

                    if (totalPaid > 0 && _paymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Select how this payment was made')),
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
                      providedByName: _providedByController.text.trim(),
                      updatedAt: DateTime.now(),
                      itemsUsed: _collectItemsUsed(),
                      paymentMethod: totalPaid > 0 ? _paymentMethod : null,
                      transactionId: _paymentMethod != null && _paymentMethod != 'Cash' && _transactionIdController.text.trim().isNotEmpty
                          ? _transactionIdController.text.trim()
                          : null,
                    );

                    try {
                      final facilityId = facilityProvider.selectedFacilityId;

                      if (facilityId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No facility selected')),
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
                          content: Text(isEditing ? 'Service updated' : 'Service added'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: darkTeal,
              foregroundColor: offWhite,
              disabledBackgroundColor: darkTeal.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(isEditing ? 'Update Visit' : 'Record Visit'),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// The client-name suggestions, shown as a genuine overlay positioned
  /// just under the client field - rather than sitting inline in the
  /// form's own layout flow, where it would push everything below it
  /// (including the item rows and Add Item button) down every time it
  /// appeared. Measures the client field's actual on-screen position
  /// via its GlobalKey, rather than assuming a fixed pixel offset.
  Widget _buildClientSuggestionsOverlay() {
    final trimmedQuery = _clientTextController.text.trim();
    if (!_showClientSuggestions || trimmedQuery.length < 2) {
      return const SizedBox.shrink();
    }

    final renderBox = _clientFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final fieldPosition = renderBox.localToGlobal(Offset.zero);
    final fieldSize = renderBox.size;

    // Convert the field's global position back to a position relative
    // to the Stack it's being positioned within - not the whole
    // Scaffold, which would also fold the AppBar's own height into
    // this conversion and throw the overlay's position off.
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final localTop = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dy
        : fieldPosition.dy;

    // Aligns with the field's own actual on-screen left edge and width,
    // rather than assuming the field is centered within some fixed
    // page width - correct regardless of which column the field sits
    // in, how it's nested inside its card, or the screen size.
    final localLeft = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dx
        : fieldPosition.dx;

    return Positioned(
      top: localTop + fieldSize.height + 4,
      left: localLeft,
      width: fieldSize.width,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: offWhite,
          ),
          child: _isSearchingClients && _clientSearchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : _clientSearchResults.isEmpty
                  ? ListTile(
                      title: const Text('No client found'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addNewClient(context),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: _clientSearchResults.map((client) {
                        return ListTile(
                          title: Text(client.name),
                          subtitle: Text(client.phone),
                          hoverColor: warmAmber.withValues(alpha: 0.15),
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
        ),
      ),
    );
  }
}

/// The one entry point for opening Add/Edit Service - a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. Same reasoning as showAddSaleScreen -
/// a quick, frequent action shouldn't need a full page navigation away
/// from wherever it was triggered.
Future<void> showAddEditServiceScreen(BuildContext context, {Service? service}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditServiceScreen(service: service)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: service != null ? 'Edit Visit' : 'Record Visit',
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
              child: AddEditServiceScreen(service: service, isModal: true),
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
