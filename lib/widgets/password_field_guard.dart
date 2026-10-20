import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../config/app_timeouts.dart';

/// One password field's text, focus and eye, with the same hygiene rules for
/// every password field in the app (P1b). The owner found that after a
/// failed sign-in the password stayed in the field, readable if the eye had
/// been opened, for anyone walking up to an unattended screen.
///
/// The eye closes by itself when the app goes to the background or loses
/// the window (any lifecycle state but resumed), when the field loses
/// focus, and [revealFor] after it was opened. The screen rebuilds on
/// [addListener] and reads [obscured] for its TextField.
class PasswordFieldGuard extends ChangeNotifier with WidgetsBindingObserver {
  PasswordFieldGuard({this.revealFor = AppTimeouts.passwordReveal}) {
    focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final Duration revealFor;

  bool _obscured = true;
  Timer? _hideTimer;

  bool get obscured => _obscured;

  /// The eye button.
  void toggle() => _obscured ? reveal() : hide();

  void reveal() {
    _hideTimer?.cancel();
    _hideTimer = Timer(revealFor, hide);
    if (!_obscured) return;
    _obscured = false;
    notifyListeners();
  }

  void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_obscured) return;
    _obscured = true;
    notifyListeners();
  }

  void clearAndHide() {
    controller.clear();
    hide();
  }

  /// What a failed sign-in or re-authentication does to the field: hidden
  /// again always; also emptied when Firebase actually rejected the attempt
  /// (see [rejectedAttempt]). Returns whether it was emptied.
  bool afterFailedAttempt(Object error) {
    if (rejectedAttempt(error)) {
      clearAndHide();
      return true;
    }
    hide();
    return false;
  }

  /// Whether Firebase tried the password and refused it (or refused to try
  /// any more): the typed password has done its job and must not stay on
  /// screen. A network or unknown error, or a malformed email, made no real
  /// attempt, so the person keeps what they typed to try again.
  static bool rejectedAttempt(Object error) =>
      error is FirebaseAuthException && _rejectedCodes.contains(error.code);

  static const Set<String> _rejectedCodes = {
    'invalid-credential',
    'user-not-found',
    'wrong-password',
    'user-disabled',
    'too-many-requests',
  };

  void _onFocusChange() {
    if (!focusNode.hasFocus) hide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) hide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    controller.dispose();
    super.dispose();
  }
}
