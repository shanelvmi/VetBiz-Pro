import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
