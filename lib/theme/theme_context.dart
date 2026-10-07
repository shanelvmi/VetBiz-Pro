import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

import 'app_breakpoints.dart';
import 'app_colors.dart';

/// Shortcuts for reading the look from a [BuildContext].
extension AppThemeContext on BuildContext {
  /// The colour roles of the current theme. Registered by AppTheme.build, so
  /// always present under VetBizProApp.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Phone width (below 600).
  bool get isCompact => screenWidth < AppBreakpoints.compact;

  /// 600 up to (not including) 900.
  bool get isMedium =>
      screenWidth >= AppBreakpoints.compact && screenWidth < AppBreakpoints.medium;

  /// 1024 and wider: the sidebar shows.
  bool get isExpanded => screenWidth >= AppBreakpoints.expanded;
}
