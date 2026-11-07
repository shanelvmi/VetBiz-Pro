import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/restock_rules.dart';
import '../../constants/facility_types.dart';
import '../../data/facility_ownership.dart';
import '../../data/facility_status.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import '../../widgets/facility_type_field.dart';
import '../../widgets/phone_form/form_action_bar.dart';
import '../../widgets/phone_form/phone_discard_scope.dart';
import 'facility_form_input.dart';
import 'facility_logo_field.dart';

/// PH8b-2 P3 (docs/design/phone_facilities.md): Add and Edit Facility on a
/// phone, the PH6 form shell as a full page: one column, today's fields in
/// today's order with today's validators, FormActionBar (Cancel, Add or
/// Save) pinned and lifted over the keyboard, and PhoneDiscardScope asking
/// before a typed form is left. Tablets and computers keep the dialogs.
class FacilityPhoneForm extends StatefulWidget {
  /// Edit's facility (its list entry) and stored details; null for Add.
  final Map<String, dynamic>? facility;
  final Map<String, dynamic>? details;
  final Map<String, String?>? contact;
  final String? existingLogoUrl;

  /// Today's picking path (the picker, then UploadSizeCheck): null when
  /// nothing was picked or the photo was refused.
  final Future<Uint8List?> Function() pickLogo;

  /// Saves; throws what the save threw, shown through [errorFor].
  final Future<void> Function(FacilityFormInput input) onSave;
  final String Function(Object error) errorFor;

  const FacilityPhoneForm({
    super.key,
    this.facility,
    this.details,
    this.contact,
    this.existingLogoUrl,
    required this.pickLogo,
    required this.onSave,
    required this.errorFor,
  });

  bool get isEdit => facility != null;

  /// Edit's text fields by their stored name, in today's order.
  static const editTexts = ['email', 'phone', 'address', 'description', 'tagline', 'licenseNo', 'tin'];

  @override
  State<FacilityPhoneForm> createState() => _FacilityPhoneFormState();
}

class _FacilityPhoneFormState extends State<FacilityPhoneForm> {
  late final TextEditingController _name = TextEditingController(text: widget.facility?['name'] as String? ?? '');
  late final TextEditingController _typeDetail = TextEditingController(text: widget.facility?['typeDetail'] as String? ?? '');
  late final _texts = {for (final f in FacilityPhoneForm.editTexts) f: TextEditingController(text: _stored(f) ?? '')};
  // Email and phone are the contact's; the rest the facility's details.
  String? _stored(String field) =>
      field == 'email' || field == 'phone' ? (widget.contact?[field]) : (widget.details?[field] as String?);
  late String? _type = widget.facility?['type'] as String?;
  late String? _ownership = widget.details?['ownership'] as String?;
  late String _status = widget.details?['status'] as String? ?? FacilityStatus.active.key;
  late String _restock = widget.details?['restockFrequency'] as String? ?? RestockRules.defaultFrequency;
  late final List<Object?> _initial;

