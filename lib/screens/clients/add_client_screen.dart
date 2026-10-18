import 'package:flutter/material.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:provider/provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/client.dart';
import '../../utils/client_duplicate_matcher.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../constants/client_options.dart';
import '../../l10n/l10n.dart';
import '../../constants/crops.dart';

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


  final List<String> clientTypes = kClientTypes;
  final List<String> farmerSubTypes = kFarmerSubTypes;

  final Map<String, List<String>> cropGroups = kCropGroups;

  final Map<String, List<String>> animalGroups = kAnimalGroups;

  final List<String> vetPracticeTypes = kVetPracticeTypes;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      // Prefill data for editing
      _name = c.name;
      _phone = c.phone;
      _address = c.address;

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
    setState(() => _typeError = _selectedTypes.isEmpty ? context.l10n.clients_errSelectType : null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypes.isEmpty) return;
    _formKey.currentState!.save();

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId == null || facilityId.isEmpty) {
      AppFeedback.error(L10n.current.clients_saveFailed, detail: L10n.current.common_noFacility);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      final typesList = _selectedTypes.toList();

      // Stop the same person being added twice - checked against the
      // database BEFORE anything is written. When editing, only a name or
      // phone number that was actually changed is checked, so a client who
      // is already a duplicate (from before this check existed) can still
      // have their other details edited.
      final existing = widget.client;
      final nameChanged = existing == null ||
          ClientDuplicateMatcher.normalizeName(_name) != ClientDuplicateMatcher.normalizeName(existing.name);
      final phoneChanged = existing == null ||
          ClientDuplicateMatcher.phoneKey(_phone) != ClientDuplicateMatcher.phoneKey(existing.phone);
      if (nameChanged || phoneChanged) {
        final duplicate = await clientProvider.findSimilarClient(
          facilityId,
          name: _name,
          phone: _phone,
          excludeClientId: existing?.id,
          checkName: nameChanged,
          checkPhone: phoneChanged,
        );
        if (duplicate != null) {
          if (!mounted) return;
          await _showDuplicateDialog(duplicate);
          return; // nothing saved; the form stays as it was so it can be corrected
        }
      }

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
        AppFeedback.success(L10n.current.clients_added);
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
        AppFeedback.success(L10n.current.clients_updated);
      }

      Navigator.pop(context, true);
    } catch (e, st) {
      AppFeedback.error(L10n.current.clients_saveFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showDuplicateDialog(SimilarClientMatch match) {
    final existing = match.client;
    final byPhone = match.matchedByPhone;
    final isAdding = widget.client == null;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.colors.danger),
            SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(context.l10n.clients_duplicateTitle)),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                byPhone
                    ? context.l10n.clients_duplicateByPhone
                    : context.l10n.clients_duplicateByName,
                style: const TextStyle(fontSize: AppFontSize.f13_5),
              ),
              const SizedBox(height: AppSpacing.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: context.colors.danger.withValues(alpha: AppAlpha.a05),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  border: Border.all(color: context.colors.danger.withValues(alpha: AppAlpha.a20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(existing.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14_5)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      existing.phone.trim().isEmpty ? context.l10n.clients_noPhone : existing.phone,
                      style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                context.l10n.clients_duplicateBody(isAdding ? 'add' : 'edit', byPhone ? 'phone' : 'name'),
                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: context.colors.brandSurface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, color: context.colors.onBrandSurface, size: AppIconSize.i22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(isEditing ? context.l10n.clients_edit : context.l10n.clients_add,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onBrandSurface),
                    tooltip: context.l10n.common_close,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  BackButton(color: context.colors.onBrandSurface),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= AppBreakpoints.formTwoColumn;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s16),
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
                              const SizedBox(width: AppSpacing.s16),
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
                            const SizedBox(height: AppSpacing.s16),
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
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  Widget _fieldLabel(String label) =>
      Text(label, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13));

  InputDecoration _fieldDecoration({String? hintText}) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
    );
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.colors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        borderSide: BorderSide(color: context.colors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        borderSide: BorderSide(color: context.colors.danger, width: 1.5),
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
          const SizedBox(height: AppSpacing.s16),
          _buildAnimalCropCard(),
        ],
        if (additionalDetailsCard != null) ...[
          const SizedBox(height: AppSpacing.s16),
          additionalDetailsCard,
        ],
      ],
    );
  }

  Widget _buildClientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, context.l10n.clients_infoSection),
          const SizedBox(height: AppSpacing.s12),
          _fieldLabel(context.l10n.common_requiredLabel(context.l10n.common_name)),
          const SizedBox(height: AppSpacing.s6),
          TextFormField(
            initialValue: _name,
            decoration: _fieldDecoration(hintText: context.l10n.clients_nameHint),
            cursorColor: context.colors.primary,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            validator: (value) =>
                value == null || value.trim().isEmpty ? context.l10n.common_required : null,
            onChanged: (value) => setState(() => _name = value),
            onSaved: (value) => _name = value!.trim(),
          ),
          const SizedBox(height: AppSpacing.s12),
          _fieldLabel(context.l10n.common_requiredLabel(context.l10n.common_phone)),
          const SizedBox(height: AppSpacing.s6),
          TextFormField(
            initialValue: _phone,
            decoration: _fieldDecoration(hintText: context.l10n.clients_phoneHint),
            cursorColor: context.colors.primary,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value == null || value.trim().isEmpty ? context.l10n.common_required : null,
            onChanged: (value) => setState(() => _phone = value),
            onSaved: (value) => _phone = value!.trim(),
          ),
          const SizedBox(height: AppSpacing.s12),
          _fieldLabel(context.l10n.common_address),
          const SizedBox(height: AppSpacing.s6),
          TextFormField(
            initialValue: _address,
            decoration: _fieldDecoration(hintText: context.l10n.clients_addressHint),
            cursorColor: context.colors.primary,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            validator: (value) =>
                value == null || value.trim().isEmpty ? context.l10n.common_required : null,
            onChanged: (value) => setState(() => _address = value),
            onSaved: (value) => _address = value!.trim(),
          ),
          const SizedBox(height: AppSpacing.s12),
          _fieldLabel(context.l10n.common_notesOptional),
          const SizedBox(height: AppSpacing.s6),
          TextFormField(
            initialValue: _notes,
            maxLength: 500,
            maxLines: 3,
            decoration: _fieldDecoration(hintText: context.l10n.clients_notesHint),
            cursorColor: context.colors.primary,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            onSaved: (value) => _notes = value?.trim(),
          ),
          const SizedBox(height: AppSpacing.s4),

          if (widget.client != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _fieldLabel(context.l10n.common_status),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(context.l10n.clientStatusLabel('Active')),
                          selected: _status == 'Active',
                          onSelected: (_) => setState(() => _status = 'Active'),
                          selectedColor: context.colors.success.withValues(alpha: AppAlpha.a15),
                          labelStyle: TextStyle(color: _status == 'Active' ? context.colors.successStrong : context.colors.textPrimary),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        ChoiceChip(
                          label: Text(context.l10n.clientStatusLabel('Inactive')),
                          selected: _status == 'Inactive',
                          onSelected: (_) => setState(() => _status = 'Inactive'),
                          selectedColor: context.colors.textHint.withValues(alpha: AppAlpha.a30),
                          labelStyle: TextStyle(color: _status == 'Inactive' ? context.colors.textPrimary : context.colors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
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
        const SizedBox(height: AppSpacing.s16),
        _buildQuickSummaryCard(),
        const SizedBox(height: AppSpacing.s16),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.category_outlined, context.l10n.clients_clientType),
          const SizedBox(height: AppSpacing.s12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildClientTypeTile(clientTypes[0])),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(child: _buildClientTypeTile(clientTypes[1])),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  Expanded(child: _buildClientTypeTile(clientTypes[2])),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(child: _buildClientTypeTile(clientTypes[3])),
                ],
              ),
            ],
          ),
          if (_typeError != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(_typeError!, style: TextStyle(color: context.colors.danger, fontSize: AppFontSize.f12)),
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
        borderRadius: BorderRadius.circular(AppRadius.r10),
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
            color: isSelected ? context.colors.primary : context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(color: isSelected ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_iconForClientType(type), color: isSelected ? context.colors.onPrimary : context.colors.primary, size: AppIconSize.i24),
                    const SizedBox(height: AppSpacing.s6),
                    Text(context.l10n.clientTypeLabel(type),
                        style: TextStyle(
                            color: isSelected ? context.colors.onPrimary : context.colors.textPrimary,
                            fontWeight: AppFontWeight.semibold,
                            fontSize: AppFontSize.f13)),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: AppIconSize.i12, color: context.colors.primary),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.summarize_outlined, context.l10n.clients_quickSummary),
          const SizedBox(height: AppSpacing.s12),
          _summaryRow(context.l10n.common_name, _name.trim().isEmpty ? '-' : _name.trim()),
          _summaryRow(context.l10n.common_phone, _phone.trim().isEmpty ? '-' : _phone.trim()),
          _summaryRow(
            context.l10n.common_type,
            _selectedTypes.isEmpty ? '-' : _selectedTypes.map(context.l10n.clientTypeLabel).join(', '),
            valueBold: true,
          ),
          _summaryRow(context.l10n.common_address, _address.trim().isEmpty ? '-' : _address.trim()),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppFontSize.f12_5,
                fontWeight: valueBold ? AppFontWeight.bold : AppFontWeight.medium,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: AppIconSize.i18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              context.l10n.clients_tip,
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.primary.withValues(alpha: AppAlpha.a85)),
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
    final title = isCropProducer ? context.l10n.clients_cropInfo : context.l10n.clients_animalInfo;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.list_alt_outlined, title),
          const SizedBox(height: AppSpacing.s4),
          Text(
            isCropProducer
                ? context.l10n.clients_cropHint
                : isAnimalKeeper
                    ? context.l10n.clients_animalHint
                    : context.l10n.clients_farmerTypeHint,
            style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f12_5),
          ),
          const SizedBox(height: AppSpacing.s12),
          _fieldLabel(context.l10n.clients_farmerType),
          const SizedBox(height: AppSpacing.s6),
          DropdownButtonFormField<String?>(
            initialValue: _farmerSubType,
            decoration: _fieldDecoration(),
            items: [
              DropdownMenuItem(value: null, child: Text(context.l10n.common_none)),
              ...farmerSubTypes.map((sub) => DropdownMenuItem(value: sub, child: Text(context.l10n.farmerSubTypeLabel(sub)))),
            ],
            onChanged: (val) => setState(() => _farmerSubType = val),
          ),
          if (isCropProducer || isAnimalKeeper) ...[
            const SizedBox(height: AppSpacing.s14),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final item in (isCropProducer ? _selectedCrops : _selectedAnimals))
                  Chip(
                    label: Text(isCropProducer ? context.l10n.cropLabel(item) : context.l10n.animalLabel(item), style: const TextStyle(fontSize: AppFontSize.f12_5)),
                    backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                    deleteIcon: const Icon(Icons.close, size: AppIconSize.i14),
                    onDeleted: () => setState(() {
                      (isCropProducer ? _selectedCrops : _selectedAnimals).remove(item);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: AppIconSize.i16),
                label: Text(isCropProducer ? context.l10n.clients_addCrops : context.l10n.clients_addAnimals),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40)),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                ),
                onPressed: () => _showGroupedMultiSelectDialog(
                  title: isCropProducer ? context.l10n.clients_selectCrops : context.l10n.clients_selectAnimals,
                  groups: isCropProducer ? cropGroups : animalGroups,
                  selected: isCropProducer ? _selectedCrops : _selectedAnimals,
                  groupLabel: isCropProducer ? context.l10n.cropGroupLabel : context.l10n.animalGroupLabel,
                  itemLabel: isCropProducer ? context.l10n.cropLabel : context.l10n.animalLabel,
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
    // What a heading and an item show; [selected] still gets the stored item.
    required String Function(String group) groupLabel,
    required String Function(String item) itemLabel,
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
              // Typed text matches the stored name, as before, or the label shown.
              final matches = entry.value
                  .where((c) => c.toLowerCase().contains(lowerQuery) || itemLabel(c).toLowerCase().contains(lowerQuery))
                  .toList();
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
                        hintText: context.l10n.common_searchEllipsis,
                        prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Expanded(
                      child: filteredGroups.isEmpty
                          ? Center(child: Text(context.l10n.clients_noMatches))
                          : ListView(
                              children: filteredGroups.entries.expand((entry) {
                                return [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s12, AppSpacing.s4, AppSpacing.s4),
                                    child: Text(groupLabel(entry.key),
                                        style: TextStyle(
                                            fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12_5, color: context.colors.primary)),
                                  ),
                                  ...entry.value.map((item) {
                                    final isSelected = selected.contains(item);
                                    return CheckboxListTile(
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      title: Text(itemLabel(item)),
                                      value: isSelected,
                                      activeColor: context.colors.primary,
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
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.common_done)),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.info_outline, context.l10n.clients_additionalDetails),
          const SizedBox(height: AppSpacing.s12),
          if (showVet) ...[
            _fieldLabel(context.l10n.clients_practiceType),
            const SizedBox(height: AppSpacing.s6),
            DropdownButtonFormField<String?>(
              initialValue: _vetPracticeType,
              decoration: _fieldDecoration(),
              items: [
                DropdownMenuItem(value: null, child: Text(context.l10n.common_none)),
                ...vetPracticeTypes.map((v) => DropdownMenuItem(value: v, child: Text(context.l10n.vetPracticeTypeLabel(v)))),
              ],
              onChanged: (val) => setState(() => _vetPracticeType = val),
            ),
            if (showBusiness) const SizedBox(height: AppSpacing.s12),
          ],
          if (showBusiness) ...[
            _fieldLabel(context.l10n.clients_businessName),
            const SizedBox(height: AppSpacing.s6),
            TextFormField(
              initialValue: _businessName,
              decoration: _fieldDecoration(hintText: context.l10n.clients_businessNameHint),
              cursorColor: context.colors.primary,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [SentenceCapitalizationFormatter()],
              onSaved: (val) => _businessName = val?.trim(),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppIconSize.i16),
            label: Text(context.l10n.common_cancel),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a50),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_outlined, size: AppIconSize.i16),
                      const SizedBox(width: AppSpacing.s8),
                      Text(isEditing ? context.l10n.clients_update : context.l10n.clients_save),
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
  final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

  if (!isWideScreen) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddClientScreen(client: client)),
    );
  }

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: client == null ? context.l10n.clients_add : context.l10n.clients_edit,
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      final modalHeight = (screenSize.height * 0.88).clamp(0, 820).toDouble();
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
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
