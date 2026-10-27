import 'package:flutter/material.dart';

/// AN6: one part of the signed-out page entering (the header, or a card):
/// a short fade and rise driven by the page's one [animation], starting
/// [delay] after it. STUB (tests first): draws [child] as it is.
class AuthEntrance extends StatelessWidget {
  const AuthEntrance({super.key, required this.animation, this.delay = Duration.zero, required this.child});

  final Animation<double> animation;
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