  Uint8List? _logoBytes;
  // Kept apart from "no change": only an explicit removal deletes the logo.
  bool _removeLogo = false;
  bool _busy = false;
  String? _typeError;
  String? _detailError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
  }

  @override
  void dispose() {
    _name.dispose();
    _typeDetail.dispose();
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Object?> _snapshot() =>
      [_name.text, _typeDetail.text, for (final c in _texts.values) c.text, _type, _ownership, _status, _restock];

  bool _isDirty() {
    if (_logoBytes != null || _removeLogo) return true;
    return !listEquals(_snapshot(), _initial);
  }

  Future<void> _pick() async {
    final bytes = await widget.pickLogo();
    if (bytes == null || !mounted) return;
    // A new logo replaces the old one: any pending removal is cancelled.
    setState(() {
      _logoBytes = bytes;
      _removeLogo = false;
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    // Edit accepts only a known stored type, as the dialog does.
    final type = widget.isEdit ? (kFacilityTypes.contains(_type) ? _type : null) : _type;
    final detailIssue = FacilityTypeField.detailErrorFor(type, _typeDetail.text, l10n);
    if (name.isEmpty || type == null || detailIssue != null) {
      setState(() {
        _error = name.isEmpty ? l10n.facilities_nameAndTypeRequired : null;
        _typeError = FacilityTypeField.typeErrorFor(type, l10n);
        _detailError = detailIssue;
      });
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await widget.onSave(FacilityFormInput(
        name: name,
        type: type,
        typeDetail: _typeDetail.text,
        logoBytes: _logoBytes,
        removeLogo: _removeLogo,
        texts: {for (final e in _texts.entries) e.key: e.value.text},
        ownership: _ownership,
        status: _status,
        restockFrequency: _restock,
      ));
      // A save leaves without asking (pop, not maybePop).
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = widget.errorFor(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    const gap = SizedBox(height: AppSpacing.s12);
    TextField text(String field, String label, {String? hint, TextInputType? keyboard, int maxLines = 1, bool sentences = true}) =>
        TextField(
          controller: _texts[field],
          enabled: !_busy,
          keyboardType: keyboard,
          maxLines: maxLines,
          textCapitalization: sentences ? TextCapitalization.sentences : TextCapitalization.none,
          inputFormatters: sentences ? [SentenceCapitalizationFormatter()] : null,
          decoration: InputDecoration(labelText: label, hintText: hint),
        );

    final fields = <Widget>[
      FacilityLogoField(
        isEdit: widget.isEdit,
        bytes: _logoBytes,
        existingUrl: widget.existingLogoUrl,
        removed: _removeLogo,
        onPick: _busy ? null : _pick,
        onRemove: _busy
            ? null
            : () => setState(() {
                  _logoBytes = null;
                  _removeLogo = true;
                }),
      ),
      const SizedBox(height: AppSpacing.s16),
      TextField(
        controller: _name,
        enabled: !_busy,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [SentenceCapitalizationFormatter()],
        decoration: InputDecoration(
          labelText: l10n.common_facilityName,
          hintText: l10n.common_facilityNameHint,
          // FN1: printed exactly as typed, never with its type.
          helperText: l10n.facilities_nameHelper,
          helperMaxLines: 2,
        ),
      ),
      gap,
      FacilityTypeField(
        type: _type,
        enabled: !_busy,
        onTypeChanged: (val) => setState(() {
          _type = val;
          _typeError = null;
          _detailError = null;
          if (val != kFacilityTypeOther) _typeDetail.clear();
        }),
        detailController: _typeDetail,
        typeDecoration: InputDecoration(labelText: l10n.facilities_typeOfFacility),
        typeError: _typeError,
        detailError: _detailError,
      ),
      if (widget.isEdit) ...[
        gap,
        text('email', l10n.facilities_businessEmailOptional, keyboard: TextInputType.emailAddress, sentences: false),
        gap,
        text('phone', l10n.facilities_businessPhoneOptional, keyboard: TextInputType.phone, sentences: false),
        gap,
        text('address', l10n.facilities_addressOptional),
        gap,
        text('description', l10n.facilities_descriptionOptional, maxLines: 3),
        gap,
        text('tagline', l10n.facilities_taglineOptional, hint: l10n.facilities_taglineHint),
        gap,
        text('licenseNo', l10n.facilities_licenseOptional, sentences: false),
        gap,
        text('tin', l10n.facilities_tinOptional, hint: l10n.facilities_tinHint, sentences: false),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _ownership,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.facilities_ownershipOptional),
          // Shows the label; the facility stores the English value.
          items: [
            for (final o in FacilityOwnership.values) DropdownMenuItem(value: o, child: Text(l10n.facilityOwnershipLabel(o))),
          ],
          onChanged: _busy ? null : (val) => setState(() => _ownership = val),
        ),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _status,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.common_status),
          items: [
            for (final s in [FacilityStatus.active.key, FacilityStatus.inactive.key])
              DropdownMenuItem(value: s, child: Text(l10n.facilityStatusLabel(s))),
          ],
          onChanged: _busy ? null : (val) => setState(() => _status = val ?? _status),
        ),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _restock,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.facilities_restockQuestion,
            helperText: l10n.facilities_restockHelper,
            helperMaxLines: 2,
          ),
          // Shows the label; the facility stores the frequency name.
          items: [
            for (final f in RestockRules.frequencies)
              DropdownMenuItem(value: f, child: Text(l10n.restockFrequencyLabel(f), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _busy ? null : (val) => setState(() => _restock = val ?? _restock),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.s8),
        Text(_error!, style: TextStyle(color: colors.dangerAccent, fontSize: PhoneFormMetrics.error)),
      ],
    ];

    return PhoneDiscardScope(
      kind: 'other',
      isDirty: _isDirty,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: Text(widget.isEdit ? l10n.facilities_editTitle : l10n.facilities_addTitle)),
        body: closeKeyboardOnTapOutside(
          context,
          SingleChildScrollView(
            padding: const EdgeInsets.all(PhoneListMetrics.pagePadding),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
          ),
        ),
        bottomNavigationBar: FormActionBar(
          primaryLabel: widget.isEdit ? l10n.common_save : l10n.common_add,
          onPrimary: _save,
          busy: _busy,
          secondaryLabel: l10n.common_cancel,
          onSecondary: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
