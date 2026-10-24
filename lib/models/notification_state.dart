import 'package:cloud_firestore/cloud_firestore.dart';

/// One person's own notification state in one facility (NOTIF-2b):
/// facilities/{fid}/notificationState/{uid}, the shape firestore.rules
/// accepts (isValidNotificationState). Each map is keyed by notification id;
/// read, unread and removed hold WHEN I did it (my device's clock), which
/// the lifetimes and the pruning use; seenStage holds the subscription
/// notice's stage I last read it at (SubscriptionNoticeStage.key).
class NotificationState {
  final Map<String, DateTime> read;
  final Map<String, DateTime> unread;
  final Map<String, DateTime> removed;
  final Map<String, String> seenStage;

  const NotificationState({
    this.read = const {},
    this.unread = const {},
    this.removed = const {},
    this.seenStage = const {},
  });

  static const NotificationState empty = NotificationState();

  /// The stored document; null (none yet) is the empty state.
  factory NotificationState.fromMap(Map<String, dynamic>? data) {
    Map<String, DateTime> times(Object? map) => {
          if (map is Map)
            for (final e in map.entries)
              if (notificationStateTime(e.value) != null) e.key as String: notificationStateTime(e.value)!,
        };
    final stages = data?['seenStage'];
    return NotificationState(
      read: times(data?['read']),
      unread: times(data?['unread']),
      removed: times(data?['removed']),
      seenStage: {
        if (stages is Map)
          for (final e in stages.entries)
            if (e.value is String) e.key as String: e.value as String,
      },
    );
  }

  /// When I read [id]: my own read, else the facility-wide readAt from
  /// before NOTIF-2 ([sharedReadAt]), unless I marked it unread; null when
  /// it is unread for me.
  DateTime? readAtForMe(String id, {DateTime? sharedReadAt}) =>
      unread.containsKey(id) ? null : (read[id] ?? sharedReadAt);

  bool isReadByMe(String id, {DateTime? sharedReadAt}) => readAtForMe(id, sharedReadAt: sharedReadAt) != null;

  bool isRemoved(String id) => removed.containsKey(id);
}

/// What a removal replaced, so Undo can put it back exactly: for each id,
/// its earlier removal time, or null when it wasn't removed before.
class RemovedEntries {
  final Map<String, DateTime?> previous;
  const RemovedEntries(this.previous);
}

/// A stored time, read back; anything else is ignored.
DateTime? notificationStateTime(Object? value) => value is Timestamp ? value.toDate() : null;
