/// Dimension tokens. All `static const`, so they stay usable inside `const`
/// widgets. Names mirror the value (`AppSpacing.s12` is 12) so moving a
/// screen onto them is exact; the values are today's, unchanged. Merging
/// near-duplicates is a separate, reviewed step (2R).
library;

import 'dart:ui' show Offset;

import 'app_text.dart' show AppFontSize;

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
  /// the round icon badge.
  static const double toastMax = 400;
  static const double toastIcon = 28;

  /// The smallest tap target: a toast button, and every small button on
  /// touch (AppTapTarget, lib/theme/app_tap_target.dart). 48 since PH2a
  /// (it was 40, below the 48 x 48 touch minimum).
  static const double minTapTarget = 48;

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

  /// AN6: the active dot is a pill this wide (as tall as a dot), filling
  /// over the slide's time.
  static const double pill = AppSpacing.s28;

  /// AN6: each dot's tap area is at least this wide (and [controlsRow] tall)
  /// around the visible dot; the owner may tune it.
  static const double dotSlot = AppSpacing.s24;

  /// AN6: the controls row under the frame (Material's 48 px touch target),
  /// kept this tall with one slide, none, or while loading, so nothing moves
  /// when the answer arrives.
  static const double controlsRow = 48;

  /// AN6: the focus ring around the dots when the keyboard is on them.
  static const double focusRing = 2;

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

/// The forms and pages that open as a full page below
/// AppBreakpoints.medium and as a centred modal from it (showAdaptiveForm,
/// lib/widgets/app_sheet.dart). The exact numbers of the 14 copies it
/// replaced (PH2b); AdaptiveFormSize combines them per screen.
class AdaptiveFormMetrics {
  AdaptiveFormMetrics._();

  /// Most forms: 60% of the window wide, at most 940; 88% high.
  static const double widthFactor = 0.60;
  static const double maxWidth = 940;
  static const double heightFactor = 0.88;

  /// Never shorter (the forms holding the fixed 480 px Browse Products).
  static const double minHeight = 480;

  /// Never taller (Add Client, Add Service, Add Transaction).
  static const double cappedMaxHeight = 820;

  /// The full report and the report review: 72% wide, 90% high.
  static const double reportWidthFactor = 0.72;
  static const double reportFullMaxWidth = 1100;
  static const double reportReviewMaxWidth = 900;
  static const double reportHeightFactor = 0.9;

  /// The activity log: 85% of the window both ways.
  static const double activityFactor = 0.85;

  /// The modal rises 3% of its height and grows from 96% as it fades in.
  static const Offset enterOffset = Offset(0, 0.03);
  static const double enterScale = 0.96;
}

/// showAppSheet (lib/widgets/app_sheet.dart): a bottom sheet on phones, a
/// dialog (AppSizes.dialogLg wide at most) on tablets and computers.
class AppSheetMetrics {
  AppSheetMetrics._();

  /// The sheet never covers more of a phone's height than this.
  static const double sheetMaxHeightFactor = 0.92;

  /// The dialog never covers more of the window's height than this.
  static const double dialogMaxHeightFactor = 0.88;
}

/// The phone shell (PH3, docs/design/phone_shell.md section 3): the bottom
/// bar, its raised "+", the "+" sheet and the More page. Every size lives
/// here, so the owner's later style changes are made in one place; colours
/// come from the context.colors roles.
class PhoneShellMetrics {
  PhoneShellMetrics._();

  /// The bar, above the home indicator (AppSafeArea.bottomOf is added), and
  /// its top border (borderStrong).
  static const double barHeight = 64;
  static const double barBorder = 1;

  /// A bar item: icon, label (one line), and the pill behind the selected
  /// item's icon (primary at 12%).
  static const double barIcon = AppIconSize.i24;
  static const double barLabel = AppFontSize.f12;
  static const double barLabelGap = AppSpacing.s2;
  static const double pillWidth = 56;
  static const double pillHeight = 32;
  static const double pillRadius = AppRadius.r16;
  static const double pillAlpha = 0.12;

  /// The central "+": a circle in accent, raised so [recordRaise] px sit
  /// above the bar's top edge; the whole slot is its tap target.
  static const double recordSize = 56;
  static const double recordIcon = 28;
  static const double recordRaise = 20;
  static const double recordElevation = AppElevation.e6;

  /// The "+" sheet's rows.
  static const double sheetRowHeight = 64;
  static const double sheetIconCircle = 40;
  static const double sheetIcon = AppIconSize.i22;
  static const double sheetLabel = AppFontSize.f16;
  static const double sheetHint = AppFontSize.f13;
  static const double sheetGap = AppSpacing.s12;
  static const double sheetSpinner = AppIconSize.i20;

  /// The More page: a grid of round icons, four a row on a phone.
  static const int moreColumns = 4;
  static const double moreCellWidth = 80;
  static const double moreCellHeight = 100;
  static const double moreCircle = 56;
  static const double moreIcon = AppIconSize.i24;
  static const double moreLabel = AppFontSize.f12;
  static const double moreLabelGap = AppSpacing.s4;
  static const double morePadding = AppSpacing.s16;
}

