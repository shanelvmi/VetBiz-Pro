import 'package:flutter/material.dart';

// RV1: every pushed page slides in from the right. Stubs first: the tests
// are written against this API and skipped until the implementation.

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const String loginRouteName = '/login';

  static PageTransitionsTheme get theme => throw UnimplementedError();

  static PageTransitionsBuilder previousDefault(TargetPlatform platform) => throw UnimplementedError();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      throw UnimplementedError();
}

class AppPageSlide extends StatelessWidget {
  const AppPageSlide({super.key, required this.animation, required this.secondaryAnimation, required this.child});

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
