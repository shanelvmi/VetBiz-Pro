part of '../register_screen.dart';

// RW2b and RW2c: moving through the five steps of either flow
// (register_wizard.md section 2, owner answers 3, 7 and 9). Continue checks
// only its step's fields; nothing reaches the server before Create (but
// the invite check, as the code is typed), which runs the unchanged
// _submitGuarded / _submit once.
extension _WizardFlow on _RegisterScreenState {
  static const int stepCount = 5;
  static const int signInStep = 3;

  /// Step 3 (index 2): the owner's facilities, or the assistant's invite.
  static const int thirdStep = 2;

  bool get _isAssistant => selectedRole == 'Assistant';

  // The _validateAll keys each step owns (steps 1 and 5 own none).
  Map<int, List<String>> get _stepFields => {
        1: const ['name', 'phone'],
        thirdStep: _isAssistant ? const ['invite'] : const ['facility', 'facilityType', 'typeDetail'],
        signInStep: const ['email', 'password', 'confirm'],
      };

  /// The errors to show: in the wizard only those of steps whose Continue
  /// was pressed (nobody is told off for a step not reached yet); Edit
  /// Profile shows them all, as before.
  Map<String, String> _shownErrors(Map<String, String> all) {
    if (widget.isUpdating) return all;
    return {for (final e in all.entries) if (_checkedFields.contains(e.key)) e.key: e.value};
  }

  void _wizardContinue() {
    if (_isSubmitting) return;
    if (_step == stepCount - 1) {
      _createFromReview();
      return;
    }
    final fields = _stepFields[_step] ?? const <String>[];
    _checkedFields.addAll(fields);
    final all = _validateAll();
    final problem = fields.where(all.containsKey).firstOrNull;
    _update(() {
      if (fields.isNotEmpty) {
        _submitAttempted = true;
        _fieldErrors = _shownErrors(all);
      }
      if (problem == null) _step++;
    });
    if (problem == null) _hidePasswords();
    problem == null ? _focusStep() : _focusField(problem);
  }

  /// Back, the back gesture and the browser's Back. Every answer is kept,
  /// the passwords too (in memory only, hidden again: design section 5).
  void _wizardBack() {
    if (_isSubmitting) return;
    if (_step == 0) {
      _goBack();
      return;
    }
    _openStep(_step - 1);
  }

  /// Opens an earlier step (Back, or the review step's Change).
  void _openStep(int step) {
    _hidePasswords();
    _update(() {
      _step = step;
      _consentError = false;
    });
    _focusStep();
  }

  Future<void> _createFromReview() async {
    if (!_consent) {
      _update(() => _consentError = true);
      return;
    }
    // Every step was checked on the way, but a later change (a facility
    // removed after Back) is caught here: open the first step with a problem.
    final all = _validateAll();
    if (all.isNotEmpty) {
      final stepFields = _stepFields;
      stepFields.values.forEach(_checkedFields.addAll);
      final step = stepFields.entries.firstWhere((s) => s.value.any(all.containsKey)).key;
      final field = stepFields[step]!.firstWhere(all.containsKey);
      _update(() {
        _submitAttempted = true;
        _fieldErrors = _shownErrors(all);
        _step = step;
      });
      _focusField(field);
      return;
    }

    final email = emailController.text.trim();
    await _submitGuarded();
    // Success navigates away; _submit cleared `error` first, so a message
    // now means this attempt failed.
    final message = error;
    if (!mounted || message == null) return;
    if (message == L10n.current.register_accountCreatedSignIn) {
      // AccountCreatedException (_submit shows its text as the toast): the
      // account exists, so Sign in, with the email and the same message.
      Navigator.pushReplacementNamed(context, '/login', arguments: LoginPrefill(email: email, message: message));
      return;
    }
    // RW2c: the invite was refused at Create (expired or used meanwhile):
    // its step, with the server's message under the code.
    if (_isAssistant && _fieldErrors.containsKey('invite')) {
      _checkedFields.add('invite');
      _update(() => _step = thirdStep);
      _focusField('invite');
      return;
    }
    // Any other failure emptied both passwords (P1b), so the sign-in step is
    // where to go on; an email problem shows under the email there.
    _checkedFields.addAll(_stepFields[signInStep]!);
    _update(() => _step = signInStep);
    _focusField(_fieldErrors.containsKey('email') ? 'email' : 'password');
  }

  // A step shown again shows the passwords hidden; their values stay in
  // this State only (emptied after a failed Create, P1b, and on leaving).
  void _hidePasswords() {
    _password.hide();
    _confirm.hide();
  }

  FocusNode? _focusOf(String field) => switch (field) {
        'name' => _nameFocus,
        'phone' => _phoneFocus,
        'facility' => _facilityNameFocus,
        'invite' => _inviteFocus,
        'typeDetail' => _facilityTypeDetailFocus,
        'email' => _emailFocus,
        'password' => _password.focusNode,
        'confirm' => _confirm.focusNode,
        _ => null,
      };

  /// A new step: its first empty field takes the focus (none on the
  /// option steps, nor on step 3 once a facility is in the list).
  void _focusStep() {
    final fields = <String, TextEditingController>{
      if (_step == 1) ...{'name': nameController, 'phone': phoneController},
      if (_step == thirdStep && !_isAssistant && facilities.isEmpty) 'facility': facilityNameController,
      if (_step == thirdStep && _isAssistant) 'invite': assistantFacilityCodeController,
      if (_step == signInStep) ...{
        'email': emailController,
        'password': passwordController,
        'confirm': confirmPasswordController,
      },
    };
    final empty = fields.entries.where((f) => f.value.text.trim().isEmpty).firstOrNull;
    if (empty != null) _focusField(empty.key);
  }

  /// After the frame (the step may be new): the field takes the focus and
  /// scrolls into view, as a failed Create account did.
  void _focusField(String field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusOf(field)?.requestFocus();
      final ctx = _fieldKeys[field]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: _RegisterScreenState._scrollToField, curve: Curves.easeOutCubic, alignment: 0.2);
      }
    });
  }

  Widget _buildWizardNavBar({required bool pinned}) {
    return WizardNavBar(
      isFirst: _step == 0,
      isLast: _step == stepCount - 1,
      submitting: _isSubmitting,
      pinned: pinned,
      finishLabel: context.l10n.register_createAccount,
      onBack: _wizardBack,
      onContinue: _wizardContinue,
    );
  }
}