/// PH4: the phone home and All details (docs/design/phone_shell.md D2, D4
/// and section 3). Colours come from context.colors roles only.
class PhoneHomeMetrics {
  PhoneHomeMetrics._();

  /// The greeting top bar: avatar, a small greeting over the name.
  static const double avatar = 40;
  static const double greeting = AppFontSize.f13;
  static const double name = AppFontSize.f16;

  /// The page: side padding, the gap between sections, section titles and
  /// their "View all" / "All details" links (48 high).
  static const double pagePadding = AppSpacing.s16;
  static const double sectionGap = AppSpacing.s16;
  static const double sectionTitle = AppFontSize.f15;
  static const double linkHeight = 48;

  /// The Today card: Sales large, then two or three small figures.
  static const double cardPadding = AppSpacing.s16;
  static const double cardRadius = AppRadius.r16;
  static const double salesValue = AppFontSize.f28;
  static const double statValue = AppFontSize.f15;
  static const double label = AppFontSize.f12;
  static const double statGap = AppSpacing.s8;
  static const double chipHeight = 36;
  static const double chipIcon = AppIconSize.i16;

  /// Quick access: four tiles in a row.
  static const double tileHeight = 92;
  static const double tileGap = AppSpacing.s8;
  static const double tileCircle = 44;
  static const double tileIcon = AppIconSize.i22;

  /// Go to: a sideways list of round shortcuts, faded at the edge.
  static const double goToHeight = 104;
  static const double goToItemWidth = 72;
  static const double goToCircle = 56;
  static const double goToIcon = AppIconSize.i24;
  static const double goToFade = 32;

  /// Needs attention and All details: rows 56 high.
  static const double rowHeight = 56;
  static const double rowIcon = AppIconSize.i22;
  static const double rowLabel = AppFontSize.f14;
  static const double rowValue = AppFontSize.f15;
  static const double countChipPadding = AppSpacing.s8;
  static const double circleAlpha = 0.12;
}

/// PH5a: the standard phone list (docs/design/phone_list_pattern.md, rules R1
/// to R12). Colours come from context.colors roles only.
class PhoneListMetrics {
  PhoneListMetrics._();

  /// The page's side padding and the gap between the header's lines.
  static const double pagePadding = AppSpacing.s16;
  static const double headerGap = AppSpacing.s8;

  /// R6 rows: two lines, at least 64 high, a 40 px round leading on a tint
  /// of a chart role (initials in textPrimary), line 1 at 15, line 2 at 13.
  static const double rowMinHeight = 64;
  static const double rowPaddingV = AppSpacing.s10;
  static const double leading = 40;
  static const double leadingGap = AppSpacing.s12;
  static const double leadingIcon = AppIconSize.i20;
  static const double leadingText = AppFontSize.f14;
  static const double leadingAlpha = 0.18;
  static const double title = AppFontSize.f15;
  static const double subtitle = AppFontSize.f13;
  static const double lineGap = AppSpacing.s4;
  static const double partGap = AppSpacing.s8;

  /// The status chip: TEXT and colour (the role at [chipAlpha] behind it).
  static const double chip = AppFontSize.f12;
  static const double chipPaddingH = AppSpacing.s8;
  static const double chipPaddingV = AppSpacing.s2;
  static const double chipRadius = AppRadius.r10;
  static const double chipAlpha = 0.14;

  /// R5 day headers, pinned while their day scrolls.
  static const double dayHeaderHeight = 40;
  static const double dayHeader = AppFontSize.f13;

  /// R3 the quick chips' row and the filter button's dot.
  static const double chipRowHeight = 48;
  static const double chipGap = AppSpacing.s8;
  static const double filterDot = 8;

  /// R4 the summary line.
  static const double summaryLine = AppFontSize.f13;

  /// R2 the floating button: its height, its gap from the edges, and the
  /// room kept under the last row so the button never covers it.
  static const double fabHeight = 56;
  static const double fabMargin = AppSpacing.s16;
  static const double fabClearance = fabHeight + fabMargin * 2;

  /// R9 the loading rows, their bars, and the pulse's lowest opacity.
  static const int skeletonRows = 6;
  static const double skeletonBar = 12;
  static const double skeletonBarWide = 160;
  static const double skeletonBarNarrow = 96;
  static const double skeletonLow = 0.45;

  /// R9 the empty state's icon.
  static const double emptyIcon = AppIconSize.i48;

  /// R10 more loads when the list is this close to its end.
  static const double loadMoreExtent = 400;

  /// R7 the details page's labels: at least 12 on a phone (S3).
  static const double detailLabel = AppFontSize.f12;

  /// PH7a: a product's photo as a row's leading (a rounded square, not
  /// a face's circle), and on its details page: the photo's height, the
  /// name, the facts' values and text, the gap between the page's parts.
  static const double productThumbRadius = AppRadius.r8;
  static const double detailsImageHeight = 180;
  static const double detailsTitle = AppFontSize.f18;
  static const double detailsValue = AppFontSize.f16;
  static const double detailsText = AppFontSize.f14;
  static const double detailsGap = AppSpacing.s12;
}

