part of '../register_screen.dart';

// RW2b: the owner's steps 2 to 4 (register_wizard.md section 2). The fields
// are the controllers and checks of the one-page form; only the
// arrangement is new.
extension _OwnerSteps on _RegisterScreenState {
  Widget _gap(double height) => SizedBox(height: height);

  // Step 2: photo (optional), the title as chips (stored as typed, so
  // they show the stored value), full name, phone.
  List<Widget> _aboutYouStep() => [
        _buildAvatarPicker(),
        _gap(WizardMetrics.fieldGap),
        _labeled(
          context.l10n.register_title,
          Wrap(
            spacing: WizardMetrics.optionListGap,
            runSpacing: WizardMetrics.optionListGap,
            children: [
              for (final prefix in prefixes)
                ChoiceChip(
                  label: Text(prefix),
                  selected: selectedPrefix == prefix,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => _update(() => selectedPrefix = prefix),
                ),
            ],
          ),
        ),
        _gap(WizardMetrics.fieldGap),
        _labeled(
          context.l10n.register_fieldFullName,
          TextField(
            key: const ValueKey<String>('register-name'),
            controller: nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: context.l10n.register_enterFullName,
              icon: Icons.person_outline,
              errorText: _fieldErrors['name'],
            ),
          ),
          fieldKey: _fieldKeys['name'],
        ),
        _gap(WizardMetrics.fieldGap),
        _labeled(
          context.l10n.register_fieldPhone,
          TextField(
            key: const ValueKey<String>('register-phone'),
            controller: phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _wizardContinue(),
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: context.l10n.register_phoneHint,
              icon: Icons.phone_outlined,
              errorText: _fieldErrors['phone'],
            ),
          ),
          fieldKey: _fieldKeys['phone'],
        ),
      ];

  // Step 3: the facilities added so far (with remove), the limit, then a
  // name, its type (the shared dropdown, empty until chosen, with Other's
  // own words: RW2b2), and Add (addFacility, as before).
  List<Widget> _facilityStep() {
    final atLimit = facilities.length >= _maxFacilities;
    final facilityError = facilities.isEmpty ? _fieldErrors['facility'] : null;
    return [
      for (var i = 0; i < facilities.length; i++) _facilityTile(i),
      if (facilityError != null) _facilityErrorBox(facilityError),
      Text(
        context.l10n.register_facilitiesAdded(facilities.length, _maxFacilities),
        style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
      ),
      _gap(WizardMetrics.fieldGap),
      _labeled(
        context.l10n.common_facilityName,
        TextField(
          key: const ValueKey<String>('register-facility-name'),
          controller: facilityNameController,
          focusNode: _facilityNameFocus,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [SentenceCapitalizationFormatter()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _wizardContinue(),
          onChanged: (_) => _onFieldChanged(),
          // FN1: printed exactly as typed, never with its type.
          decoration: _decoration(hint: context.l10n.common_facilityNameHint, icon: Icons.storefront_outlined, helper: context.l10n.facilities_nameHelper),
        ),
      ),
      _gap(WizardMetrics.fieldGap),
      KeyedSubtree(key: _fieldKeys['facilityType'], child: _facilityTypeField(gap: WizardMetrics.fieldGap)),
      _gap(WizardMetrics.fieldGap),
      Tooltip(
        message: atLimit ? context.l10n.register_maxFacilitiesReached(_maxFacilities) : '',
        child: ElevatedButton.icon(
          onPressed: (_isAddingFacility || atLimit) ? null : addFacility,
          icon: _isAddingFacility
              ? const SizedBox(width: AppSpacing.s16, height: AppSpacing.s16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add, size: AppIconSize.i18),
          label: Text(context.l10n.common_add),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.accent,
            foregroundColor: context.colors.onAccent,
            disabledBackgroundColor: context.colors.divider,
            elevation: AppElevation.e0,
            minimumSize: const Size.fromHeight(WizardMetrics.buttonHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WizardMetrics.buttonRadius)),
          ),
        ),
      ),
    ];
  }

  /// The type and an Other facility's words, shared by step 3 and the old
  /// one-page form. Another type drops words typed for Other.
  Widget _facilityTypeField({required double gap}) => FacilityTypeField(
        dropdownKey: const ValueKey<String>('register-facility-type'),
        detailKey: const ValueKey<String>('register-facility-type-detail'),
        type: _selectedFacilityType,
        onTypeChanged: (value) {
          _update(() {
            _selectedFacilityType = value;
            if (value != kFacilityTypeOther) facilityTypeDetailController.clear();
          });
          _onFieldChanged();
        },
        detailController: facilityTypeDetailController,
        detailFocusNode: _facilityTypeDetailFocus,
        typeDecoration: _decoration(hint: '', icon: Icons.category_outlined),
        detailDecoration: _decoration(hint: context.l10n.facilityType_detailLabel, icon: Icons.edit_outlined),
        typeError: _fieldErrors['facilityType'],
        detailError: _fieldErrors['typeDetail'],
        labeled: (label, field) => _labeled(label, field),
        gap: gap,
        detailAction: TextInputAction.done,
        onDetailChanged: (_) => _onFieldChanged(),
        onDetailSubmitted: (_) => _wizardContinue(),
      );

  // Step 4: email, password, confirm (the P1b guards come with them).
  List<Widget> _signInStep() => [
        _labeled(
          context.l10n.common_email,
          TextField(
            key: const ValueKey<String>('register-email'),
            controller: emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _onFieldChanged(),
            decoration: _decoration(
              hint: context.l10n.register_emailHint,
              icon: Icons.mail_outline,
              errorText: _fieldErrors['email'],
            ),
          ),
          fieldKey: _fieldKeys['email'],
        ),
        _gap(WizardMetrics.fieldGap),
        _labeled(
          context.l10n.common_password,
          _passwordInput(key: const ValueKey<String>('register-password'), action: TextInputAction.next),
          fieldKey: _fieldKeys['password'],
        ),
        _gap(WizardMetrics.fieldGap),
        _labeled(
          context.l10n.register_fieldConfirmPassword,
          _confirmInput(
            key: const ValueKey<String>('register-confirm'),
            action: TextInputAction.done,
            onSubmitted: (_) => _wizardContinue(),
          ),
          fieldKey: _fieldKeys['confirm'],
        ),
      ];
}
