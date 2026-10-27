import 'package:flutter/material.dart';

/// Small buttons drawn under 48 px (docs/design/phone_foundations.md S2):
/// as compact as before with a mouse, at least [AppSizes.minTapTarget]
/// square on touch. The theme decides which: Flutter pads tap targets on
/// Android and iOS (phone and tablet browsers too) and shrink-wraps them on
/// desktop, so the computer layout stays exactly as it was.
///
/// lib/screens may not shrink a tap target itself (`BoxConstraints()`,
/// `VisualDensity.compact`, `MaterialTapTargetSize.shrinkWrap`): the guard's
/// rule R12 (tool/check_hardcoded.dart). Use these instead.
class AppTapTarget {
  AppTapTarget._();

  static bool isTouch(BuildContext context) => throw UnimplementedError();

  /// An IconButton's constraints: none with a mouse (as `BoxConstraints()`
  /// was), 48 x 48 on touch. The icon keeps its size inside.
  static BoxConstraints iconConstraints(BuildContext context) => throw UnimplementedError();

  /// The theme's tap target size: shrinkWrap with a mouse, padded on touch.
  static MaterialTapTargetSize size(BuildContext context) => throw UnimplementedError();

  /// Compact with a mouse, standard on touch.
  static VisualDensity density(BuildContext context) => throw UnimplementedError();

  /// The width or height of a box holding a small button: [compact] with a
  /// mouse, at least 48 on touch.
  static double extent(BuildContext context, double compact) => throw UnimplementedError();
}
