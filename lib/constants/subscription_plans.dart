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

// Fallback defaults - only ever shown if a Platform Admin hasn't set
// real prices yet via Overview > Pricing. Once they have, every
// consumer reads their configured values instead, via
// loadSubscriptionPlans()/loadPlanById() below.
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(id: 'daily', label: 'Daily', durationDays: 1, priceTsh: 1000),
  SubscriptionPlan(id: 'weekly', label: 'Weekly', durationDays: 7, priceTsh: 6000),
  SubscriptionPlan(id: 'monthly', label: 'Monthly', durationDays: 30, priceTsh: 20000),
  SubscriptionPlan(id: 'yearly', label: 'Yearly', durationDays: 365, priceTsh: 200000),
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
  }).handleError((_) {
    // Same reasoning as loadSubscriptionPlans()'s catch - a transient
    // read error (e.g. a brief connectivity blip) shouldn't surface
    // as a visible error in the UI. This just suppresses the error
    // event; the stream stays quiet until the next successful
    // snapshot comes through, rather than emitting a broken state.
  });
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
