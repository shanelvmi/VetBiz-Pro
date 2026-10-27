import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// The one phone, tablet or desktop signal (docs/design/phone_foundations.md
/// S1). New code asks this instead of comparing widths of its own.
///
/// A phone is narrower than [AppBreakpoints.compact], or shorter than
/// [AppBreakpoints.phoneLandscapeHeight] while narrower than
/// [AppBreakpoints.expanded] (a phone turned sideways). Otherwise a tablet
/// below [AppBreakpoints.expanded] wide, a desktop from it.
enum AppLayout {
  phone,
  tablet,
  desktop;

  /// Pure, so tests can check any size without a widget.
  static AppLayout fromSize(Size size) {
    final w = size.width;
    if (w < AppBreakpoints.compact) return AppLayout.phone;
    if (w < AppBreakpoints.expanded) {
      return size.height < AppBreakpoints.phoneLandscapeHeight ? AppLayout.phone : AppLayout.tablet;
    }
    return AppLayout.desktop;
  }

  static AppLayout of(BuildContext context) => fromSize(MediaQuery.sizeOf(context));

  static bool isPhone(BuildContext context) => of(context) == AppLayout.phone;
}
