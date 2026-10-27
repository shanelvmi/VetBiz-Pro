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

  /// A poster announcement's 16:9 thumbnail in a notification row (AN3).
  static const double posterThumbnail = 64;

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

  /// AN4 (owner): about half the old frame shadow (blur 40, offset 20,
  /// AppAlpha.a40 of the shadow role), so the cards inside it lead.
  static const double shadowBlur = 20;
  static const double shadowOffsetY = 10;
  static const double shadowAlpha = AppAlpha.a20;
}

/// The cards inside the signed-out frame (AN4): the login card and, on wide
/// windows, the Updates card beside it share every size here, so they read
/// as one pair and one place restyles both (lib/widgets/auth_panel.dart).
class AuthPanelMetrics {
  AuthPanelMetrics._();

  static const double radius = AppRadius.r20;

  /// Inside the card: the sides and the top, and a little less at the bottom.
  static const double padding = AppSpacing.s28;
  static const double paddingBottom = AppSpacing.s24;

  /// The login card's gradient line along its top edge. Only the login card
  /// draws it; the Updates card adds its height to its top inset instead,
  /// so the two heading rows sit on one line.
  static const double accentHeight = 4;

  /// The soft circle beside each heading (the lock, the vaccine), its outline
  /// and glow, and the gap to the heading.
  static const double iconCircle = 42;
  static const double iconCircleBorder = 1.4;
  static const double iconCircleGlow = 14;
  static const double iconCircleGlowAlpha = AppAlpha.a50;

  /// Dark (AN5): a smaller, fainter glow, so the light ring does not haze
  /// the icon on the dark card. Light keeps the two above.
  static const double iconCircleGlowDark = 6;
  static const double iconCircleGlowAlphaDark = AppAlpha.a15;
  static const double headingGap = AppSpacing.s14;

  /// Between a heading and its subtitle (the welcome sentence, the sign-in
  /// subtext), the same in both cards so the two lines share a line (AN5).
  static const double subtitleGap = AppSpacing.s12;

  /// Two shadows: a wide tinted lift and a tight, crisp edge.
  static const double liftBlur = 32;
  static const double liftOffsetY = 14;
  static const double edgeBlur = 8;
  static const double edgeOffsetY = 2;

  /// Between the two cards: side by side, and stacked on phones.
  static const double gap = AppSpacing.s28;
  static const double stackGap = AppSpacing.s20;
}

/// The login page's Updates (lib/widgets/updates_parts.dart, AN2 and AN4).
class UpdatesMetrics {
  UpdatesMetrics._();

  /// The label row: always this tall, so nothing moves between slides;
  /// taller on wide windows, where the label is larger.
  static const double labelRowPhone = AppSpacing.s24;
  static const double labelRowWide = AppSpacing.s28;

  /// The dots: the selected one larger as well as another colour.
  static const double dot = AppSpacing.s8;
  static const double dotSelected = AppSpacing.s12;

  /// Wide: between the welcome note and the Updates label.
  static const double welcomeGap = AppSpacing.s28;
}

/// The calm footer below the signed-out cards (lib/widgets/auth_footer.dart, G3).
/// Every size of it lives here, so one place restyles it.
class AuthFooterMetrics {
  AuthFooterMetrics._();

  /// Every link and icon: Material's 48 px touch target.
  static const double tapTarget = 48;

  /// G6: the bottom row's icon line, the same with or without icons (wide
  /// and phone), so the footer never moves when they arrive.
  static const double bottomRowHeight = tapTarget;

  /// The brand mark beside the app name, and its letters.
  static const double markSize = 32;

  /// AN5: the description line under the mark and the name wraps to at
  /// most this many lines in the brand column; three on a wide window, so the
  /// Kiswahili is never cut there (the English takes two, under the links).
  static const int descriptionMaxLines = 4;
  static const int descriptionMaxLinesWide = 3;

  /// The social network icons inside their 48 px targets.
  static const double socialIconSize = AppIconSize.i18;

  /// The line between the columns and the bottom row.
  static const double hairline = 1;

  /// Around the footer, and between its parts (phones and narrow windows).
  static const double paddingVertical = AppSpacing.s24;
  static const double columnGap = AppSpacing.s24;
  static const double sectionGap = AppSpacing.s16;

  /// G5, wide windows (a mouse): about a third shorter. Link rows of 32 px
  /// instead of the 48 px touch target, less padding, a small gap above
  /// the line.
  static const double linkRowHeightWide = AppSpacing.s32;
  static const double paddingVerticalWide = AppSpacing.s12;
  static const double lineGapWide = AppSpacing.s8;

  /// G5, phones and narrow windows: the links' 48 px targets already leave
  /// space under them, so a small gap after a row of links and none above
  /// the line.
  static const double linksGapNarrow = AppSpacing.s4;

  /// The brand column takes this share of the row; Support and Legal one each.
  static const int brandFlex = 2;
}

/// The shared hover link of the signed-out pages (lib/widgets/hover_link.dart,
/// G4). Every size of it lives here, so one place restyles every link.
class HoverLinkMetrics {
  HoverLinkMetrics._();

  /// Material's 48 px touch target: the least height of every link, and
  /// the least width of an icon link.
  static const double tapTarget = 48;

  /// The keyboard focus ring: drawn outside the link, so it never moves it.
  static const double focusRingWidth = 2;
  static const double focusRingGap = AppSpacing.s4;
  static const double focusRingRadius = AppRadius.r6;

  /// Under an icon link: the line that shows on hover and focus. Its space
  /// is always kept, so it never moves the icon.
  static const double iconUnderlineGap = AppSpacing.s2;
  static const double iconUnderlineThickness = 1;
}

/// The About, How to use it and FAQs pages (lib/screens/info, G4). Every
/// size of them lives here, so one place restyles the three.
class InfoPageMetrics {
  InfoPageMetrics._();

  /// The readable column: never wider than this, centred on wide screens.
  static const double maxWidth = 720;

  /// Around the column, and between its parts.
  static const double padding = AppSpacing.s20;
  static const double sectionGap = AppSpacing.s24;
  static const double itemGap = AppSpacing.s12;

  /// The number circle in front of a step.
  static const double stepBadge = 28;

  /// Line height of the body text, for reading.
  static const double lineHeight = 1.5;
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

  /// A wizard screen (the register wizard, RW2b): between the header, the
  /// intro and the step's content, between fields, between option cards,
  /// and above Back and Continue when they are the card's bottom row.
  static const double sectionGap = AppSpacing.s20;
  static const double fieldGap = AppSpacing.s14;
  static const double optionListGap = AppSpacing.s8;
  static const double navTopGap = AppSpacing.s24;

  /// The review step's summary boxes: inside, the corner, between boxes,
  /// and between a box's lines.
  static const double reviewPadding = AppSpacing.s14;
  static const double reviewRadius = AppRadius.r14;
  static const double reviewGap = AppSpacing.s10;
  static const double reviewLineGap = AppSpacing.s4;

  /// Terms checkbox: between the box and the sentence, and above the error.
  static const double consentGap = AppSpacing.s4;
}
