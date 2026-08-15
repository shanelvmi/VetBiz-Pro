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
  String? _planId;

  SubscriptionStatus _status = SubscriptionStatus.trial;
  SubscriptionStatus get status => _status;

  DateTime? get expiresAt => _expiresAt;
  String? get planId => _planId;

  bool get isLocked => _status == SubscriptionStatus.locked;
  bool get isReadOnly => _status == SubscriptionStatus.locked;
  bool get isInGracePeriod => _status == SubscriptionStatus.grace;

  int? get daysRemaining {
    if (_expiresAt == null) return null;
    final diff = _expiresAt!.difference(DateTime.now());
    return diff.inHours >= 0 ? (diff.inHours / 24).ceil() : -((-diff.inHours) / 24).ceil();
  }

  String get statusLabel {
    switch (_status) {
      case SubscriptionStatus.trial:
        return 'Trial - no subscription set up yet';
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

      _status = _computeStatus(_expiresAt);
      notifyListeners();
    }, onError: (e) {
      debugPrint('SubscriptionProvider listen error: $e');
    });
  }

  /// No expiry set at all means this facility has never had a
  /// subscription cycle yet (brand new, or rolled out before this
  /// feature existed) - treated as an open trial, not locked, so this
  /// never silently locks out an existing shop the moment it ships.
  SubscriptionStatus _computeStatus(DateTime? expiresAt) {
    if (expiresAt == null) return SubscriptionStatus.trial;

    final now = DateTime.now();
    if (now.isBefore(expiresAt)) return SubscriptionStatus.active;

    final graceEnd = expiresAt.add(const Duration(days: kGracePeriodDays));
    if (now.isBefore(graceEnd)) return SubscriptionStatus.grace;

    return SubscriptionStatus.locked;
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _expiresAt = null;
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
