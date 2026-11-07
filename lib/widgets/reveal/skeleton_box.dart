import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

// RV1: the one skeleton look. Stubs first (see reveal_gate.dart).

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = RevealMetrics.skeletonRadius});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class SkeletonOf extends StatelessWidget {
  const SkeletonOf({super.key, required this.child, this.radius = RevealMetrics.skeletonRadius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class SkeletonPulse extends StatelessWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class SkeletonScope extends InheritedWidget {
  const SkeletonScope({super.key, required super.child});

  static bool of(BuildContext context) => throw UnimplementedError();

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) => false;
}

class SkeletonOr extends StatelessWidget {
  const SkeletonOr({super.key, required this.child, this.placeholder, this.radius = RevealMetrics.skeletonRadius});

  final Widget child;
  final Widget? placeholder;
  final double radius;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
