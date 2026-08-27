import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription plan definitions. Prices below are the fallback
/// defaults used only until a Platform Admin sets real ones via the
/// Overview tab's Pricing card (stored in platform_config/settings) -
/// see loadSubscriptionPlans(). Kept in one place so the Subscription
/// screen and the admin review screen never disagree about what a
/// plan actually costs or how long it lasts.
class SubscriptionPlan {
  final String id; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final String label;
  final int durationDays;
  final double priceTsh;

  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.durationDays,
    required this.priceTsh,
  });
}

// A neutral shape template - id, label, and duration are fixed, but
// price is deliberately 0 here. This is never meant to be shown as a
// real, payable price; it only surfaces if a Platform Admin hasn't
// configured a price yet, or the fetch genuinely fails - see
// loadSubscriptionPlans()/streamSubscriptionPlans() below, both of
// which are the actual source of truth for what a plan costs.
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(id: 'daily', label: 'Daily', durationDays: 1, priceTsh: 0),
  SubscriptionPlan(id: 'weekly', label: 'Weekly', durationDays: 7, priceTsh: 0),
  SubscriptionPlan(id: 'monthly', label: 'Monthly', durationDays: 30, priceTsh: 0),
  SubscriptionPlan(id: 'yearly', label: 'Yearly', durationDays: 365, priceTsh: 0),
];

SubscriptionPlan? planById(String id) {
  for (final plan in kSubscriptionPlans) {
    if (plan.id == id) return plan;
  }
  return null;
}

// Firestore field name for each plan's Platform-Admin-configured
// price, e.g. platform_config/settings.dailyPriceTsh.
String _priceFieldFor(String planId) => '${planId}PriceTsh';

/// The current plans, with each price overridden by whatever a
/// Platform Admin has configured in platform_config/settings, if
/// anything - falls back to the static defaults above for any plan
/// that hasn't been configured yet (or if the read fails entirely,
/// e.g. offline), so this always returns something usable.
Future<List<SubscriptionPlan>> loadSubscriptionPlans() async {
  try {
    final doc = await FirebaseFirestore.instance.collection('platform_config').doc('settings').get();
    final data = doc.data();
    if (data == null) return kSubscriptionPlans;

    return kSubscriptionPlans.map((plan) {
      final configured = (data[_priceFieldFor(plan.id)] as num?)?.toDouble();
      if (configured == null) return plan;
      return SubscriptionPlan(
        id: plan.id,
        label: plan.label,
        durationDays: plan.durationDays,
        priceTsh: configured,
      );
    }).toList();
  } catch (e) {
    return kSubscriptionPlans;
  }
}

Future<SubscriptionPlan?> loadPlanById(String id) async {
  final plans = await loadSubscriptionPlans();
  for (final plan in plans) {
    if (plan.id == id) return plan;
  }
  return null;
}

/// Same merged result as loadSubscriptionPlans(), but live - emits a
/// fresh list whenever platform_config/settings changes, not just
/// once. For the Subscription screen specifically: a Platform Admin
/// changing a price while someone already has that screen open should
/// show up immediately, not require closing and reopening it. Other
/// consumers that just need a one-off read (e.g. the Platform Admin's
/// own facility detail screen) should keep using
/// loadSubscriptionPlans() instead - they don't need an open listener
/// for a screen visited briefly.
Stream<List<SubscriptionPlan>> streamSubscriptionPlans() {
  return FirebaseFirestore.instance
      .collection('platform_config')
      .doc('settings')
      .snapshots()
      .map((doc) {
    final data = doc.data();
    if (data == null) return kSubscriptionPlans;

    return kSubscriptionPlans.map((plan) {
      final configured = (data[_priceFieldFor(plan.id)] as num?)?.toDouble();
      if (configured == null) return plan;
      return SubscriptionPlan(
        id: plan.id,
        label: plan.label,
        durationDays: plan.durationDays,
        priceTsh: configured,
      );
    }).toList();
  }).transform(
    StreamTransformer<List<SubscriptionPlan>, List<SubscriptionPlan>>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      // A genuine, possibly persistent read failure (not just a
      // transient blip) still needs to actually reach the screen as a
      // real data event - the 0-priced fallback plans - rather than
      // being silently swallowed with no emission at all. Silently
      // dropping the error here (as this used to do) left the
      // screen's own listener callback never firing at all if the
      // very first fetch attempt failed, which meant its loading
      // spinner had nothing to ever turn off - it would spin forever.
      handleError: (error, stackTrace, sink) => sink.add(kSubscriptionPlans),
    ),
  );
}

/// How long a facility stays usable after its subscription expires
/// before being locked to read-only.
const int kGracePeriodDays = 3;

/// Default trial length for a brand-new facility, used only if a
/// Platform Admin hasn't configured a different value yet (see
/// platform_config/settings in Firestore). Facilities created before
/// this feature shipped have no trialExpiresAt at all and are
/// unaffected - this only applies going forward, to facilities created
/// from now on.
const int kDefaultTrialDays = 14;
