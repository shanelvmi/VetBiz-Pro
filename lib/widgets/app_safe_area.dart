import 'package:flutter/widgets.dart';

/// The bottom safe area (docs/design/phone_foundations.md S8): every pinned
/// bottom bar and sheet keeps its content above the phone's home indicator
/// or gesture bar. viewPadding, not padding: it stays the same while the
/// keyboard is open, so content does not jump.
class AppSafeArea {
  AppSafeArea._();

  /// The room the system takes at the bottom of the window.
  static double bottomOf(BuildContext context) => MediaQuery.viewPaddingOf(context).bottom;
}
