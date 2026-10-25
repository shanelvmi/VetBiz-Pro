import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/collections.dart';
import '../data/subscription_notice_stage.dart';
import '../config/app_rules.dart';
import '../config/app_date_format.dart';
import '../l10n/l10n.dart';

enum SubscriptionStatus { trial, active, grace, locked }

/// Tracks one facility's subscription status in real time. Deliberately
/// self-contained and separate from FacilityProvider - swapping manual
/// payment review for an automated push-payment flow later only means
/// changing what writes `subscriptionExpiresAt` on the facility document
/// (a Cloud Function instead of an admin approving a submission by hand);
/// nothing here, or anywhere else in the app that reads subscription
/// status, needs to change.
class SubscriptionProvider with ChangeNotifier {
  SubscriptionProvider({FirebaseFirestore? firestore}) : _firestore = firestore;

  // Null: the app's own Firestore. Tests pass an in-memory one (REFRESH-1).
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _subscription;
  String? _facilityId;

  DateTime? _expiresAt;
  DateTime? _trialExpiresAt;
  String? _planId;

  SubscriptionStatus _status = SubscriptionStatus.trial;
  SubscriptionStatus get status => _status;

  /// The date actually governing the current status - a real
  /// subscription date takes priority whenever one exists, otherwise a
  /// real timed trial's own end date. Null means this facility has
  /// neither (created before the trial-length feature existed, or
  /// deliberately left on the old, indefinite trial) - never
  /// retroactively assigned one just to have something to show.
  DateTime? get expiresAt => _expiresAt ?? _trialExpiresAt;
  String? get planId => _planId;

  bool get isLocked => _status == SubscriptionStatus.locked;
  bool get isReadOnly => _status == SubscriptionStatus.locked;
  bool get isInGracePeriod => _status == SubscriptionStatus.grace;

  int? get daysRemaining {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inHours >= 0 ? (diff.inHours / 24).ceil() : -((-diff.inHours) / 24).ceil();
  }

  /// How many days out an active/trial period starts counting as
  /// "needs attention" - the same 7 the Dashboard banner and bell
  /// already use, and kAttentionThresholdDays in the
  /// checkSubscriptionExpiry Cloud Function.
  static const int attentionThresholdDays = AppRules.subscriptionAttentionDays;

  /// The CALM trial: still in the free trial, with no urgency yet - more than a
  /// week left, or no end date at all.
  ///
  /// This is the ONE definition of that state. The bell's blue blink, the
  /// Dashboard's blue "View Plans" pill and the Notifications lists all use it,
  /// so they can't disagree. They used to: the bell and pill each worked it out
  /// for themselves while the lists only knew about the subscription notice, which is
  /// empty for exactly this state - so the bell blinked blue for the whole
  /// trial with nothing in the dropdown or on the Notifications screen to say
  /// why.
  bool get isInCalmTrial => _status == SubscriptionStatus.trial && attentionStage == SubscriptionNoticeStage.none;

  /// What to tell someone in the calm trial - the message the blue blink is
  /// about. Live, like [attentionNoticeShown]: the days left are worked out now, not
  /// read from something written once and left to go stale. Only shown, never
  /// compared, so it is in the current language.
  ({String title, String message})? get trialInfoNotice {
    if (!isInCalmTrial) return null;
    final l = L10n.current;
    final end = expiresAt;
    final days = daysRemaining;
    if (end == null || days == null) {
      return (title: l.subscription_freeTrialTitle, message: l.subscription_onFreeTrial);
    }
    return (
      title: l.subscription_freeTrialTitle,
      message: l.subscription_trialDaysLeftEnding(days, AppDateFormat.dateNoPad.format(end)),
    );
  }

  /// How far the subscription notice has escalated, as a stored key (NOTIF-2b):
  /// what a person's seenStage is compared with. Since NOTIF-2c the only
  /// escalation test: the English message is no longer compared.
  SubscriptionNoticeStage get attentionStage {
    switch (_status) {
      case SubscriptionStatus.locked:
        return SubscriptionNoticeStage.locked;
      case SubscriptionStatus.grace:
        return SubscriptionNoticeStage.grace;
      case SubscriptionStatus.trial:
      case SubscriptionStatus.active:
        final days = daysRemaining;
        return (days == null || days > attentionThresholdDays) ? SubscriptionNoticeStage.none : SubscriptionNoticeStage.expiring;
    }
  }