/// PH6 (docs/design/phone_foundations.md S6): the money forms on a phone.
class PhoneFormMetrics {
  PhoneFormMetrics._();

  /// The pinned action bar: its padding, its buttons (at least 48 high) and
  /// the gap between them, the divider above it.
  static const double barPaddingH = AppSpacing.s16;
  static const double barPaddingV = AppSpacing.s12;
  static const double buttonHeight = 48;
  static const double buttonGap = AppSpacing.s12;
  static const double buttonRadius = AppRadius.r10;
  static const double barDivider = 1;
  static const double spinnerSize = AppIconSize.i18;
  static const double spinnerStroke = 2;

  /// The pinned summary line above the buttons (Add Sale's items and total).
  static const double summary = AppFontSize.f14;
  static const double summaryGap = AppSpacing.s8;

  /// Fields: at least 48 high; labels and body text at least 14; the
  /// reserved error line under a field.
  static const double fieldMinHeight = 48;
  static const double fieldPaddingV = AppSpacing.s14;
  static const double fieldPaddingH = AppSpacing.s12;
  static const double label = AppFontSize.f14;
  static const double body = AppFontSize.f14;
  static const double error = AppFontSize.f12;

  /// PH8a: the time wheels in a sheet (Business hours' closing times).
  static const double timeWheelHeight = 216;

  /// Picker sheets: one option a row, 56 high, a check on the chosen one.
  static const double optionRow = 56;
  static const double optionCheck = AppIconSize.i20;
  static const double optionIcon = AppIconSize.i20;
  static const double optionGap = AppSpacing.s12;
  static const double groupHeaderPaddingTop = AppSpacing.s12;
}

/// PH7b (docs/design/phone_reports.md): the reports on a phone.
class PhoneReportMetrics {
  PhoneReportMetrics._();

  /// The page's and a row's side padding; the gap between sections.
  static const double pagePadding = AppSpacing.s16;
  static const double sectionGap = AppSpacing.s16;
  static const double sectionRadius = AppRadius.r12;
  static const double headerGap = AppSpacing.s8;

  /// R1: the tab bar's labels and each tab's height (a 48 px target).
  static const double tabLabel = AppFontSize.f14;
  static const double tabHeight = 48;

  /// R2 rows: two lines, at least 56 high, both at 14 (line 2 muted: in
  /// Kiswahili it is the longer one, and the owner's rule is 14 on rows).
  static const double rowMinHeight = 56;
  static const double rowPaddingV = AppSpacing.s8;
  static const double title = AppFontSize.f14;
  static const double subtitle = AppFontSize.f14;
  static const double sectionTitle = AppFontSize.f16;
  static const double icon = AppIconSize.i18;
  static const double lineGap = AppSpacing.s4;
  static const double partGap = AppSpacing.s8;

  /// R4 label-and-value rows (and See all): at least 48 high.
  static const double statMinHeight = 48;
  static const double statPaddingV = AppSpacing.s6;
}

/// PH8a: the bells (lib/screens/dashboard/notification_bell.dart).
class BellMetrics {
  BellMetrics._();

  /// The dropdown under a bell on a wide window: 400 wide, [panelGap] below
  /// the bell, kept [panelEdge] inside the window's right edge, at most
  /// [panelMaxHeight] of the window high, growing from [panelEnterScale].
  static const double panelWidth = 400;
  static const double panelGap = AppSpacing.s8;
  static const double panelEdge = AppSpacing.s16;
  static const double panelMaxHeight = 0.75;
  static const double panelEnterScale = 0.95;

  /// The unread number (NOTIF-2d): 12 px, never under the phone minimum.
  static const double countText = AppFontSize.f12;
  static const double countHeight = 18;

  /// The number shows up to [countMax], then "9+".
  static const int countMax = 9;
}

/// PH8a: the subscription banner at the top of the phone tabs.
class PhoneBannerMetrics {
  PhoneBannerMetrics._();

  static const double paddingStart = AppSpacing.s12;
  static const double paddingV = AppSpacing.s2;
  static const double icon = AppIconSize.i20;
  static const double gap = AppSpacing.s8;

  /// One line, two at most in Kiswahili, 14 px.
  static const double text = AppFontSize.f14;
  static const int maxLines = 2;
  static const double actionPaddingH = AppSpacing.s8;

  /// PH8a-fix (the owner's correction): the banner floats over the tab
  /// content, right under the app bar: an 8 px side margin, a 12 px radius,
  /// a soft shadow, and the status role at 92 percent, slightly see-through
  /// over the content and never blended into the surface (the ink is
  /// AppColors.bannerInk, which passes 4.5:1 over black and white content).
  static const double overlayAlpha = 0.92;
  static const double overlayMargin = AppSpacing.s8;
  static const double overlayRadius = AppRadius.r12;
  static const double shadowAlpha = AppAlpha.a20;
  static const double shadowBlur = 8;
  static const double shadowOffsetY = 2;

  /// It comes in sliding down this fraction of its height as it fades in.
  static const double enterSlide = 0.25;
}
