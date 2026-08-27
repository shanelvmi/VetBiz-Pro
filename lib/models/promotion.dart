import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/subscription_status_utils.dart';

/// One subscription discount/offer. The schema itself already
/// supports several promotions coexisting (V2: a real list, priority
/// rules for overlapping offers) - what makes this V1 is purely the
/// rule enforced in code (see setActivePromotion below), not anything
/// about this shape. Getting to V2 means changing that rule and the
/// screen that manages these, not the data or this class.
class Promotion {
  final String id;
  final String label;
  final bool active;
  final double discountPercent;
  // Empty/null means "applies to every plan" - a specific list
  // restricts the discount to just those plan ids.
  final List<String> appliesToPlans;
  // If true, only ever shown to a facility within the same <=7-day
  // "expiring soon" window used throughout the rest of the app (the
  // urgent subscription banner, the notification cards) - a
  // retention offer, not a broadcast one. Ignored when
  // targetFacilityIds is non-empty - see appliesToFacility below.
  final bool targetExpiringOnly;
  // Non-empty means this offer is only ever shown to these specific
  // facilities - a relationship/reward-based offer (e.g. rewarding a
  // facility that consistently pays on time), independent of where
  // they are in their billing cycle. Takes precedence over
  // targetExpiringOnly when set - the two are mutually exclusive at
  // the editor UI level, even though both fields coexist here.
  final List<String> targetFacilityIds;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const Promotion({
    required this.id,
    required this.label,
    required this.active,
    required this.discountPercent,
    required this.appliesToPlans,
    required this.targetExpiringOnly,
    this.targetFacilityIds = const [],
    this.endsAt,
    this.createdAt,
  });

  bool get appliesToAllPlans => appliesToPlans.isEmpty;

  bool appliesToPlan(String planId) => appliesToAllPlans || appliesToPlans.contains(planId);

  bool get isTargetedToSpecificFacilities => targetFacilityIds.isNotEmpty;

  // The single source of truth for whether this offer should show to
  // a given facility right now - specific-facility targeting wins if
  // set, otherwise falls back to the expiring-soon/everyone choice.
  bool appliesToFacility(String facilityId, {required bool isExpiringSoon}) {
    if (isTargetedToSpecificFacilities) return targetFacilityIds.contains(facilityId);
    if (targetExpiringOnly) return isExpiringSoon;
    return true;
  }

  bool get hasEnded => endsAt != null && DateTime.now().isAfter(endsAt!);

  double discountedPrice(double originalPrice) {
    final discounted = originalPrice * (1 - (discountPercent / 100));
    return discounted < 0 ? 0 : discounted;
  }

  factory Promotion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final endsAtField = data['endsAt'];
    final createdAtField = data['createdAt'];
    return Promotion(
      id: doc.id,
      label: (data['label'] as String?) ?? 'Untitled Offer',
      active: data['active'] == true,
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      appliesToPlans: (data['appliesToPlans'] as List?)?.map((e) => e.toString()).toList() ?? [],
      targetExpiringOnly: data['targetExpiringOnly'] == true,
      targetFacilityIds: (data['targetFacilityIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      endsAt: endsAtField is Timestamp ? endsAtField.toDate() : null,
      createdAt: createdAtField is Timestamp ? createdAtField.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'label': label,
        'active': active,
        'discountPercent': discountPercent,
        'appliesToPlans': appliesToPlans,
        'targetExpiringOnly': targetExpiringOnly,
        'targetFacilityIds': targetFacilityIds,
        'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      };
}

/// Live list of every promotion (active or not, ended or not) - for
/// the management screen, which needs to show everything, not just
/// what's currently applicable.
Stream<List<Promotion>> streamAllPromotions() {
  return FirebaseFirestore.instance
      .collection('promotions')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Promotion.fromDoc).toList());
}

/// The one promotion, if any, that should actually be shown to a
/// facility right now - live, so a Platform Admin activating an offer
/// shows up immediately on an already-open Subscription screen, same
/// reasoning as streamSubscriptionPlans(). V1 only ever has one
/// active promotion at a time (enforced in setActivePromotion below),
/// so this just returns that one if it qualifies - V2's "several
/// active, pick the best match" logic would live here without
/// changing anything upstream of this function.
Stream<Promotion?> streamApplicablePromotion({required String facilityId, required bool isExpiringSoon}) {
  return FirebaseFirestore.instance
      .collection('promotions')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    final promo = Promotion.fromDoc(snap.docs.first);
    if (promo.hasEnded) return null;
    if (!promo.appliesToFacility(facilityId, isExpiringSoon: isExpiringSoon)) return null;
    return promo;
  }).handleError((_) {
    // Same reasoning as streamSubscriptionPlans()'s handleError - a
    // transient read error shouldn't surface as a visible error state
    // over what's otherwise a purely cosmetic discount banner.
  });
}