  /// The subscription notice that applies RIGHT NOW, or null when
  /// nothing needs attention (comfortably active, an open trial with no
  /// end date, or just renewed). Derived live from the same state the
  /// Dashboard banner and Subscription screen read, so a screen showing
  /// this can never disagree with them - the stored
  /// notifications/subscription_expiring document is a once-a-day
  /// snapshot written by the Cloud Function at 00:30, which is what let
  /// Notifications say "1 day left" while the banner already said
  /// "grace period". Wording matches that function exactly, so
  /// switching the source doesn't change what anyone reads.
  ///
  /// In the current language: it is only shown, never compared
  /// ([attentionStage] says whether it escalated; NOTIF-2c retired the
  /// English copy the Notifications screen used to compare).
  ({String title, String message})? get attentionNoticeShown => _attentionNoticeIn(L10n.current);

  ({String title, String message})? _attentionNoticeIn(AppLocalizations l) {
    // Same rule the function uses: no paid cycle date means this is a
    // trial, even after that trial has run out (status is then grace
    // or locked, so status alone can't tell them apart).
    final isTrial = _expiresAt == null;
    final endedTitle = isTrial ? l.subscription_trialEndedTitle : l.subscription_expiredTitle;

    switch (_status) {
      case SubscriptionStatus.locked:
        return (
          title: endedTitle,
          message: isTrial ? l.subscription_trialEndedReadOnly : l.subscription_expiredReadOnly,
        );
      case SubscriptionStatus.grace:
        return (
          title: endedTitle,
          message: isTrial ? l.subscription_trialEndedGrace : l.subscription_expiredGrace,
        );
      case SubscriptionStatus.trial:
      case SubscriptionStatus.active:
        final days = daysRemaining;
        if (days == null || days > attentionThresholdDays) return null;
        return isTrial
            ? (title: l.subscription_trialExpiringSoonTitle, message: l.subscription_trialExpiresIn(days))
            : (title: l.subscription_expiringSoonTitle, message: l.subscription_expiresIn(days));
    }
  }

  /// Shown on the Subscription screen, in the current language.
  String get statusLabel {
    final l = L10n.current;
    switch (_status) {
      case SubscriptionStatus.trial:
        return _trialExpiresAt != null ? l.subscription_statusTrial : l.subscription_statusTrialNoSetup;
      case SubscriptionStatus.active:
        return l.subscription_statusActive;
      case SubscriptionStatus.grace:
        return l.subscription_statusGrace;
      case SubscriptionStatus.locked:
        return l.subscription_statusLocked;
    }
  }

  void listenToFacility(String facilityId) {
    if (_facilityId == facilityId && _subscription != null) return;

    _facilityId = facilityId;
    _subscription?.cancel();

    _subscription = _db
        .collection(Collections.facilities)
        .doc(facilityId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      _planId = data?['subscriptionPlan'] as String?;

      final expiresAtField = data?['subscriptionExpiresAt'];
      _expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;

      final trialExpiresAtField = data?['trialExpiresAt'];
      _trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;

      _status = _computeStatus();
      notifyListeners();
    }, onError: (e) {
      debugPrint('SubscriptionProvider listen error: $e');
    });
  }

  /// No paid subscription cycle takes priority whenever it exists. With
  /// none, a real timed trial counts down the same way, reusing the
  /// same grace/locked flow once it runs out. With neither set at all,
  /// this facility has never had a subscription cycle and has no timed
  /// trial either (created before this feature existed) - treated as
  /// an open trial, not locked, so this never silently locks out an
  /// existing shop, and never retroactively changes one either.
  SubscriptionStatus _computeStatus() {
    final now = DateTime.now();

    if (_expiresAt != null) {
      if (now.isBefore(_expiresAt!)) return SubscriptionStatus.active;
      final graceEnd = _expiresAt!.add(AppRules.gracePeriod);
      if (now.isBefore(graceEnd)) return SubscriptionStatus.grace;
      return SubscriptionStatus.locked;
    }

    if (_trialExpiresAt != null) {
      if (now.isBefore(_trialExpiresAt!)) return SubscriptionStatus.trial;
      final graceEnd = _trialExpiresAt!.add(AppRules.gracePeriod);
      if (now.isBefore(graceEnd)) return SubscriptionStatus.grace;
      return SubscriptionStatus.locked;
    }

    return SubscriptionStatus.trial;
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _expiresAt = null;
    _trialExpiresAt = null;
    _planId = null;
    _status = SubscriptionStatus.trial;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
