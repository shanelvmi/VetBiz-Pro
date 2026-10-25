import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_limits.dart';
import '../config/app_ranges.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/payment_submission_status.dart';
import '../data/subscription_notice_stage.dart';
import '../models/notification_model.dart';
import '../models/notification_policy.dart';
import '../models/notification_state.dart';
import '../providers/subscription_provider.dart';
import 'notification_state_service.dart';

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
/// [buildNotificationItems], and every action as one state write
/// (NotificationStateService). Each action shows at once (applied to the
/// state here first) and the listener then brings the stored result.
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
  final NotificationStateService _service;

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
        _clock = clock ?? DateTime.now,
        _service = NotificationStateService(firestore: firestore, facilityId: facilityId, uid: uid, clock: clock);

  final List<StreamSubscription<Object?>> _subs = [];
  bool _started = false;
  bool _disposed = false;
  bool _notificationsLoaded = false;
  bool _stateLoaded = false;
  Object? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _live = const [];
  final List<FacilityNotification> _older = [];
  DocumentSnapshot<Map<String, dynamic>>? _olderCursor;
  bool _olderDone = false;
  bool _loadingOlder = false;
  NotificationState _confirmed = NotificationState.empty;
  NotificationState _state = NotificationState.empty;
  LatestClaim? _latestClaim;
  DateTime? _liveSince;
  List<FacilityNotification> _stored = const [];
  List<NotificationItem> _items = const [];

  CollectionReference<Map<String, dynamic>> _facilityCollection(String name) =>
      firestore.collection(Collections.facilities).doc(facilityId).collection(name);

  Query<Map<String, dynamic>> get _newestFirst =>
      _facilityCollection(Collections.notifications).orderBy(Fields.createdAt, descending: true);

  /// Starts listening; calling it again does nothing.
  void start() {
    if (_started) return;
    _started = true;
    _subs.add(_newestFirst.limit(window).snapshots().listen((s) {
      _live = s.docs;
      _notificationsLoaded = true;
      _rebuild();
    }, onError: (Object e) {
      _error = e;
      _notificationsLoaded = true;
      _rebuild();
    }));
    _subs.add(_service.watch().listen((s) {
      _confirmed = s;
      _state = s;
      _stateLoaded = true;
      _rebuild();
    }, onError: (Object e) {
      // Without my state the lists still work, as for someone who has done
      // nothing yet (unread, nothing removed).
      debugPrint('[NOTIFICATIONS] state: $e');
      _stateLoaded = true;
      _rebuild();
    }));
    _subs.add(_facilityCollection(Collections.paymentSubmissions)
        .orderBy(Fields.submittedAt, descending: true)
        .limit(AppLimits.single)
        .snapshots()
        .listen((s) {
      final data = s.docs.firstOrNull?.data();
      final at = data?[Fields.submittedAt];
      _latestClaim = data == null
          ? null
          : LatestClaim(
              submittedAt: at is Timestamp ? at.toDate() : null,
              rejected: data[Fields.status] == PaymentSubmissionStatus.rejected.key,
            );
      _rebuild();
    }, onError: (Object e) => debugPrint('[NOTIFICATIONS] claims: $e')));
    _subscriptionChanges?.addListener(_rebuild);
  }

  bool get isLoading => !_notificationsLoaded || !_stateLoaded;
  Object? get error => _error;

  List<NotificationItem> get items => _items;
  List<NotificationItem> get planNotices => _items.where((i) => i.type == NotificationType.trialStatus).toList();
  List<NotificationItem> get needsAttention => _items
      .where((i) => i.notification.category != NotificationCategory.other && i.type != NotificationType.trialStatus)
      .toList();
  List<NotificationItem> get earlier =>
      _items.where((i) => i.notification.category == NotificationCategory.other).toList();
  bool get hasUnread => _items.any((i) => !i.isRead);

  /// The bell's red dot: something unread for me (the calm trial is the
  /// blue dot, not this).
  bool get hasUnreadAlert => _items.any((i) => !i.isRead && i.type != NotificationType.trialStatus);

  /// The bell's accent: whether I removed the live promotion's notification.
  bool isPromotionDismissedForMe(String promotionLabel) =>
      isPromotionDismissed(promotionLabel: promotionLabel, stored: _stored, state: _state);

  /// My read items that may be removed ("Remove read ones"); never persistent.
  List<NotificationItem> get readRemovable => _items.where((i) => i.isRead && i.canRemove).toList();

  bool get canLoadOlder => !_olderDone && _live.length >= window;
  bool get isLoadingOlder => _loadingOlder;

  Future<void> loadOlder() async {
    if (!canLoadOlder || _loadingOlder) return;
    _loadingOlder = true;
    _notify();
    try {
      final cursor = _olderCursor ?? _live.last;
      final snap = await _newestFirst.startAfterDocument(cursor).limit(olderPage).get();
      _older.addAll(snap.docs.map(FacilityNotification.fromFirestore));
      if (snap.docs.isNotEmpty) _olderCursor = snap.docs.last;
      if (snap.docs.length < olderPage) _olderDone = true;
    } finally {
      _loadingOlder = false;
      _rebuild();
    }
  }

  /// Re-applies the lifetimes at the clock's time now.
  void refresh() => _rebuild();

  Future<void> markRead(Iterable<NotificationItem> items) async {
    final ids = items.map((i) => i.id).toSet();
    if (ids.isEmpty) return;
    final now = _clock();
    final stage = _subscription().stage;
    final notice = ids.contains(subscriptionNoticeId) && stage != SubscriptionNoticeStage.none;
    _patch(
      read: {for (final id in ids) id: now},
      unread: {for (final id in ids) id: null},
      seenStage: notice ? {subscriptionNoticeId: stage.key} : const {},
    );
    await _guard(() async {
      await _service.markRead(ids);
      if (notice) await _service.recordSeenStage(NotificationType.subscriptionExpiring, stage);
    });
  }

  Future<void> markUnread(NotificationItem item) async {
    _patch(unread: {item.id: _clock()}, read: {item.id: null});
    await _guard(() => _service.markUnread([item.id]));
  }

  Future<void> toggleRead(NotificationItem item) => item.isRead ? markUnread(item) : markRead([item]);

  Future<void> markAllRead() => markRead(_items.where((i) => !i.isRead));

  /// Removes [items] for me (persistent ones are skipped); the result is
  /// what [restore] puts back.
  Future<RemovedEntries> remove(Iterable<NotificationItem> items) async {
    final ids = items.where((i) => i.canRemove).map((i) => i.id).toSet();
    if (ids.isEmpty) return const RemovedEntries({});
    _patch(removed: {for (final id in ids) id: _clock()});
    late RemovedEntries entries;
    await _guard(() async => entries = await _service.remove(ids));
    return entries;
  }

  Future<void> restore(RemovedEntries entries) async {
    if (entries.previous.isEmpty) return;
    _patch(removed: entries.previous);
    await _guard(() => _service.restoreRemoved(entries));
  }

  /// A failed write puts the stored state back on screen, then rethrows
  /// for the screen to say so.
  Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      _state = _confirmed;
      _rebuild();
      rethrow;
    }
  }

  void _patch({
    Map<String, DateTime?> read = const {},
    Map<String, DateTime?> unread = const {},
    Map<String, DateTime?> removed = const {},
    Map<String, String> seenStage = const {},
  }) {
    Map<String, DateTime> apply(Map<String, DateTime> base, Map<String, DateTime?> changes) {
      final out = Map<String, DateTime>.of(base);
      changes.forEach((id, t) {
        if (t == null) {
          out.remove(id);
        } else {
          out[id] = t;
        }
      });
      return out;
    }

    _state = NotificationState(
      read: apply(_state.read, read),
      unread: apply(_state.unread, unread),
      removed: apply(_state.removed, removed),
      seenStage: {..._state.seenStage, ...seenStage},
    );
    _rebuild();
  }

  void _rebuild() {
    if (_disposed) return;
    final now = _clock();
    _liveSince ??= now;
    final liveIds = {for (final d in _live) d.id};
    _stored = [
      ..._live.map(FacilityNotification.fromFirestore),
      ..._older.where((n) => !liveIds.contains(n.id)),
    ];
    _items = buildNotificationItems(
      stored: _stored,
      state: _state,
      uid: uid,
      isAdmin: _isAdmin(),
      subscription: _subscription(),
      now: now,
      latestClaim: _latestClaim,
      liveRowsSince: _liveSince,
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subscriptionChanges?.removeListener(_rebuild);
    super.dispose();
  }
}
