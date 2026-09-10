import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/client.dart';

class AddClientScreen extends StatefulWidget {
  final Client? client; // null = add, not null = edit
  final bool isModal;

  const AddClientScreen({super.key, this.client, this.isModal = false});

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
  String? _notes;

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
  String _status = 'Active';

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
      _status = c.status;
      _notes = c.notes;
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
          notes: _notes,
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
          status: _status,
          notes: _notes,
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
    final isEditing = widget.client != null;

    return Scaffold(
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
                const Icon(Icons.people_alt_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isEditing ? 'Edit Client' : 'Add Client',
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
          return Center(
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
                              Expanded(
                                flex: 2,
                                child: _buildLeftColumn(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: _buildRightColumn(),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _buildLeftColumn(),
                            const SizedBox(height: 16),
                            _buildRightColumn(),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildFooter(isEditing),
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

  Widget _fieldLabel(String label) =>
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

  InputDecoration _fieldDecoration({String? hintText}) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
    );
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryDeepGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }


  Widget _buildLeftColumn() {
    final additionalDetailsCard = _buildAdditionalDetailsCard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientInfoCard(),
        if (_selectedTypes.contains('Farmer')) ...[
          const SizedBox(height: 16),
          _buildAnimalCropCard(),
        ],
        if (additionalDetailsCard != null) ...[
          const SizedBox(height: 16),
          additionalDetailsCard,
        ],
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
          _fieldLabel('Name *'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _name,
            decoration: _fieldDecoration(hintText: 'Enter client name'),
            cursorColor: primaryDeepGreen,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
            onChanged: (value) => setState(() => _name = value),
            onSaved: (value) => _name = value!.trim(),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Phone *'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _phone,
            decoration: _fieldDecoration(hintText: 'e.g. 07XX XXX XXX'),
            cursorColor: primaryDeepGreen,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
            onChanged: (value) => setState(() => _phone = value),
            onSaved: (value) => _phone = value!.trim(),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Address'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _address,
            decoration: _fieldDecoration(hintText: 'Enter address'),
            cursorColor: primaryDeepGreen,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
            onChanged: (value) => setState(() => _address = value),
            onSaved: (value) => _address = value!.trim(),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Notes (optional)'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _notes,
            maxLength: 500,
            maxLines: 3,
            decoration: _fieldDecoration(hintText: 'Any additional information about the client...'),
            cursorColor: primaryDeepGreen,
            onSaved: (value) => _notes = value?.trim(),
          ),
          const SizedBox(height: 4),

          if (widget.client != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _fieldLabel('Status'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _status == 'Active',
                          onSelected: (_) => setState(() => _status = 'Active'),
                          selectedColor: Colors.green.withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: _status == 'Active' ? Colors.green[800] : Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Inactive'),
                          selected: _status == 'Inactive',
                          onSelected: (_) => setState(() => _status = 'Inactive'),
                          selectedColor: Colors.grey.withValues(alpha: 0.25),
                          labelStyle: TextStyle(color: _status == 'Inactive' ? Colors.grey[800] : Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientTypeCard(),
        const SizedBox(height: 16),
        _buildQuickSummaryCard(),
        const SizedBox(height: 16),
        _buildTipCard(),
      ],
    );
  }

  IconData _iconForClientType(String type) {
    switch (type) {
      case 'Farmer':
        return Icons.agriculture_outlined;
      case 'Vet':
        return Icons.medical_services_outlined;
      case 'Wholesaler':
        return Icons.local_shipping_outlined;
      case 'Retailer':
        return Icons.storefront_outlined;
      default:
        return Icons.person_outline;
    }
  }

  // Genuinely multi-select, matching the real data model - a client can
  // be more than one type at once (a vet who also farms, a retailer
  // who also buys wholesale). Restyled to match the mockup's card
  // look, but tapping still just toggles membership in the set, same
  // as the ChoiceChips this replaces.
  Widget _buildClientTypeCard() {
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
          _sectionHeader(Icons.category_outlined, 'Client Type'),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildClientTypeTile(clientTypes[0])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildClientTypeTile(clientTypes[1])),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildClientTypeTile(clientTypes[2])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildClientTypeTile(clientTypes[3])),
                ],
              ),
            ],
          ),
          if (_typeError != null) ...[
            const SizedBox(height: 8),
            Text(_typeError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildClientTypeTile(String type) {
    final isSelected = _selectedTypes.contains(type);
    return AspectRatio(
      aspectRatio: 1.3,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          if (isSelected) {
            _selectedTypes.remove(type);
          } else {
            _selectedTypes.add(type);
            if (_typeError != null) _typeError = null;
          }
        }),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? primaryDeepGreen : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? primaryDeepGreen : Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_iconForClientType(type), color: isSelected ? Colors.white : primaryDeepGreen, size: 26),
                    const SizedBox(height: 6),
                    Text(type,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 12, color: primaryDeepGreen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Temporary - Quick Summary and Tip built out properly in a later
  // phase. Kept here now purely so the two-column shell has something
  // to preview on the right beyond just the Client Type card.
  Widget _buildQuickSummaryCard() {
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
          _sectionHeader(Icons.summarize_outlined, 'Quick Summary'),
          const SizedBox(height: 12),
          _summaryRow('Name', _name.trim().isEmpty ? '-' : _name.trim()),
          _summaryRow('Phone', _phone.trim().isEmpty ? '-' : _phone.trim()),
          _summaryRow(
            'Type',
            _selectedTypes.isEmpty ? '-' : _selectedTypes.join(', '),
            valueBold: true,
          ),
          _summaryRow('Address', _address.trim().isEmpty ? '-' : _address.trim()),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryDeepGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: primaryDeepGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You can update this client's animal species or crops anytime by editing their profile.",
              style: TextStyle(fontSize: 12, color: primaryDeepGreen.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  // Temporary - everything from the old Client Type chip selector,
  // farmer/vet/wholesaler conditional fields, and Save button, kept
  // functionally as-is for now inside its own card. Split into the
  // Animal/Crop Information card, Additional Details card, and the
  // real footer in the next phases.
  Widget _buildAnimalCropCard() {
    final isCropProducer = _farmerSubType == 'Crop Producer';
    final isAnimalKeeper = _farmerSubType == 'Animal Keeper';
    final title = isCropProducer ? 'Crop Information (Optional)' : 'Animal Information (Optional)';

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
          _sectionHeader(Icons.list_alt_outlined, title),
          const SizedBox(height: 4),
          Text(
            isCropProducer
                ? 'Add crops grown by this client if available.'
                : isAnimalKeeper
                    ? 'Add animals owned by this client if available.'
                    : 'Select a farmer type below to add crops or animals.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Farmer Type'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _farmerSubType,
            decoration: _fieldDecoration(),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...farmerSubTypes.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))),
            ],
            onChanged: (val) => setState(() => _farmerSubType = val),
          ),
          if (isCropProducer || isAnimalKeeper) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in (isCropProducer ? _selectedCrops : _selectedAnimals))
                  Chip(
                    label: Text(item, style: const TextStyle(fontSize: 12.5)),
                    backgroundColor: primaryDeepGreen.withValues(alpha: 0.08),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() {
                      (isCropProducer ? _selectedCrops : _selectedAnimals).remove(item);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(isCropProducer ? 'Add Crops' : 'Add Animals'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryDeepGreen,
                  side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showGroupedMultiSelectDialog(
                  title: isCropProducer ? 'Select Crops' : 'Select Animal Species',
                  groups: isCropProducer ? cropGroups : animalGroups,
                  selected: isCropProducer ? _selectedCrops : _selectedAnimals,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Multi-select grouped picker - same search + grouped-list pattern
  // already established for the transaction category picker, but
  // items stay toggleable rather than closing the dialog on first tap,
  // since more than one crop or animal species can apply at once.
  Future<void> _showGroupedMultiSelectDialog({
    required String title,
    required Map<String, List<String>> groups,
    required List<String> selected,
  }) async {
    String query = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final lowerQuery = query.trim().toLowerCase();
            final filteredGroups = <String, List<String>>{};
            for (final entry in groups.entries) {
              final matches = entry.value.where((c) => c.toLowerCase().contains(lowerQuery)).toList();
              if (matches.isNotEmpty) filteredGroups[entry.key] = matches;
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                height: 440,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredGroups.isEmpty
                          ? const Center(child: Text('No matches found'))
                          : ListView(
                              children: filteredGroups.entries.expand((entry) {
                                return [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 12.5, color: primaryDeepGreen)),
                                  ),
                                  ...entry.value.map((item) {
                                    final isSelected = selected.contains(item);
                                    return CheckboxListTile(
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      title: Text(item),
                                      value: isSelected,
                                      activeColor: primaryDeepGreen,
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          setState(() {
                                            if (checked == true) {
                                              selected.add(item);
                                            } else {
                                              selected.remove(item);
                                            }
                                          });
                                        });
                                      },
                                    );
                                  }),
                                ];
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }

  // Only rendered at all when at least one relevant type is selected,
  // so an otherwise-empty card doesn't linger in the layout.
  Widget? _buildAdditionalDetailsCard() {
    final showVet = _selectedTypes.contains('Vet');
    final showBusiness = _selectedTypes.contains('Wholesaler') || _selectedTypes.contains('Retailer');
    if (!showVet && !showBusiness) return null;

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
          _sectionHeader(Icons.info_outline, 'Additional Details'),
          const SizedBox(height: 12),
          if (showVet) ...[
            _fieldLabel('Practice Type'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _vetPracticeType,
              decoration: _fieldDecoration(),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...vetPracticeTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))),
              ],
              onChanged: (val) => setState(() => _vetPracticeType = val),
            ),
            if (showBusiness) const SizedBox(height: 12),
          ],
          if (showBusiness) ...[
            _fieldLabel('Business Name'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _businessName,
              decoration: _fieldDecoration(hintText: 'Enter business name'),
              cursorColor: primaryDeepGreen,
              onSaved: (val) => _businessName = val?.trim(),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildFooter(bool isEditing) {
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
            onPressed: _isSaving ? null : _saveClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: offWhite,
              disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.5),
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
                      const Icon(Icons.save_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(isEditing ? 'Update Client' : 'Save Client'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The one entry point for opening Add/Edit Client - same reasoning
/// and threshold as showAddSaleScreen elsewhere in this app: a
/// full-screen push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. Returns whatever the screen itself
/// popped with (true on a successful save), same as calling
/// Navigator.push directly - existing callers that check that value
/// (e.g. add_edit_service_screen.dart) keep working unchanged.
Future<bool?> showAddClientScreen(BuildContext context, {Client? client}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddClientScreen(client: client)),
    );
  }

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: client == null ? 'Add Client' : 'Edit Client',
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
              child: AddClientScreen(client: client, isModal: true),
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
