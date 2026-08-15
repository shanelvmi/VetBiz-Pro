/// Subscription plan definitions. Prices are placeholders - replace with
/// your real pricing before relying on this. Kept in one place so the
/// Subscription screen and the admin review screen never disagree about
/// what a plan actually costs or how long it lasts.
class SubscriptionPlan {
  final String id; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final String label;
  final int durationDays;
  final double priceTsh; // ⚠️ placeholder - set your real price

  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.durationDays,
    required this.priceTsh,
  });
}

// ⚠️ Placeholder prices - update these with your real numbers.
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

/// How long a facility stays usable after its subscription expires
/// before being locked to read-only.
const int kGracePeriodDays = 3;
