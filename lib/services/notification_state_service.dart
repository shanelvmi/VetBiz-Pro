import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_limits.dart';
import '../config/app_ranges.dart';
import '../data/collections.dart';
import '../data/subscription_notice_stage.dart';
import '../models/notification_model.dart' show NotificationType;
import '../models/notification_state.dart';

/// Reads and writes one person's own notification state in one facility
/// (NOTIF-2b; docs/design/notifications.md, section 2, approved):
/// facilities/{fid}/notificationState/{uid}, which only that person may read
/// or write (firestore.rules, NOTIF-2a).
///
/// Every action is ONE write: `set` with merge, each entry as its own field
/// inside its map (a nested map merges entry by entry, as dotted paths would;
/// a dotted key in `set` would be a literal field name). So two devices of
/// the same person never overwrite each other's entries. updatedAt is the
/// server's time; the entries hold the device's time (the design's P4),
/// which the lifetimes and the pruning use.
///
/// Every write also drops entries older than AppRanges.notificationStatePrune
/// and keeps each map within AppLimits.notificationStateMapMax (the rule's
/// bound), the oldest going first. A dropped `removed` entry means that
/// notification shows again if it is still within its lifetime; a dropped
/// `read` entry shows it unread again (or read through an old shared
/// readAt). Reaching the bound takes 2000 actions of one kind within 120 days.
class NotificationStateService {
  final FirebaseFirestore _firestore;
  final String facilityId;
  final String uid;

  /// The device's clock (the design's P4); tests pass a fake one.
  final DateTime Function() _clock;

  NotificationStateService({
    required FirebaseFirestore firestore,
    required this.facilityId,
    required this.uid,
    DateTime Function()? clock,
  })  : _firestore = firestore,
        _clock = clock ?? DateTime.now;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(Collections.facilities)
      .doc(facilityId)
      .collection(Collections.notificationState)
      .doc(uid);

  /// My state, live; the empty state while there is no document.
  Stream<NotificationState> watch() => _doc.snapshots().map((s) => NotificationState.fromMap(s.data()));

  Future<void> markRead(Iterable<String> ids) {
    final now = _clock();
    return _write(read: {for (final id in ids) id: now}, unread: {for (final id in ids) id: null});
  }

  Future<void> markUnread(Iterable<String> ids) {
    final now = _clock();
    return _write(unread: {for (final id in ids) id: now}, read: {for (final id in ids) id: null});
  }

  /// Removes [ids] for me; the result is what Undo hands to [restoreRemoved].
  Future<RemovedEntries> remove(Iterable<String> ids) async {
    final current = await _current();
    final now = _clock();
    final previous = {for (final id in ids) id: current.removed[id]};
    await _write(removed: {for (final id in ids) id: now}, current: current);
    return RemovedEntries(previous);
  }

  /// Puts back what [remove] replaced: each entry's earlier time, or none.
  Future<void> restoreRemoved(RemovedEntries previous) => _write(removed: previous.previous);

  /// The stage I read the [type] notice at (only the subscription notice has
  /// stages).
  Future<void> recordSeenStage(NotificationType type, SubscriptionNoticeStage stage) => _write(
      seenStage: {type == NotificationType.subscriptionExpiring ? subscriptionNoticeId : type.name: stage.key});

  Future<NotificationState> _current() async => NotificationState.fromMap((await _doc.get()).data());

  /// One merge: [read], [unread], [removed] map an id to its new time, or to
  /// null to take it off; then the pruning and the bound.
  Future<void> _write({
    Map<String, DateTime?> read = const {},
    Map<String, DateTime?> unread = const {},
    Map<String, DateTime?> removed = const {},
    Map<String, String> seenStage = const {},
    NotificationState? current,
  }) async {
    final state = current ?? await _current();
    final now = _clock();
    final data = <String, Object?>{'updatedAt': FieldValue.serverTimestamp()};
    void plan(String field, Map<String, DateTime> existing, Map<String, DateTime?> changes) {
      final result = Map<String, DateTime>.of(existing);
      final out = <String, Object>{};
      void drop(String id) {
        result.remove(id);
        out[id] = FieldValue.delete();
      }

      changes.forEach((id, time) {
        if (time != null) {
          result[id] = time;
          out[id] = Timestamp.fromDate(time);
        } else if (result.containsKey(id)) {
          drop(id);
        }
      });
      for (final e in [...result.entries]) {
        if (!now.isBefore(e.value.add(AppRanges.notificationStatePrune))) drop(e.key);
      }
      final over = result.length - AppLimits.notificationStateMapMax;
      if (over > 0) {
        final oldestFirst = result.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
        for (final e in oldestFirst.take(over)) {
          drop(e.key);
        }
      }
      if (out.isNotEmpty) data[field] = out;
    }

    plan('read', state.read, read);
    plan('unread', state.unread, unread);
    plan('removed', state.removed, removed);
    if (seenStage.isNotEmpty) data['seenStage'] = seenStage;
    await _doc.set(data, SetOptions(merge: true));
  }
}
