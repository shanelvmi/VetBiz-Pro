part of '../register_screen.dart';

// RW2b: the owner's steps 2 to 4 (register_wizard.md section 2). The fields
// are the controllers and checks of the one-page form; only the
// arrangement is new.
extension _OwnerSteps on _RegisterScreenState {
  Widget _gap(double height) => SizedBox(height: height);

  // Step 2: photo (optional), the title as chips (stored as typed, so
  // they show the stored value), full name, phone.
  // Temporary until the wizard view uses it (RW2b, next commit).
  // ignore: unused_element
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
  // name, its type as option cards, and Add (addFacility, as before).
  // Temporary until the wizard view uses it (RW2b, next commit).
  // ignore: unused_element
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
          decoration: _decoration(hint: context.l10n.common_facilityNameHint, icon: Icons.storefront_outlined),
        ),
      ),
      _gap(WizardMetrics.fieldGap),
      _fieldLabel(context.l10n.common_type),
      _gap(AppSpacing.s6),
      for (final type in kFacilityTypes) ...[
        WizardOptionCard(
          title: context.l10n.facilityTypeLabel(type),
          selected: _selectedFacilityType == type,
          onTap: () {
            _update(() => _selectedFacilityType = type);
            _onFieldChanged();
          },
        ),
        _gap(WizardMetrics.optionListGap),
      ],
      _gap(AppSpacing.s6),
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

  // Step 4: email, password, confirm (the P1b guards come with them).
  // Temporary until the wizard view uses it (RW2b, next commit).
  // ignore: unused_element
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
