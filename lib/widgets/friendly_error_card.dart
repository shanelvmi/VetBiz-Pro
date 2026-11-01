import 'package:flutter/material.dart';

/// FX1: what a release build shows in place of a widget that failed to build
/// (ErrorWidget.builder), instead of Flutter's grey box: a small card with
/// error_screenFailed, sized to what it holds (it never stretches a Row or a
/// list), no technical text. It may be drawn above the app's theme and
/// localisations, so it needs neither.
class FriendlyErrorCard extends StatelessWidget {
  const FriendlyErrorCard({super.key});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
