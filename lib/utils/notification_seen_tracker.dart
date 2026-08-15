import 'package:shared_preferences/shared_preferences.dart';

/// Tracks when the current device last opened the Notifications screen -
/// stored locally (per-device), not synced to Firestore. Used to tell
/// the difference between "something still needs attention" (an
/// ongoing condition like low stock - shown as a steady dot regardless
/// of whether it's been seen) and "something new arrived since you last
/// looked" (a fresh urgent announcement or a newly-registered pending
/// assistant - shown as a blinking dot until Notifications is opened
/// again).
class NotificationSeenTracker {
  static const _key = 'last_notifications_viewed_at';

  static Future<DateTime?> getLastViewedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> markViewedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }
}