/// Activates the given promotion and deactivates every other one -
/// the actual V1 rule ("only one active at a time"), enforced here in
/// code rather than in the data model itself. This is the one
/// function that changes for V2 (e.g. stop deactivating others,
/// add priority/overlap handling) - everything else in this file
/// already supports it as-is.
Future<void> setActivePromotion(String promoId) async {
  final collection = FirebaseFirestore.instance.collection('promotions');
  final currentlyActive = await collection.where('active', isEqualTo: true).get();

  final batch = FirebaseFirestore.instance.batch();
  for (final doc in currentlyActive.docs) {
    if (doc.id != promoId) {
      batch.update(doc.reference, {'active': false});
    }
  }
  batch.update(collection.doc(promoId), {'active': true});
  await batch.commit();

  final promoDoc = await collection.doc(promoId).get();
  await _notifyFacilitiesOfPromotion(Promotion.fromDoc(promoDoc));
}

// Same <=7-day "expiring soon" definition used throughout the rest of
// the app (the Dashboard banner, the Notifications bell) - never
// disagrees with what those already show for the same facility.
bool _isExpiringSoon(DateTime? expiresAt, DateTime? trialExpiresAt) {
  final status = computeSubscriptionStatus(expiresAt, trialExpiresAt);
  if (status == SubscriptionStatusKind.grace || status == SubscriptionStatusKind.locked) return true;
  if (status != SubscriptionStatusKind.trial && status != SubscriptionStatusKind.active) return false;
  final governingExpiry = expiresAt ?? trialExpiresAt;
  if (governingExpiry == null) return false;
  return governingExpiry.difference(DateTime.now()).inDays <= 7;
}

Future<void> _notifyFacilitiesOfPromotion(Promotion promo) async {
  final List<String> targetFacilityIds;

  if (promo.isTargetedToSpecificFacilities) {
    targetFacilityIds = promo.targetFacilityIds;
  } else {
    // Applies broadly (everyone, or everyone currently expiring soon) -
    // evaluated once, right now, against every facility's current
    // subscription status. A facility that becomes expiring-soon later
    // won't get this one-time notification, though the live bell/banner
    // elsewhere will still correctly reflect the offer applying to them
    // by then regardless.
    final facilitiesSnap = await FirebaseFirestore.instance.collection('facilities').get();
    targetFacilityIds = facilitiesSnap.docs.where((doc) {
      final data = doc.data();
      final expiresAtField = data['subscriptionExpiresAt'];
      final trialExpiresAtField = data['trialExpiresAt'];
      final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
      final trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;
      final isExpiringSoon = _isExpiringSoon(expiresAt, trialExpiresAt);
      return promo.appliesToFacility(doc.id, isExpiringSoon: isExpiringSoon);
    }).map((doc) => doc.id).toList();
  }

  if (targetFacilityIds.isEmpty) return;

  final firestore = FirebaseFirestore.instance;
  final message = '${promo.discountPercent.toStringAsFixed(0)}% off your next subscription payment.';

  // Chunked defensively - Firestore caps a single batch at 500 writes,
  // and this platform's facility count could plausibly grow past that
  // over time even if it's nowhere close today.
  for (var i = 0; i < targetFacilityIds.length; i += 400) {
    final chunk = targetFacilityIds.sublist(i, i + 400 > targetFacilityIds.length ? targetFacilityIds.length : i + 400);
    final batch = firestore.batch();
    for (final facilityId in chunk) {
      final ref = firestore.collection('facilities').doc(facilityId).collection('notifications').doc();
      batch.set(ref, {
        'type': 'promotion',
        'title': promo.label,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': promo.endsAt != null ? Timestamp.fromDate(promo.endsAt!) : null,
      });
    }
    await batch.commit();
  }
}
