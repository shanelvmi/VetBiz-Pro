import 'package:flutter/material.dart';

import '../config/app_limits.dart';
import '../constants/facility_types.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';

/// The facility type as every form offers it (RW2b2): registration's step 3,
/// Add and Edit facility, and the no-facility page. A dropdown that starts
/// empty with "Select facility type"; choosing Other opens a required field
/// for the owner's own words (typeDetail). The dropdown saves and compares
/// the stored type ("Ambulatory Vet"), showing its label.
///
/// The caller keeps the state (the type and the words' controller) and
/// decides when to check them, with [typeError] and [detailError].
class FacilityTypeField extends StatelessWidget {
  const FacilityTypeField({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.detailController,
    this.typeDecoration = const InputDecoration(),
    this.detailDecoration = const InputDecoration(),
    this.typeError,
    this.detailError,
    this.labeled,
    this.dropdownKey,
    this.detailKey,
    this.detailFocusNode,
    this.detailAction,
    this.onDetailChanged,
    this.onDetailSubmitted,
    this.gap = AppSpacing.s12,
    this.enabled = true,
  });

  /// The stored type chosen, or null (nothing yet).
  final String? type;
  final ValueChanged<String?> onTypeChanged;
  final TextEditingController detailController;

  /// The caller's look for the two fields; the errors are added here.
  final InputDecoration typeDecoration;
  final InputDecoration detailDecoration;
  final String? typeError;
  final String? detailError;

  /// Puts a label above a field (registration's style). Without it the
  /// words' field carries its label inside, as the dialogs' fields do.
  final Widget Function(String label, Widget field)? labeled;
  final Key? dropdownKey;
  final Key? detailKey;
  final FocusNode? detailFocusNode;
  final TextInputAction? detailAction;
  final ValueChanged<String>? onDetailChanged;
  final ValueChanged<String>? onDetailSubmitted;
  final double gap;
  final bool enabled;

  /// "Choose your facility type" while nothing is chosen.
  static String? typeErrorFor(String? type, AppLocalizations l10n) => type == null ? l10n.facilityType_required : null;

  /// What is wrong with the words, only when the type is Other.
  static String? detailErrorFor(String? type, String typed, AppLocalizations l10n) {
    if (type != kFacilityTypeOther) return null;
    return switch (typeDetailIssue(typed)) {
      TypeDetailIssue.required => l10n.facilityType_detailLabel,
      TypeDetailIssue.length => l10n.facilityType_detailLength(AppLimits.typeDetailMin, AppLimits.typeDetailMax),
      TypeDetailIssue.characters => l10n.facilityType_detailCharacters,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dropdown = KeyedSubtree(
      key: dropdownKey,
      child: DropdownButtonFormField<String>(
        // initialValue only applies when the field is first built, so a
        // type reset by the caller (after Add) kept SHOWING the old one; a
        // key that follows the type rebuilds the field with it.
        key: ValueKey<String?>('facility-type-$type'),
        initialValue: type,
        isExpanded: true,
        hint: Text(l10n.facilityType_selectHint, overflow: TextOverflow.ellipsis),
        decoration: typeDecoration.copyWith(errorText: typeError),
        items: [
          for (final t in kFacilityTypes)
            DropdownMenuItem(value: t, child: Text(l10n.facilityTypeLabel(t), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: enabled ? onTypeChanged : null,
      ),
    );
    if (type != kFacilityTypeOther) return labeled?.call(l10n.common_type, dropdown) ?? dropdown;

    final detail = TextField(
      key: detailKey,
      controller: detailController,
      focusNode: detailFocusNode,
      enabled: enabled,
      // No maxLength: it would cut the words silently; the error says why.
      textCapitalization: TextCapitalization.sentences,
      textInputAction: detailAction,
      onChanged: onDetailChanged,
      onSubmitted: onDetailSubmitted,
      decoration: detailDecoration.copyWith(
        labelText: labeled == null ? l10n.facilityType_detailLabel : detailDecoration.labelText,
        errorText: detailError,
        // Long Kiswahili errors wrap instead of running off a phone.
        errorMaxLines: 3,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labeled?.call(l10n.common_type, dropdown) ?? dropdown,
        SizedBox(height: gap),
        labeled?.call(l10n.facilityType_detailLabel, detail) ?? detail,
      ],
    );
  }
}
