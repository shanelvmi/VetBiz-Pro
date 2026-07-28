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

  // Client categorization (nullable for None)
  String? _clientType;
  String? _farmerSubType;
  List<String> _selectedCrops = [];
  List<String> _selectedAnimals = [];
  String? _vetPracticeType;
  String? _businessName;

  bool _isSaving = false;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final List<String> clientTypes = ['Farmer', 'Vet', 'Wholesaler', 'Retailer'];
  final List<String> farmerSubTypes = ['Crop Producer', 'Animal Keeper'];
  final List<String> availableCrops = ['Maize', 'Rice', 'Wheat', 'Vegetables'];
  final List<String> availableAnimals = ['Cattle', 'Goat', 'Chicken', 'Sheep'];
  final List<String> vetPracticeTypes = ['Clinic', 'Consultant', 'Hospital'];

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

      _clientType = c.type;
      _farmerSubType = c.farmerSubType;
      _selectedCrops = List.from(c.crops ?? []);
      _selectedAnimals = List.from(c.animalSpecies ?? []);
      _businessName = c.businessName;
      _vetPracticeType = c.vetPracticeType;
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
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

      if (widget.client == null) {
        // ADD
        await clientProvider.addClient(
          facilityId,
          name: _name,
          phone: _phone,
          address: _address,
          type: _clientType ?? 'Farmer',
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
          type: _clientType ?? 'Farmer',
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
      ),
      body: SingleChildScrollView(
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
              const SizedBox(height: 12),

              // CLIENT TYPE
              DropdownButtonFormField<String?>(
                initialValue: _clientType,
                decoration: InputDecoration(
                  labelText: 'Client Type',
                  enabledBorder: enabledBorder,
                  focusedBorder: focusedBorder,
                  errorBorder: errorBorder,
                  focusedErrorBorder: errorBorder,
                  floatingLabelStyle: TextStyle(color: primaryDeepGreen),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...clientTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type))),
                ],
                onChanged: (val) => setState(() => _clientType = val),
              ),
              const SizedBox(height: 12),

              // CONDITIONAL FIELDS
              if (_clientType == 'Farmer') ...[
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
                  _buildMultiSelectField('Crops', availableCrops, _selectedCrops),

                if (_farmerSubType == 'Animal Keeper')
                  _buildMultiSelectField('Animal Species', availableAnimals, _selectedAnimals),
              ] else if (_clientType == 'Vet') ...[
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
              ] else if (_clientType == 'Wholesaler' || _clientType == 'Retailer') ...[
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
              ],

              const SizedBox(height: 20),

              _isSaving
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDeepGreen,
                          foregroundColor: offWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ).copyWith(
                          backgroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.hovered)) return warmAmber;
                            return primaryDeepGreen;
                          }),
                        ),
                        onPressed: _saveClient,
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
    );
  }

  /// Multi-select for crops or animals
  Widget _buildMultiSelectField(String label, List<String> options, List<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
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
        const SizedBox(height: 12),
      ],
    );
  }
}
