import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/subscription_notice_stage.dart';
import '../models/notification_model.dart' show NotificationType;
import '../models/notification_state.dart';

/// Reads and writes one person's own notification state in one facility
/// (NOTIF-2b; docs/design/notifications.md, section 2, approved).
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

  Stream<NotificationState> watch() => throw UnimplementedError('NOTIF-2b');

  Future<void> markRead(Iterable<String> ids) => throw UnimplementedError('NOTIF-2b');

  Future<void> markUnread(Iterable<String> ids) => throw UnimplementedError('NOTIF-2b');

  /// Removes [ids] for me; the result is what Undo hands to [restoreRemoved].
  Future<RemovedEntries> remove(Iterable<String> ids) => throw UnimplementedError('NOTIF-2b');

  Future<void> restoreRemoved(RemovedEntries previous) => throw UnimplementedError('NOTIF-2b');

  Future<void> recordSeenStage(NotificationType type, SubscriptionNoticeStage stage) =>
      throw UnimplementedError('NOTIF-2b');

  // Kept until the implementation uses them.
  // ignore: unused_element
  FirebaseFirestore get _db => _firestore;
  // ignore: unused_element
  DateTime _now() => _clock();
}
