import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_limits.dart';
import '../config/app_ranges.dart';
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

  factory SubscriptionFacts.of(SubscriptionProvider p) {
    final stage = p.attentionStage;
    final end = p.expiresAt;
    return SubscriptionFacts(
      stage: stage,
      notice: stage == SubscriptionNoticeStage.none ? null : p.attentionNoticeShown,
      trialInfo: p.trialInfoNotice,
      cycleStart: end?.subtract(AppRanges.day * SubscriptionProvider.attentionThresholdDays),
    );
  }
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

/// The subscription notice is read for me only at the stage I read it at
/// (P3; a stage, not the English wording, so "7 days" then "6 days" stays
/// read and a language switch changes nothing), and only in this cycle.
bool _noticeReadByMe(NotificationState state, SubscriptionFacts s) {
  if (state.unread.containsKey(subscriptionNoticeId)) return false;
  final readAt = state.read[subscriptionNoticeId];
  if (readAt == null) return false;
  if (s.cycleStart != null && readAt.isBefore(s.cycleStart!)) return false;
  final seen = SubscriptionNoticeStage.fromKey(state.seenStage[subscriptionNoticeId]);
  if (seen == null) return false;
  return !NotificationPolicy.isUnreadAgain(seenStage: seen, current: s.stage);
}

bool _newerClaimThan(LatestClaim? claim, DateTime? createdAt) =>
    claim != null && !claim.rejected && claim.submittedAt != null && createdAt != null && claim.submittedAt!.isAfter(createdAt);

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
}) {
  final out = <NotificationItem>[];
  final since = liveRowsSince ?? now;
  final trial = subscription.trialInfo;
  if (trial != null) {
    out.add(NotificationItem(
      FacilityNotification(
          id: trialStatusRowId, type: NotificationType.trialStatus, title: trial.title, message: trial.message, createdAt: since),
      isRead: state.isReadByMe(trialStatusRowId),
    ));
  }
  // The stored notice (checkSubscriptionExpiry, once a day) lags the live
  // state, so the live provider is the source of truth: one row, the live
  // wording, the stored document's date when there is one. It no longer has
  // to be inserted already read: my read state is keyed by id, not written
  // on the document, so a row with no document can be read like any other.
  final notice = subscription.notice;
  if (subscription.stage != SubscriptionNoticeStage.none && notice != null) {
    final storedNotice = stored.where((n) => n.type == NotificationType.subscriptionExpiring).firstOrNull;
    out.add(NotificationItem(
      FacilityNotification(
        id: subscriptionNoticeId,
        type: NotificationType.subscriptionExpiring,
        title: notice.title,
        message: notice.message,
        createdAt: storedNotice?.createdAt ?? since,
      ),
      isRead: _noticeReadByMe(state, subscription),
    ));
  }

  for (final n in stored) {
    if (n.type == NotificationType.subscriptionExpiring) continue;
    if (NotificationPolicy.isNeverShown(n.type) || !n.isVisibleTo(uid: uid, isAdmin: isAdmin)) continue;
    final cls = NotificationPolicy.classOf(n.type);
    if (cls == NotificationClass.persistent) {
      final facts = PersistentFacts(
        subscriptionStage: subscription.stage,
        inCalmTrial: trial != null,
        newerClaimExists: _newerClaimThan(latestClaim, n.createdAt),
      );
      if (NotificationPolicy.isResolved(n.type, facts)) continue;
    } else {
      if (state.isRemoved(n.id)) continue;
      if (n.expiresAt != null && !now.isBefore(n.expiresAt!)) continue;
      final hidden = NotificationPolicy.isHiddenByAge(
        cls: cls,
        now: now,
        createdAt: n.createdAt,
        myReadAt: state.read[n.id],
        sharedReadAt: n.readAt,
        markedUnread: state.unread.containsKey(n.id),
        endsAt: n.expiresAt,
      );
      if (hidden) continue;
    }
    out.add(NotificationItem(n, isRead: state.isReadByMe(n.id, sharedReadAt: n.readAt)));
  }
  return out;
}

/// Whether I removed the newest stored notification of the live promotion
/// called [promotionLabel], so the bell's accent stays off for me. Both are
/// stored values (the notification's title is the promotion's label as
/// written by _notifyFacilitiesOfPromotion); a NEW promotion writes a new
/// notification, which I have not removed.
bool isPromotionDismissed({
  required String promotionLabel,
  required List<FacilityNotification> stored,
  required NotificationState state,
}) {
  FacilityNotification? newest;
  for (final n in stored) {
    if (n.type != NotificationType.promotion || n.title != promotionLabel) continue;
    final t = n.createdAt;
    if (newest == null || (t != null && (newest.createdAt == null || t.isAfter(newest.createdAt!)))) newest = n;
  }
  return newest != null && state.isRemoved(newest.id);
}

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
