import '../config/app_limits.dart';
import '../config/app_timeouts.dart';
import '../data/announcement_fields.dart';
import '../services/announcement_service.dart';

/// Which announcements the login page's Updates shows (AN2), in the order
/// given (the query's, newest first).
class UpdatesSelection {
  UpdatesSelection._();

  /// Not hidden; for everyone or for [languageCode] (a missing or unknown
  /// audience is everyone); then, while any of those is urgent, only the
  /// urgent ones (they take over without hiding the rest one by one); at
  /// most [AppLimits.updatesMaxSlides].
  static List<Announcement> pick(Iterable<Announcement> all, {required String languageCode}) {
    final shown = all
        .where((a) => !a.hidden && (a.audience == AnnouncementAudience.all || a.audience.key == languageCode))
        .toList();
    final urgent = shown.where((a) => a.urgent).toList();
    return (urgent.isNotEmpty ? urgent : shown).take(AppLimits.updatesMaxSlides).toList();
  }

  /// Published within [AppTimeouts.updatesNewFor] of [now].
  static bool isNew(Announcement a, DateTime now) {
    final at = a.publishedAt;
    return at != null && now.difference(at) < AppTimeouts.updatesNewFor;
  }
}
