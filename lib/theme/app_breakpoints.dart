/// Widths at which a layout changes shape.
///
/// Breakpoints decide WHERE a layout flips, so none of them were rounded:
/// each keeps its exact legacy number. The one-offs are named for the layout
/// decision they control, with the places that use them. Harmonising them is
/// step 2R and needs screenshots at the boundary widths.
class AppBreakpoints {
  AppBreakpoints._();

  // The three tiers.

  /// Phones. Also the 2-vs-4 column summary grids
  /// (manage_assistants_screen.dart:1073, subscription_history_screen.dart:278)
  /// and the narrow list layouts (debtors_screen.dart:329,
  /// manage_assistants_screen.dart:823, sales_screen.dart:354,
  /// services_screen.dart:305, login_screen.dart:416).
  static const double compact = 600;

  /// Wide enough for the desktop page frame (the many `isWideScreen` checks),
  /// and the side-by-side receipt / facility layouts.
  static const double medium = 900;

  /// The dashboard sidebar shows (dashboard_screen.dart:1113, 2469, 2843).
  static const double expanded = 1024;

  // One-offs, exact.

  /// Above this screen width a confirm dialog is a fixed 340 wide
  /// (AppSizes.dialogXs), below it
  /// 85% of the screen (subscription_guard.dart:53, 77;
  /// platform_admin_home_screen.dart:177; user_detail_screen.dart:178, 228, 248).
  static const double dialogFixedWidth = 700;

  /// Below this, side-by-side sections stack into one column
  /// (announcements_tab.dart:643, subscription_history_screen.dart:395,
  /// facility_picker_screen.dart:241, facility_screen.dart:1943, 2896,
  /// overview_tab.dart:178 for its 4-column grid).
  static const double stackSections = 700;

  /// Forms switch to two columns (add_transaction_screen.dart:240,
  /// add_sale_screen.dart:897, add_client_screen.dart:319,
  /// add_edit_service_screen.dart:327, add_edit_product_screen.dart:1082,
  /// view_reports_screen.dart:363).
  static const double formTwoColumn = 860;

  /// A main card with a second panel beside it, instead of below
  /// (login_screen.dart:1184, legal_document_screen.dart:84,
  /// notifications_screen.dart:614).
  static const double twoPane = 820;

  /// Five category cards in a row instead of three
  /// (notifications_screen.dart:477, stock_alerts_screen.dart:629).
  static const double fiveColumnCards = 720;

  /// The registration form's two columns (register_screen.dart:1039).
  static const double registerTwoColumn = 720;

  /// Results show as a table instead of a list
  /// (notifications_screen.dart:791, subscription_history_screen.dart:479,
  /// stock_alerts_screen.dart:829).
  static const double resultsTable = 760;

  /// The team list shows as a table (manage_assistants_screen.dart:1324).
  static const double teamTable = 800;

  /// Filters sit in one row instead of stacking
  /// (manage_assistants_screen.dart:1191, stock_alerts_screen.dart:746).
  static const double filterRow = 640;

  /// A details panel opens beside the list instead of as a bottom sheet
  /// (manage_assistants_screen.dart:1017, 1529).
  static const double detailsSidePanel = 1100;

  /// Tight phone layout in the sale and product forms
  /// (add_sale_screen.dart:896, add_edit_product_screen.dart:1079).
  static const double phoneNarrow = 480;

  /// The loading illustration shrinks (vetbiz_loading_indicator.dart:162), and
  /// the overview grid drops to one column (overview_tab.dart:178).
  static const double smallPhone = 420;

  /// The login header drops its subtitle (login_screen.dart:307).
  static const double loginHeaderNarrow = 560;

  /// A summary card's own width (not the screen) below which it uses its
  /// smaller avatar and text (summary_card.dart:173).
  static const double summaryCardCompact = 160;
}
