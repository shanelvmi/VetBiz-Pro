/// Dimension tokens. All `static const`, so they stay usable inside `const`
/// widgets. Names mirror the value (`AppSpacing.s12` is 12) so moving a
/// screen onto them is exact; the values are today's, unchanged. Merging
/// near-duplicates is a separate, reviewed step (2R).
library;

/// Padding, margins and gaps (`EdgeInsets`, `SizedBox` up to 32).
class AppSpacing {
  AppSpacing._();

  static const double s2 = 2;
  static const double s3 = 3;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
}

/// Corner radii (`BorderRadius.circular`, `Radius.circular`).
class AppRadius {
  AppRadius._();

  static const double r4 = 4;
  static const double r6 = 6;
  static const double r7 = 7;
  static const double r8 = 8;
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  /// Fully rounded ends (pills, circles).
  static const double pill = 999;
}

/// `Icon(size:)` and `iconSize:` only.
class AppIconSize {
  AppIconSize._();

  static const double i12 = 12;
  static const double i14 = 14;
  static const double i16 = 16;
  static const double i18 = 18;
  static const double i20 = 20;
  static const double i22 = 22;
  static const double i24 = 24;
  static const double i32 = 32;
  static const double i48 = 48;
  static const double i56 = 56;
  static const double i64 = 64;
}

class AppElevation {
  AppElevation._();

  static const double e0 = 0;
  static const double e1 = 1;
  static const double e2 = 2;
  static const double e6 = 6;
  static const double e8 = 8;
}

/// Opacity for tints: `colors.primary.withValues(alpha: AppAlpha.a10)`.
class AppAlpha {
  AppAlpha._();

  static const double a05 = 0.05;
  static const double a10 = 0.1;
  static const double a15 = 0.15;
  static const double a20 = 0.2;
  static const double a30 = 0.3;
  static const double a40 = 0.4;
  static const double a50 = 0.5;
  static const double a70 = 0.7;
  static const double a85 = 0.85;
}

/// Widths of dialogs, content columns and fixed chrome.
class AppSizes {
  AppSizes._();

  // Dialog max widths.
  static const double dialogXs = 340;
  static const double dialogSm = 420;
  static const double dialogMd = 500;
  static const double dialogLg = 560;

  // Content max widths.
  static const double formMax = 700;
  static const double contentSm = 820;
  static const double contentMd = 900;
  static const double contentLg = 1000;
  static const double contentXl = 1080;
  static const double pageMax = 1440;

  /// Feedback toasts (lib/ui/feedback): the card's width on wider screens,
  /// the round icon badge, and the smallest height of a toast button.
  static const double toastMax = 400;
  static const double toastIcon = 28;
  static const double minTapTarget = 40;

  /// The dashboard sidebar (dashboard_screen.dart, the sidebar `width:`).
  static const double sidebarExpanded = 250;
  static const double sidebarCollapsed = 72;

  /// The platform admin sidebar is 10px narrower than the dashboard's
  /// (platform_admin_home_screen.dart). Kept exact; aligning them is a 2R
  /// decision.
  static const double platformAdminSidebarExpanded = 240;
}
