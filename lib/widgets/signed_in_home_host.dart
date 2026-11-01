import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../utils/navigator_key.dart';

/// PH3 root fix (docs/design/phone_shell.md section 1, the owner's answer 1):
/// AppEntryPoint, the app's first and only base route, SHOWS the signed-in
/// home (the dashboard) itself instead of pushing it as a second route. So a
/// signed-in stack holds one route: Back on Home has nothing to pop and
/// leaves the app or the page as the platform does, instead of uncovering the
/// sign-in decision screen while still signed in.
///
/// AppEntryPoint stays alive the whole time (it must: it is the one thing
/// that reacts to the next sign-in, see force_logout.dart), and it still owns
/// every decision. This only holds the home it was handed.
class SignedInHomeHost extends StatefulWidget {
  /// The signed-in user, or null when nobody is. The home is dropped when
  /// this changes (signed out, or another account).
  final String? signedInUid;

  /// AppEntryPoint's own screens (connecting, login, the decision).
  final Widget child;

  const SignedInHomeHost({super.key, required this.signedInUid, required this.child});

  @override
  State<SignedInHomeHost> createState() => _SignedInHomeHostState();
}

class _SignedInHomeHostState extends State<SignedInHomeHost> {
  Widget? _home;
  // A new key for each home handed in, so opening a facility (or System
  // Refresh) always starts a fresh dashboard, as the old pushed route did.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    showSignedInHome = _show;
    clearSignedInHome = _clear;
  }

  @override
  void didUpdateWidget(SignedInHomeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Signed out, or another account: the old home must never show again.
    if (oldWidget.signedInUid != widget.signedInUid) _home = null;
  }

  @override
  void dispose() {
    // Cleared, not left pointing at a State that is gone.
    if (showSignedInHome == _show) showSignedInHome = null;
    if (clearSignedInHome == _clear) clearSignedInHome = null;
    super.dispose();
  }

  void _show(Widget home) {
    if (!mounted || widget.signedInUid == null) return;
    setState(() {
      _home = home;
      _generation++;
    });
  }

  void _clear() {
    if (!mounted || _home == null) return;
    setState(() => _home = null);
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.signedInUid == null ? null : _home;
    // The same gentle fade the pushed dashboard route used to open with.
    return AnimatedSwitcher(
      duration: AppMotion.slower,
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: home == null
          ? KeyedSubtree(key: const ValueKey('entry'), child: widget.child)
          : KeyedSubtree(key: ValueKey('home$_generation'), child: home),
    );
  }
}
