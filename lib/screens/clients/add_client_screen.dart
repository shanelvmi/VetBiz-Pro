import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/client.dart';

class AddClientScreen extends StatefulWidget {
  final Client? client; // null = add, not null = edit

  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  String _name = '';
  String _phone = '';
  String _address = '';
  double _balance = 0.0;

  // Client categorization - a client can genuinely be more than one
  // type at once (a vet who also farms, a retailer who also buys
  // wholesale), so this is a selectable set, not one exclusive choice.
  // Every relevant detail section below shows independently based on
  // what's actually checked, rather than only one type's fields ever
  // being visible at a time.
  final Set<String> _selectedTypes = {};
  String? _farmerSubType;
  List<String> _selectedCrops = [];
  List<String> _selectedAnimals = [];
  String? _vetPracticeType;
  String? _businessName;

  bool _isSaving = false;
  String? _typeError;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final List<String> clientTypes = ['Farmer', 'Vet', 'Wholesaler', 'Retailer'];
  final List<String> farmerSubTypes = ['Crop Producer', 'Animal Keeper'];

  final Map<String, List<String>> cropGroups = {
    'Food Crops': [
      'Maize', 'Rice', 'Wheat', 'Cassava', 'Sorghum', 'Millet', 'Beans',
      'Bananas', 'Sweet Potatoes', 'Irish Potatoes', 'Groundnuts',
    ],
    'Cash Crops': [
      'Coffee', 'Cotton', 'Tobacco', 'Cashew Nuts', 'Sisal', 'Tea',
      'Pyrethrum', 'Sugarcane', 'Cloves', 'Sesame', 'Sunflower',
    ],
    'Vegetables': ['Tomatoes', 'Onions', 'Cabbage', 'Okra'],
    'Fruits': ['Mangoes', 'Oranges', 'Avocado', 'Watermelon'],
  };

  final Map<String, List<String>> animalGroups = {
    'Livestock': ['Cattle', 'Goat', 'Sheep', 'Pig', 'Donkey'],
    'Poultry': ['Chicken', 'Duck', 'Turkey', 'Guinea Fowl'],
    'Other': ['Bees', 'Dog', 'Cat', 'Rabbit'],
  };

  final List<String> vetPracticeTypes = ['Clinic', 'Consultant', 'Hospital', 'Ambulatory'];

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      // Prefill data for editing
      _name = c.name;
      _phone = c.phone;
      _address = c.address;
      _balance = c.balance;

