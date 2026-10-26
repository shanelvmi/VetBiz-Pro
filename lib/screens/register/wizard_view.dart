part of '../register_screen.dart';

// RW2b: the wizard inside the register card (register_wizard.md section 3):
// the header, the step's question, its content, and Back / Continue; and
// step 1. Steps 2 to 4 are in owner_steps.dart, step 5 in review_step.dart.
extension _WizardView on _RegisterScreenState {
  /// Wide (as the login page arranges its side): the welcome panel at the
  /// left of every step. Narrow: the welcome strip on step 1 only (owner
  /// answer 2). [inlineBar]: Back and Continue as the card's bottom row
  /// (on phones they are pinned to the screen instead).
  Widget _buildWizardBody(AuthCardLayout layout, {required bool inlineBar}) {
    final wizard = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardStepHeader(current: _step + 1, total: _WizardFlow.stepCount, title: _stepTitle()),
        const SizedBox(height: WizardMetrics.sectionGap),
        WizardStepIntro(title: _stepQuestion(), subtitle: _stepHint()),
        const SizedBox(height: WizardMetrics.sectionGap),
        ..._stepContent(),
        if (inlineBar) ...[
          const SizedBox(height: WizardMetrics.navTopGap),
          _buildWizardNavBar(pinned: false),
        ],
      ],
    );
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

  // The short name at the right of "Step n of 5".
  String _stepTitle() => switch (_step) {
        0 => context.l10n.register_yourRole,
        1 => context.l10n.register_stepAboutYou,
        2 => context.l10n.register_yourFacilities,
        3 => context.l10n.register_stepSignIn,
        _ => context.l10n.register_stepReview,
      };

  String _stepQuestion() => _step == 0 ? context.l10n.register_stepAccountType(AppInfo.name) : _stepTitle();

  String _stepHint() => switch (_step) {
        0 => context.l10n.register_stepAccountTypeHint,
        1 => context.l10n.register_stepAboutYouHint,
        2 => context.l10n.register_stepFacilityHint,
        3 => context.l10n.register_stepSignInHint,
        _ => context.l10n.register_stepReviewHint,
      };

  List<Widget> _stepContent() => switch (_step) {
        0 => _accountTypeStep(),
        1 => _aboutYouStep(),
        2 => _facilityStep(),
        3 => _signInStep(),
        _ => _reviewStep(),
      };

  // Step 1: the role cards' texts as the two answers. _selectRole is the
  // same as before (choosing the assistant clears its invite fields).
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
      ];
}
