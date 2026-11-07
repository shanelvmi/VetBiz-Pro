import 'package:flutter/material.dart';

import 'reveal_gate.dart';

// RV1: a screen's content arriving as one piece. Stubs first (see
// reveal_gate.dart).

class ScreenReveal extends StatelessWidget {
  const ScreenReveal({super.key, required this.gate, this.skeleton, required this.child});

  final RevealGate gate;
  final Widget? skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Marks where a reveal's (or a late slot's) own content starts, so a test
/// can compare a revealed tree with the same tree before RV1.
class RevealedContent extends StatelessWidget {
  const RevealedContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
