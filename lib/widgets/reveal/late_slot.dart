import 'package:flutter/material.dart';

// RV1: the reserved box where a secondary block appears. Stubs first (see
// reveal_gate.dart).

class LateSlot extends StatelessWidget {
  const LateSlot({super.key, required this.ready, required this.child, this.height});

  final bool ready;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