      _selectedTypes.addAll(c.types);
      _farmerSubType = c.farmerSubType;
      _selectedCrops = List.from(c.crops);
      _selectedAnimals = List.from(c.animalSpecies);
      _businessName = c.businessName;
      _vetPracticeType = c.vetPracticeType;
    }
  }

  Future<void> _saveClient() async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once

    // Client Type isn't part of the Form's own validators, since it's a
    // custom chip selector rather than a form field - checked
    // separately here, same principle as before: at least one type
    // must be picked, since the whole app (icons, colors, filtering)
    // depends on a client actually being categorized as something.
    setState(() => _typeError = _selectedTypes.isEmpty ? 'Select at least one client type' : null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypes.isEmpty) return;
    _formKey.currentState!.save();

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId == null || facilityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No facility selected. Cannot save client.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      final typesList = _selectedTypes.toList();

      if (widget.client == null) {
        // ADD
        await clientProvider.addClient(
          facilityId,
          name: _name,
          phone: _phone,
          address: _address,
          types: typesList,
          farmerSubType: _farmerSubType,
          crops: _selectedCrops.isNotEmpty ? _selectedCrops : null,
          animalSpecies: _selectedAnimals.isNotEmpty ? _selectedAnimals : null,
          businessName: _businessName,
          vetPracticeType: _vetPracticeType,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // EDIT
        final updated = widget.client!.copyWith(
          name: _name,
          phone: _phone,
          address: _address,
          types: typesList,
          farmerSubType: _farmerSubType,
          crops: _selectedCrops,
          animalSpecies: _selectedAnimals,
          businessName: _businessName,
          vetPracticeType: _vetPracticeType,
        );
        await clientProvider.updateClient(facilityId, updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save client: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: primaryDeepGreen.withValues(alpha: 0.6),
        width: 1.2,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: primaryDeepGreen,
        width: 2,
      ),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 1.5,
      ),
    );

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add Client' : 'Edit Client'),
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // NAME
                  TextFormField(
                    initialValue: _name,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      enabledBorder: enabledBorder,
                      focusedBorder: focusedBorder,
                      errorBorder: errorBorder,
                      focusedErrorBorder: errorBorder,
                      floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                    ),
                    cursorColor: primaryDeepGreen,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                    onSaved: (value) => _name = value!.trim(),
                  ),
                  const SizedBox(height: 12),

                  // PHONE
                  TextFormField(
                    initialValue: _phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      enabledBorder: enabledBorder,
                      focusedBorder: focusedBorder,
                      errorBorder: errorBorder,
                      focusedErrorBorder: errorBorder,
                      floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                    ),
                    cursorColor: primaryDeepGreen,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                    onSaved: (value) => _phone = value!.trim(),
                  ),
                  const SizedBox(height: 12),

                  // ADDRESS
                  TextFormField(
                    initialValue: _address,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      enabledBorder: enabledBorder,
                      focusedBorder: focusedBorder,
                      errorBorder: errorBorder,
                      focusedErrorBorder: errorBorder,
                      floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                    ),
                    cursorColor: primaryDeepGreen,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                    onSaved: (value) => _address = value!.trim(),
                  ),
                  const SizedBox(height: 16),

                  // CLIENT TYPE(S) - multi-select. A client can genuinely
                  // be more than one of these at once.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Client Type(s)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryDeepGreen)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: clientTypes.map((type) {
                      final isSelected = _selectedTypes.contains(type);
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedTypes.add(type);
                              if (_typeError != null) _typeError = null;
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                        },
                        selectedColor: primaryDeepGreen.withValues(alpha: 0.7),
                      );
                    }).toList(),
                  ),
                  if (_typeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_typeError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // CONDITIONAL FIELDS - each shows independently based
                  // on what's checked above, so a client who's both a
                  // Vet and a Farmer sees both sets of fields at once,
                  // not just whichever type happened to be picked first.
                  if (_selectedTypes.contains('Farmer')) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _farmerSubType,
                      decoration: InputDecoration(
                        labelText: 'Farmer Type',
                        enabledBorder: enabledBorder,
                        focusedBorder: focusedBorder,
                        errorBorder: errorBorder,
                        focusedErrorBorder: errorBorder,
                        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...farmerSubTypes
                            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub))),
                      ],
                      onChanged: (val) => setState(() => _farmerSubType = val),
                    ),
                    const SizedBox(height: 12),

                    if (_farmerSubType == 'Crop Producer')
                      _buildGroupedMultiSelect('Crops', cropGroups, _selectedCrops),

                    if (_farmerSubType == 'Animal Keeper')
                      _buildGroupedMultiSelect('Animal Species', animalGroups, _selectedAnimals),
                  ],
                  if (_selectedTypes.contains('Vet')) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _vetPracticeType,
                      decoration: InputDecoration(
                        labelText: 'Practice Type',
                        enabledBorder: enabledBorder,
                        focusedBorder: focusedBorder,
                        errorBorder: errorBorder,
                        focusedErrorBorder: errorBorder,
                        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...vetPracticeTypes
                            .map((v) => DropdownMenuItem(value: v, child: Text(v))),
                      ],
                      onChanged: (val) => setState(() => _vetPracticeType = val),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_selectedTypes.contains('Wholesaler') || _selectedTypes.contains('Retailer')) ...[
                    TextFormField(
                      initialValue: _businessName,
                      decoration: InputDecoration(
                        labelText: 'Business Name',
                        enabledBorder: enabledBorder,
                        focusedBorder: focusedBorder,
                        errorBorder: errorBorder,
                        focusedErrorBorder: errorBorder,
                        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                      ),
                      cursorColor: primaryDeepGreen,
                      onSaved: (val) => _businessName = val?.trim(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),

                  _isSaving
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.hovered)) return warmAmber;
                                return primaryDeepGreen;
                              }),
                              foregroundColor: WidgetStateProperty.all(offWhite),
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                            ),
                            onPressed: _isSaving ? null : _saveClient,
                            child: Text(
                              widget.client == null ? 'Save Client' : 'Update Client',
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
  }

  Widget _buildGroupedMultiSelect(
    String label,
    Map<String, List<String>> groups,
    List<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...groups.entries.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryDeepGreen.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: group.value.map((opt) {
                    final isSelected = selected.contains(opt);
                    return ChoiceChip(
                      label: Text(opt),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            selected.add(opt);
                          } else {
                            selected.remove(opt);
                          }
                        });
                      },
                      selectedColor: primaryDeepGreen.withValues(alpha: 0.7),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }
}
