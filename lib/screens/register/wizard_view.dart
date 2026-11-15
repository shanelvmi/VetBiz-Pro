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
        // UI8: on the phone the step count and the bar are in the tinted
        // strip (_buildPhoneStrip); the step shows its round icon instead.
        if (!flat) ...[
          WizardStepHeader(current: _step + 1, total: _WizardFlow.stepCount, title: _stepTitle()),
          const SizedBox(height: WizardMetrics.sectionGap),
        ],
        WizardStepIntro(title: _stepQuestion(), subtitle: _stepHint(), centered: flat, icon: flat ? _stepIcon().outlined : null),
        const SizedBox(height: WizardMetrics.sectionGap),
        ..._stepContent(),
        // RW2b2: the header has no Sign in any more, so when the welcome
        // panel (with its Sign in) is hidden, step 1 offers it. UI8: the
        // phone page offers it under every step instead (below).
        if (_step == 0 && !layout.isWide && !flat) _signInLink(),
        if (inlineBar) ...[
          const SizedBox(height: WizardMetrics.navTopGap),
          _buildWizardNavBar(pinned: false),
        ],
        if (flat) ...[
          const SizedBox(height: WizardMetrics.sectionGap),
          _signInLink(),
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

  // ==================== PHONE: A TINTED STRIP AND THE STEP (UI8) ====================
  // FIN1 gave phones the treatment LG1 gave the login: no frame, header bar,
  // card or welcome strip, the wizard straight on the page's background in
  // one centred column (at most 420 wide, 24 px sides). UI8 (owner): a slim
  // tinted strip at the top ("Step n of 5", the five-part bar; EN | SW,
  // Light/Dark and Help), each step under its round icon, Sign in at the
  // bottom, and no footer (Help opens its links in a sheet). Only the frame
  // changes: the steps, their checks and every call are the card's
  // (_buildWizardBody, flat).
  Widget _buildPhonePage({required bool inlineBar}) {
    // A phone held sideways is short: there the strip scrolls away with the
    // step, so the pinned Continue bar and the strip do not leave the step a
    // sliver between them.
    final pinStrip = MediaQuery.sizeOf(context).height >= AppBreakpoints.phoneLandscapeHeight;
    Widget page(double width) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PhoneLoginMetrics.maxWidth),
            child: Padding(
              key: RegisterScreen.phonePageKey,
              padding: const EdgeInsets.fromLTRB(
                PhoneLoginMetrics.sidePadding,
                AuthPhoneMetrics.contentTop,
                PhoneLoginMetrics.sidePadding,
                PhoneLoginMetrics.bottomPadding,
              ),
              child: _buildWizardBody(
                AuthCardLayout(availableWidth: width, isWide: false),
                inlineBar: inlineBar,
                flat: true,
              ),
            ),
          ),
        );
    if (!pinStrip) {
      return LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildPhoneStrip(), SafeArea(top: false, child: page(viewport.maxWidth))],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhoneStrip(),
        Expanded(
          child: SafeArea(
            top: false,
            child: LayoutBuilder(builder: (context, viewport) => SingleChildScrollView(child: page(viewport.maxWidth))),
          ),
        ),
      ],
    );
  }

  // The step header in the tinted strip, with the controls at its right.
  Widget _buildPhoneStrip() {
    return AuthPhoneTint(
      key: RegisterScreen.phoneBrandKey,
      padding: const EdgeInsets.fromLTRB(
        AuthPhoneMetrics.headerPaddingH,
        AuthPhoneMetrics.stripPaddingV,
        AuthPhoneMetrics.headerPaddingH,
        AuthPhoneMetrics.headerPaddingTop,
      ),
      child: WizardStepHeader(
        current: _step + 1,
        total: _WizardFlow.stepCount,
        title: _stepTitle(),
        strip: true,
        trailing: AuthPhoneControls(onHelp: () => showAuthHelpSheet(context)),
      ),
    );
  }

  // UI8: the round icon of each step on the phone.
  AppIcon _stepIcon() => switch (_step) {
        0 => AppIcons.stepRole,
        1 => AppIcons.stepAboutYou,
        2 => _isAssistant ? AppIcons.stepInvite : AppIcons.stepFacility,
        3 => AppIcons.stepSignIn,
        _ => AppIcons.stepReview,
      };

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
  // UI8, the phone: the larger cards, and the assistant card SHOWS
  // register_roleStaffAssistant; the stored value stays 'Assistant'.
  List<Widget> _accountTypeStep() {
    final phone = AppLayout.isPhone(context);
    return [
      WizardOptionCard(
        icon: Icons.storefront_outlined,
        title: context.l10n.register_roleAdminSubtitle,
        subtitle: context.l10n.roleLabel(UserRole.admin.key),
        selected: selectedRole == 'Admin',
        onTap: () => _selectRole('Admin'),
        large: phone,
      ),
      const SizedBox(height: WizardMetrics.optionListGap),
      WizardOptionCard(
        icon: Icons.groups_outlined,
        title: context.l10n.register_roleAssistantSubtitle,
        subtitle: phone ? context.l10n.register_roleStaffAssistant : context.l10n.roleLabel(UserRole.assistant.key),
        selected: selectedRole == 'Assistant',
        onTap: () => _selectRole('Assistant'),
        large: phone,
      ),
      const SizedBox(height: AppSpacing.s4),
      FieldMessageSlot(
        message: _fieldErrors.containsKey('role') ? context.l10n.register_chooseAccountType(AppInfo.name) : null,
        reserve: [context.l10n.register_chooseAccountType(AppInfo.name)],
        style: TextStyle(color: context.colors.dangerDeep, fontSize: AppFontSize.f12),
      ),
    ];
  }
}
