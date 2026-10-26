import '../data/announcement_fields.dart';
import '../services/announcement_service.dart';

/// Who sees an announcement (AN3): ONE rule for every reader of
/// public_announcements - the login page's Updates, the dashboard's bell and
/// Notifications - so they can never disagree.
class AnnouncementVisibility {
  AnnouncementVisibility._();

  /// Not hidden, and for everyone (also a missing or unknown audience) or
  /// for [languageCode], the language the app is shown in.
  static bool isShown(Announcement a, {required String languageCode}) =>
      !a.hidden && (a.audience == AnnouncementAudience.all || a.audience.key == languageCode);

  /// The bell's blink: an urgent announcement this person may see, published
  /// after [lastViewed] (when this device last opened Notifications; null
  /// before the first time, which never blinks).
  static bool hasNewUrgentSince(Iterable<Announcement> all, DateTime? lastViewed, {required String languageCode}) {
    if (lastViewed == null) return false;
    return all.any((a) {
      final at = a.publishedAt;
      return a.urgent && at != null && at.isAfter(lastViewed) && isShown(a, languageCode: languageCode);
    });
  }
}
