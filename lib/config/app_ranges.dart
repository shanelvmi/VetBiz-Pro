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

  /// The payments ledger opens on the last year.
  static const Duration paymentsDefaultRange = year;

  /// The last moment before a boundary ("the end of last month" is the
  /// start of this month minus this).
  static const Duration instant = Duration(seconds: 1);

  /// Platform admin overview: activity window.
  static const Duration adminOverviewWindow = Duration(days: 90);

  /// How long a locally built notice stays (notifications_screen.dart).
  static const Duration noticeLifetime = Duration(days: 2);

  /// Insights trend: today and the 13 days before it (14 days in all).
  static const Duration insightsTrendBack = Duration(days: 13);

  /// Export presets: "last 7 days" and "last 30 days", today included, so
  /// they reach back 6 and 29 days.
  static const Duration exportLast7DaysBack = Duration(days: 6);
  static const Duration exportLast30DaysBack = Duration(days: 29);

  /// Sales and services older than this are in the archive; the archive
  /// screens also print the number ("archived after 180 days").
  static const int archiveCutoffDays = 180;
  static const Duration archiveCutoff = Duration(days: archiveCutoffDays);

  /// How far back the archive search opens, from the cutoff.
  static const Duration archiveDefaultWindow = Duration(days: 90);
}
