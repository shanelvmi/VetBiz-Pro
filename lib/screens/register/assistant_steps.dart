part of '../register_screen.dart';

// RW2c: the assistant's step 3, the invite code (register_wizard.md
// section 2). Moved from the one-page form's invite section: the same
// as-typed check (_onFacilityCodeChanged, debounced, the server's limit of
// 5 wrong codes in 15 minutes) and the same messages. Steps 1, 2, 4 and 5
// are shared with the owner.
extension _AssistantSteps on _RegisterScreenState {
  List<Widget> _inviteStep() {
    // Once a valid code has been found any earlier complaint is moot.
    final inviteError = _foundFacility != null ? null : _fieldErrors['invite'];

    return [
      _labeled(
        context.l10n.common_inviteCode,
        TextField(
          key: const ValueKey<String>('register-invite'),
          controller: assistantFacilityCodeController,
          focusNode: _inviteFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _wizardContinue(),
          onChanged: (value) {
            _onFacilityCodeChanged(value);
            _onFieldChanged();
          },
          decoration: _decoration(
            hint: context.l10n.register_enterInviteCode,
            icon: Icons.vpn_key_outlined,
            errorText: inviteError,
            reserve: _messagesOf('invite'),
            suffix: _isLookingUpFacility
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.s12),
                    child: SizedBox(width: AppSpacing.s16, height: AppSpacing.s16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_foundFacility != null ? Icon(Icons.check_circle, color: context.colors.success) : null),
          ),
        ),
        fieldKey: _fieldKeys['invite'],
      ),
      const SizedBox(height: AppSpacing.s10),
      if (_foundFacility != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: context.colors.success.withValues(alpha: AppAlpha.a10),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.success.withValues(alpha: AppAlpha.a30)),
          ),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, color: context.colors.success, size: AppIconSize.i18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  // FN1: the name exactly as typed, never with its type.
                  context.l10n.register_joining(FacilityDisplay.name(_foundFacility!['name'] as String?)),
                  style: TextStyle(color: context.colors.success, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13),
                ),
              ),
            ],
          ),
        )
      // Not shown twice: once Continue has been pressed the same message is
      // already on the field itself.
      else if (_facilityLookupError != null && inviteError == null)
        Text(_facilityLookupError!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
    ];
  }
}
