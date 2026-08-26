import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/subscription_plans.dart';

enum SubscriptionStatus { trial, active, grace, locked }

/// Tracks one facility's subscription status in real time. Deliberately
/// self-contained and separate from FacilityProvider - swapping manual
/// payment review for an automated push-payment flow later only means
/// changing what writes `subscriptionExpiresAt` on the facility document
/// (a Cloud Function instead of an admin approving a submission by hand);
/// nothing here, or anywhere else in the app that reads subscription
/// status, needs to change.
class SubscriptionProvider with ChangeNotifier {
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

  String get statusLabel {
    switch (_status) {
      case SubscriptionStatus.trial:
        return _trialExpiresAt != null ? 'Trial' : 'Trial - no subscription set up yet';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.grace:
        return 'Payment overdue - grace period';
      case SubscriptionStatus.locked:
        return 'Locked - subscription expired';
    }
  }

  void listenToFacility(String facilityId) {
    if (_facilityId == facilityId && _subscription != null) return;

    _facilityId = facilityId;
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('facilities')
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
      final graceEnd = _expiresAt!.add(const Duration(days: kGracePeriodDays));
      if (now.isBefore(graceEnd)) return SubscriptionStatus.grace;
      return SubscriptionStatus.locked;
    }

    if (_trialExpiresAt != null) {
      if (now.isBefore(_trialExpiresAt!)) return SubscriptionStatus.trial;
      final graceEnd = _trialExpiresAt!.add(const Duration(days: kGracePeriodDays));
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
