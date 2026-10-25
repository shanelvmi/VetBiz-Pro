import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_limits.dart';
import '../data/subscription_notice_stage.dart';
import '../models/notification_model.dart';
import '../models/notification_policy.dart';
import '../models/notification_state.dart';
import '../providers/subscription_provider.dart';

/// The id of the live free-trial row (never stored).
const String trialStatusRowId = 'trial_status';

/// What the live subscription says right now (SubscriptionProvider): the
/// stage the notice is at, its text in the current language, the calm
/// trial's text, and when this cycle's notice began.
class SubscriptionFacts {
  final SubscriptionNoticeStage stage;
  final ({String title, String message})? notice;
  final ({String title, String message})? trialInfo;

  /// When the current cycle's "expiring" stage began (the end date minus
  /// the attention window). A read before it belongs to an earlier cycle.
  final DateTime? cycleStart;

  const SubscriptionFacts({this.stage = SubscriptionNoticeStage.none, this.notice, this.trialInfo, this.cycleStart});

  static const SubscriptionFacts none = SubscriptionFacts();

  factory SubscriptionFacts.of(SubscriptionProvider p) => throw UnimplementedError('NOTIF-2c');
}

/// The newest subscription payment claim: when it was sent, and whether
/// it was rejected (a pending or approved one resolves an older rejection).
class LatestClaim {
  final DateTime? submittedAt;
  final bool rejected;
  const LatestClaim({this.submittedAt, this.rejected = false});
}

/// One row as I see it: the notification (live rows in the current
/// language) and whether I have read it.
class NotificationItem {
  final FacilityNotification notification;
  final bool isRead;

  const NotificationItem(this.notification, {required this.isRead});

  String get id => notification.id;
  NotificationType get type => notification.type;
  NotificationClass get cls => NotificationPolicy.classOf(notification.type);
  bool get canRemove => NotificationPolicy.canRemove(notification.type);
  PersistentReason? get persistentReason => NotificationPolicy.persistentReason(notification.type);
  bool get hasTarget => notification.relatedEntityType != null && notification.relatedEntityId != null;
}

/// The rows I see, newest first after the live rows (the trial, then the
/// subscription notice): only what is for me, not removed by me, within its
/// lifetime and not resolved (NotificationPolicy).
List<NotificationItem> buildNotificationItems({
  required List<FacilityNotification> stored,
  required NotificationState state,
  required String? uid,
  required bool isAdmin,
  required SubscriptionFacts subscription,
  required DateTime now,
  LatestClaim? latestClaim,
  DateTime? liveRowsSince,
}) =>
    throw UnimplementedError('NOTIF-2c');

/// Whether I removed the newest stored notification of the live promotion
/// called [promotionLabel], so the bell's accent stays off for me.
bool isPromotionDismissed({
  required String promotionLabel,
  required List<FacilityNotification> stored,
  required NotificationState state,
}) =>
    throw UnimplementedError('NOTIF-2c');

/// The Notifications screen's and the dropdown's data (NOTIF-2c): my
/// notifications and my own state, live, built into rows through
/// [buildNotificationItems], and every action as one state write.
class NotificationFeedController extends ChangeNotifier {
  final FirebaseFirestore firestore;
  final String facilityId;
  final String uid;
  final bool Function() _isAdmin;
  final SubscriptionFacts Function() _subscription;
  final Listenable? _subscriptionChanges;
  final int window;
  final int olderPage;
  final DateTime Function() _clock;

  NotificationFeedController({
    required this.firestore,
    required this.facilityId,
    required this.uid,
    required bool Function() isAdmin,
    SubscriptionFacts Function()? subscription,
    Listenable? subscriptionChanges,
    this.window = AppLimits.notificationsWindow,
    this.olderPage = AppLimits.notificationsOlderPage,
    DateTime Function()? clock,
  })  : _isAdmin = isAdmin,
        _subscription = subscription ?? (() => SubscriptionFacts.none),
        _subscriptionChanges = subscriptionChanges,
        _clock = clock ?? DateTime.now;

  void start() => throw UnimplementedError('NOTIF-2c ${_isAdmin.hashCode} ${_subscription.hashCode} '
      '${_subscriptionChanges.hashCode} ${_clock.hashCode}');

  bool get isLoading => throw UnimplementedError('NOTIF-2c');
  Object? get error => throw UnimplementedError('NOTIF-2c');

  List<NotificationItem> get items => throw UnimplementedError('NOTIF-2c');
  List<NotificationItem> get planNotices => throw UnimplementedError('NOTIF-2c');
  List<NotificationItem> get needsAttention => throw UnimplementedError('NOTIF-2c');
  List<NotificationItem> get earlier => throw UnimplementedError('NOTIF-2c');
  bool get hasUnread => throw UnimplementedError('NOTIF-2c');

  /// My read items that may be removed ("Remove read ones"); never persistent.
  List<NotificationItem> get readRemovable => throw UnimplementedError('NOTIF-2c');

  bool get canLoadOlder => throw UnimplementedError('NOTIF-2c');
  bool get isLoadingOlder => throw UnimplementedError('NOTIF-2c');
  Future<void> loadOlder() => throw UnimplementedError('NOTIF-2c');

  /// Re-applies the lifetimes at the clock's time now.
  void refresh() => throw UnimplementedError('NOTIF-2c');

  Future<void> markRead(Iterable<NotificationItem> items) => throw UnimplementedError('NOTIF-2c');
  Future<void> markUnread(NotificationItem item) => throw UnimplementedError('NOTIF-2c');
  Future<void> toggleRead(NotificationItem item) => throw UnimplementedError('NOTIF-2c');
  Future<void> markAllRead() => throw UnimplementedError('NOTIF-2c');

  /// Removes [items] for me (persistent ones are skipped); the result is
  /// what [restore] puts back.
  Future<RemovedEntries> remove(Iterable<NotificationItem> items) => throw UnimplementedError('NOTIF-2c');
  Future<void> restore(RemovedEntries entries) => throw UnimplementedError('NOTIF-2c');
}
