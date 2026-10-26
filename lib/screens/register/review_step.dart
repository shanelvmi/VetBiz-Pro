part of '../register_screen.dart';

// RW2b: step 5, "Check and create" (register_wizard.md section 2, owner
// answers 1 and 5): what each step holds, with Change to open it, then the
// required "I agree" box. Create account (the nav bar's last label) runs
// the unchanged submit.
extension _ReviewStep on _RegisterScreenState {
  List<Widget> _reviewStep() {
    final l10n = context.l10n;
    final terms = l10n.common_termsOfService;
    final privacy = l10n.common_privacyPolicy;
    return [
      _reviewBox(l10n.register_yourRole, [l10n.register_roleAdminSubtitle], step: 0),
      // The full name exactly as _submit builds it.
      _reviewBox(l10n.register_stepAboutYou, ['$selectedPrefix ${nameController.text.trim()}', phoneController.text.trim()], step: 1),
      _reviewBox(
        l10n.register_yourFacilities,
        [for (final f in facilities) '${f['name'] ?? ''} (${l10n.facilityTypeLabel(f['type'] ?? '')})'],
        step: 2,
      ),
      _reviewBox(l10n.register_stepSignIn, [emailController.text.trim()], step: _WizardFlow.signInStep),
      const SizedBox(height: WizardMetrics.sectionGap),
      WizardConsentRow(
        value: _consent,
        onChanged: (ticked) => _update(() {
          _consent = ticked;
          if (ticked) _consentError = false;
        }),
        text: l10n.register_consent(terms, privacy),
        links: [
          WizardLink(label: terms, onTap: () => _openLegal(const TermsOfServiceScreen())),
          WizardLink(label: privacy, onTap: () => _openLegal(const PrivacyPolicyScreen())),
        ],
        errorText: _consentError ? l10n.register_consentRequired : null,
      ),
    ];
  }

  void _openLegal(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Widget _reviewBox(String title, List<String> lines, {required int step}) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: WizardMetrics.reviewGap),
      padding: const EdgeInsetsDirectional.only(start: WizardMetrics.reviewPadding, top: WizardMetrics.reviewPadding, bottom: WizardMetrics.reviewPadding),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(WizardMetrics.reviewRadius),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: WizardFontSize.reviewLabel, fontWeight: AppFontWeight.semibold, color: colors.textMuted),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: WizardMetrics.reviewLineGap),
                  Text(line, style: TextStyle(fontSize: WizardFontSize.reviewValue, color: colors.textPrimary)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openStep(step),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              minimumSize: const Size(WizardMetrics.buttonHeight, WizardMetrics.buttonHeight),
            ),
            child: Text(context.l10n.common_change),
          ),
        ],
      ),
    );
  }
}
