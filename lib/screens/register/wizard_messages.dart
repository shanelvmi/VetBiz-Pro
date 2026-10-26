part of '../register_screen.dart';

// G5: the messages each wizard field can show under it, so its line under
// the field is kept as tall as the longest (FieldMessageSlot).
extension _WizardMessages on _RegisterScreenState {
  /// G5: every message a wizard field can show under it (its helper, the
  /// live checks and _validateAll's errors), so its line is kept as tall as
  /// the longest of them and an error never moves the card. Keep in step
  /// with _validateAll. A message not listed here (the server's) still
  /// shows, at most two lines.
  List<String> _messagesOf(String field) {
    final l10n = context.l10n;
    return switch (field) {
      'name' => [l10n.register_enterFullName, l10n.register_nameTooShort],
      'phone' => [l10n.register_enterPhone, l10n.register_validPhone],
      'facility' => [
          l10n.facilities_nameHelper,
          l10n.register_addOneFacilityHow,
          l10n.register_chooseTypeThenAdd,
          l10n.register_pressAddToInclude(facilityNameController.text.trim()),
        ],
      'facilityType' => [l10n.facilityType_required],
      'typeDetail' => [
          l10n.facilityType_detailLabel,
          l10n.facilityType_detailLength(AppLimits.typeDetailMin, AppLimits.typeDetailMax),
          l10n.facilityType_detailCharacters,
        ],
      'invite' => [
          l10n.register_enterInviteCode,
          l10n.register_stillChecking,
          l10n.register_enterValidInvite,
          l10n.register_inviteInvalid,
          l10n.register_inviteCheckFailed,
        ],
      'email' => [l10n.register_enterEmail, l10n.register_validEmailExample],
      'password' => [
          l10n.register_passwordRule,
          l10n.register_looksGood,
          l10n.register_createPassword,
          l10n.register_pwMin8,
          l10n.register_pwNeedsLetter,
          l10n.register_pwNeedsNumber,
          l10n.register_pwTooCommon,
        ],
      'confirm' => [l10n.register_reenterToConfirm, l10n.common_passwordsDoNotMatch, l10n.register_passwordsMatch],
      _ => const [],
    };
  }
}
