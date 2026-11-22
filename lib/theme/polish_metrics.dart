import 'app_dimens.dart';
import 'app_text.dart';

/// POL1 (docs/POLISH_AUDIT.md): the sizes of the one consistent look, used by
/// the shared widgets in lib/ui/polish (StatusDot, FlatStatCard, FilterRow,
/// SectionLabel) and by the screens that adopt them. Every value is a step of
/// the existing scale; no spacing step was added (s8, s16 and s24 exist).
class PolishMetrics {
  PolishMetrics._();

  // Owner rule 5: one gap inside a group, a larger one between groups, a
  // larger one between sections.
  static const double gapInGroup = AppSpacing.s8;
  static const double gapBetweenGroups = AppSpacing.s16;
  static const double gapBetweenSections = AppSpacing.s24;

  /// The page's side padding (the same as the phone lists').
  static const double pagePadding = AppSpacing.s16;

  // Owner rule 3: the one status style, a dot plus the word.
  static const double dot = AppSizes.statusDot;
  static const double dotGap = AppSpacing.s6;
  static const double statusText = AppFontSize.f12;

  /// Where a pill is truly needed: one low-opacity style, one size.
  static const double pillAlpha = AppAlpha.a10;
  static const double pillPaddingH = AppSpacing.s8;
  static const double pillPaddingV = AppSpacing.s2;
  static const double pillRadius = AppRadius.r10;

  /// POL2b: the same pill on a brand-coloured surface (the phone Today card):
  /// a soft white fill, the old change chip's (PhoneHomeMetrics.circleAlpha).
  static const double onBrandPillAlpha = PhoneHomeMetrics.circleAlpha;

  // Owner rule 4: the flat stat card.
  static const double cardPadding = AppSpacing.s16;
  static const double cardRadius = AppRadius.r12;
  static const double hairline = 1;

  /// POL3: the flat primary button's states, onPrimary laid over primary
  /// (the onPrimary ink stays at 4.5:1 or more on both, every theme, Light
  /// and Dark; the pressed state is the lower, 4.71 in Ledger Dark).
  static const double buttonHoverAlpha = AppAlpha.a05;
  static const double buttonPressedAlpha = AppAlpha.a10;
  static const double statValue = AppFontSize.f20;
  static const double statLabel = AppFontSize.f12;
  static const double statLineGap = AppSpacing.s4;

  /// POL4: the stat card's first-load spinner, as thin as the lists' ones.
  static const double spinnerStroke = 2;

  // The single filter row: text segments, the chosen one in primary with a
  // thin underline; 48 high so each segment is a full tap target.
  static const double filterHeight = AppSizes.minTapTarget;
  static const double filterPaddingH = AppSpacing.s12;
  static const double filterText = AppFontSize.f14;
  static const double filterCountGap = AppSpacing.s6;
  static const double filterUnderline = 2;

  /// The small group header ("New", "Earlier", a month).
  static const double sectionLabel = AppFontSize.f12;
  static const double sectionLabelPaddingTop = AppSpacing.s16;
  static const double sectionLabelPaddingBottom = AppSpacing.s8;

  /// POL7: lines of one hue told apart by style (the Sales revenue chart:
  /// Collections dashed, Services dotted) and their legend swatch, which
  /// draws the same pattern.
  static const List<int> chartDash = [6, 4];
  static const List<int> chartDot = [2, 3];
  static const double chartSwatchWidth = AppSpacing.s20;
  static const double chartSwatchStroke = 2;

  /// An unread row: a soft primary tint (stronger than the old 5 %) and a
  /// primary dot at its leading edge.
  static const double unreadTintAlpha = AppAlpha.a10;
  static const double unreadDot = AppSizes.statusDot;

  /// UX7: the Settings page template (lib/ui/polish/page_layout.dart). A
  /// table keeps its Date column (and its actions column) one fixed width,
  /// so the date sits at the same x on every row.
  static const double tableDateColumn = 180;
  static const double tableActionsColumn = 200;
  static const double tableRowPaddingV = AppSpacing.s10;
  static const double tableHeaderText = AppFontSize.f12;
}

/// LAY6a: the record screens' details panel (DetailsLayout) and the toolbar
/// of search plus filters (ToolbarLayout).
class DetailsLayoutMetrics {
  DetailsLayoutMetrics._();

  /// A slide-over panel is at most this share of the width it covers.
  static const double slideOverMaxFactor = 0.9;

  /// The search field's narrowest width while the filters share its line;
  /// below it the search takes its own line and the filters wrap under it.
  static const double searchMinWidth = 240;

  /// A record list's header (figures, toolbar) takes at most this share of
  /// the list's height; taller, it scrolls inside it.
  static const double headerMaxShare = 0.35;
}

/// UX9: the Select Facility screen (lib/screens/facilities/facility_picker_screen.dart)
/// and its card (lib/widgets/facility_pick_card.dart). Flat hairline cards
/// in a centred column; every value a step of the existing scale.
class FacilityPickerMetrics {
  FacilityPickerMetrics._();

  /// The cards never spread wider than this, centred in the window.
  static const double maxContentWidth = 1100;

  /// A grid column is never narrower than this (3 or more facilities).
  static const double minCardWidth = 220;

  /// The gap between cards, both ways.
  static const double gridGap = AppSpacing.s16;

  /// The logo, or the two-letter initials tile when there is none.
  static const double logoTile = AppIconSize.i48;
  static const double logoTileRadius = AppRadius.r10;
  static const double initialsText = AppFontSize.f16;

  static const double cardPadding = AppSpacing.s16;
  static const double cardRadius = AppRadius.r12;

  /// The highlighted (Default) card's accent outline; every other card the
  /// hairline.
  static const double selectedOutline = 2;

  /// More facilities than this, and a search box shows above the grid.
  static const int searchAbove = 8;
}
