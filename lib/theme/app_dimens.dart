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

  // The Markdown quote box (flutter_markdown's own default corner).
  static const double r2 = 2;
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

  /// Empty-state and placeholder icons (add_sale_screen.dart empty items;
  /// add_edit_product_screen.dart photo placeholder, 36 snapped up).
  static const double i40 = 40;
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

  /// The round button in the signed-out screens' top bar (the theme
  /// toggle): the circle you see, inside Material's 48 px touch target.
  static const double authHeaderButton = 36;

  /// The profile (lib/widgets/profile): the avatar in the top bar, in the
  /// drawer and in Edit Profile, and the widest the top bar's name gets.
  static const double profileAvatarBar = 32;
  static const double profileAvatarDrawer = 72;
  static const double profileAvatarEditor = 68;
  static const double profileNameMax = 160;

  /// A small round status indicator (online, stock status, submitted,
  /// client Active/Inactive): an 8 px dot, as a Container or an
  /// Icons.circle size.
  static const double statusDot = 8;

  /// The dashboard sidebar (dashboard_screen.dart, the sidebar `width:`).
  static const double sidebarExpanded = 250;
  static const double sidebarCollapsed = 72;

  /// The platform admin sidebar is 10px narrower than the dashboard's
  /// (platform_admin_home_screen.dart). Kept exact; aligning them is a 2R
  /// decision.
  static const double platformAdminSidebarExpanded = 240;
}

/// The one card of the signed-out screens (lib/widgets/auth_card.dart).
/// Login and Register both read these, so one place restyles both cards.
class AuthCardMetrics {
  AuthCardMetrics._();

  /// Between the card and the page edge (and the phone's full width).
  static const double pageMargin = AppSpacing.s24;

  /// Widest the card gets: in its wide layout (above
  /// AppBreakpoints.twoPane) and below it.
  static const double maxWidthWide = 1100;
  static const double maxWidthNarrow = 560;

  /// Inside the card, around its body.
  static const double paddingWide = AppSpacing.s28;
  static const double paddingNarrow = AppSpacing.s18;

  static const double radius = AppRadius.r24;
  static const double shadowBlur = 40;
  static const double shadowOffsetY = 20;
}

/// The step-by-step forms (lib/widgets/wizard, register_wizard.md section
/// 3). Every size of the wizard widgets lives here, so one place restyles
/// them (the owner's phone-app style comes later).
class WizardMetrics {
  WizardMetrics._();

  /// Back, Continue and the terms checkbox: Material's 48 px touch target.
  static const double buttonHeight = 48;
  static const double consentTapTarget = 48;

  /// The smallest an option card gets, with one short line.
  static const double optionMinHeight = 56;

  /// The progress bar under "Step n of total".
  static const double progressHeight = 4;
  static const double progressRadius = AppRadius.r2;

  /// Header: between "Step n of total" and the title on one line, between
  /// the lines when the title wraps, and above the bar.
  static const double headerSpacing = AppSpacing.s12;
  static const double headerRunSpacing = AppSpacing.s4;
  static const double headerBarGap = AppSpacing.s8;

  /// Step intro: between the title and the subtitle.
  static const double introGap = AppSpacing.s6;

  /// Option card: inside, between the radio, icon and text, the corner
  /// and the outline (thicker when chosen, so the state is not colour only).
  static const double optionPaddingH = AppSpacing.s16;
  static const double optionPaddingV = AppSpacing.s12;
  static const double optionGap = AppSpacing.s12;
  static const double optionTextGap = AppSpacing.s2;
  static const double optionRadius = AppRadius.r12;
  static const double optionBorder = 1;
  static const double optionBorderSelected = 2;
  static const double optionIcon = AppIconSize.i24;

  /// Back and Continue: between them, inside, the corner, and the spinner
  /// that replaces Continue's text while the account is created.
  static const double navGap = AppSpacing.s12;
  static const double buttonPaddingH = AppSpacing.s24;
  static const double buttonRadius = AppRadius.r12;
  static const double spinnerSize = AppSpacing.s20;
  static const double spinnerStroke = 2.2;

  /// The bar pinned to the bottom of a phone screen: around the buttons,
  /// and its top line.
  static const double pinnedPaddingH = AppSpacing.s16;
  static const double pinnedPaddingV = AppSpacing.s12;
  static const double pinnedDivider = 1;

  /// Terms checkbox: between the box and the sentence, and above the error.
  static const double consentGap = AppSpacing.s4;
}
