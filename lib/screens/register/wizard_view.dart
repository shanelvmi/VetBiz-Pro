part of '../register_screen.dart';

// RW2b: the wizard inside the register card (register_wizard.md section 3):
// the header, the step's question, its content, and Back / Continue; and
// step 1. Steps 2 to 4 are in owner_steps.dart, step 5 in review_step.dart.
extension _WizardView on _RegisterScreenState {
  /// Wide (as the login page arranges its side): the welcome panel at the
  /// left of every step. Narrow: the welcome strip on step 1 only (owner
  /// answer 2). [inlineBar]: Back and Continue as the card's bottom row
  /// (on phones they are pinned to the screen instead). [flat] (FIN1, the
  /// flat phone page): no welcome strip, the step header and the heading
  /// centred.
  Widget _buildWizardBody(AuthCardLayout layout, {required bool inlineBar, bool flat = false}) {
    final wizard = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardStepHeader(current: _step + 1, total: _WizardFlow.stepCount, title: _stepTitle(), centered: flat),
        const SizedBox(height: WizardMetrics.sectionGap),
        WizardStepIntro(title: _stepQuestion(), subtitle: _stepHint(), centered: flat),
        const SizedBox(height: WizardMetrics.sectionGap),
        ..._stepContent(),
        // RW2b2: the header has no Sign in any more, so when the welcome
        // panel (with its Sign in) is hidden, step 1 offers it.
        if (_step == 0 && !layout.isWide) _signInLink(),
        if (inlineBar) ...[
          const SizedBox(height: WizardMetrics.navTopGap),
          _buildWizardNavBar(pinned: false),
        ],
      ],
    );
    if (flat) return wizard;
    if (layout.isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _RegisterScreenState._welcomePanelWidth, child: _buildWelcomePanel()),
            const SizedBox(width: AppSpacing.s24),
            Expanded(child: wizard),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == 0) ...[
          _buildWelcomeStrip(),
          const SizedBox(height: AppSpacing.s16),
        ],
        wizard,
      ],
    );
  }

  // ==================== PHONE: ONE FLAT PAGE (FIN1) ====================
  // The owner: the treatment LG1 gave the login. No frame, header bar, card
  // or welcome strip: the compact brand row, then the wizard straight on the
  // page's background in one centred column (at most 420 wide, 24 px sides),
  // the footer below. Only the frame changes: the steps, their checks and
  // every call are the card's (_buildWizardBody, flat).
  Widget _buildPhonePage({required bool inlineBar}) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            // At least the screen's height, so the footer reaches the bottom.
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: PhoneLoginMetrics.maxWidth),
                    child: Padding(
                      key: RegisterScreen.phonePageKey,
                      padding: const EdgeInsets.fromLTRB(
                        PhoneLoginMetrics.sidePadding,
                        PhoneLoginMetrics.topPadding,
                        PhoneLoginMetrics.sidePadding,
                        PhoneLoginMetrics.bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPhoneBrandRow(),
                          const SizedBox(height: PhoneLoginMetrics.brandGap),
                          _buildWizardBody(
                            AuthCardLayout(availableWidth: viewport.maxWidth, isWide: false),
                            inlineBar: inlineBar,
                            flat: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const AuthFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The login's phone brand row: the VB mark and the app name at the left,
  // the Light/Dark switch at the right; no bar behind them.
  Widget _buildPhoneBrandRow() {
    return Row(
      key: RegisterScreen.phoneBrandKey,
      children: [
        Container(
          width: PhoneLoginMetrics.mark,
          height: PhoneLoginMetrics.mark,
          decoration: BoxDecoration(color: context.colors.brandSurface, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            AppInfo.logoMark,
            style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14),
          ),
        ),
        const SizedBox(width: PhoneLoginMetrics.markGap),
        Expanded(
          child: Text(
            AppInfo.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.textPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
          ),
        ),
        const AuthThemeToggle(onPage: true),
      ],
    );
  }

  // The short name at the right of "Step n of 5".
  String _stepTitle() => switch (_step) {
        0 => context.l10n.register_yourRole,
        1 => context.l10n.register_stepAboutYou,
        2 => _isAssistant ? context.l10n.register_stepInvite : context.l10n.register_yourFacilities,
        3 => context.l10n.register_stepSignIn,
        _ => context.l10n.register_stepReview,
      };

  String _stepQuestion() => _step == 0 ? context.l10n.register_stepAccountType(AppInfo.name) : _stepTitle();

  String _stepHint() => switch (_step) {
        0 => context.l10n.register_stepAccountTypeHint,
        1 => context.l10n.register_stepAboutYouHint,
        2 => _isAssistant ? context.l10n.register_askAdminForInvite : context.l10n.register_stepFacilityHint,
        3 => context.l10n.register_stepSignInHint,
        _ => context.l10n.register_stepReviewHint,
      };

  List<Widget> _stepContent() => switch (_step) {
        0 => _accountTypeStep(),
        1 => _aboutYouStep(),
        2 => _isAssistant ? _inviteStep() : _facilityStep(),
        3 => _signInStep(),
        _ => _reviewStep(),
      };

  Widget _signInLink() => Padding(
        padding: const EdgeInsets.only(top: WizardMetrics.optionListGap),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s4,
          children: [
            Text(context.l10n.register_alreadyHaveAccount, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13)),
            HoverLink(label: context.l10n.common_logIn, onTap: _goToLogin),
          ],
        ),
      );

  // Step 1: the role cards' texts as the two answers. _selectRole is the
  // same as before (choosing the assistant clears its invite fields); G6:
  // nothing is chosen at first, each card is a toggle, and Continue with
  // none chosen puts the step's error in a line that is always kept (G5),
  // so nothing moves.
  List<Widget> _accountTypeStep() => [
        WizardOptionCard(
          icon: Icons.storefront_outlined,
          title: context.l10n.register_roleAdminSubtitle,
          subtitle: context.l10n.roleLabel(UserRole.admin.key),
          selected: selectedRole == 'Admin',
          onTap: () => _selectRole('Admin'),
        ),
        const SizedBox(height: WizardMetrics.optionListGap),
        WizardOptionCard(
          icon: Icons.groups_outlined,
          title: context.l10n.register_roleAssistantSubtitle,
          subtitle: context.l10n.roleLabel(UserRole.assistant.key),
          selected: selectedRole == 'Assistant',
          onTap: () => _selectRole('Assistant'),
        ),
        const SizedBox(height: AppSpacing.s4),
        FieldMessageSlot(
          message: _fieldErrors.containsKey('role') ? context.l10n.register_chooseAccountType(AppInfo.name) : null,
          reserve: [context.l10n.register_chooseAccountType(AppInfo.name)],
          style: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f12),
        ),
      ];
}
