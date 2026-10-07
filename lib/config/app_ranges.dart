/// Calendar spans and the default date ranges screens open with.
class AppRanges {
  AppRanges._();

  static const Duration day = Duration(days: 1);
  static const Duration week = Duration(days: 7);
  static const Duration fortnight = Duration(days: 14);

  /// "A month" as the app counts it: 30 days, not a calendar month.
  static const Duration month = Duration(days: 30);
  static const Duration year = Duration(days: 365);

  /// Sales, services and transactions open on the last 30 days.
  static const Duration defaultListRange = month;

  /// How far each "load older" step of the archives reaches back.
  static const Duration archiveStep = month;

  /// The payments ledger opens on the last year.
  static const Duration paymentsDefaultRange = year;

  /// Platform admin overview: activity window.
  static const Duration adminOverviewWindow = Duration(days: 90);

  /// How long a locally built notice stays (notifications_screen.dart).
  static const Duration noticeLifetime = Duration(days: 2);

  /// Insights trend: today and the 13 days before it (14 days in all).
  static const int insightsTrendDaysBack = 13;

  /// Export presets: "last 7 days" and "last 30 days", today included, so
  /// they reach back 6 and 29 days.
  static const int exportLast7DaysBack = 6;
  static const int exportLast30DaysBack = 29;
}
