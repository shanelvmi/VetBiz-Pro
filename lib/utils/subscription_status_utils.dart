/// Shared subscription status logic - used by SubscriptionProvider (one
/// facility's own live status) and the Platform Admin Shops Directory
/// (every facility at a glance), so the two can never disagree about
/// what "locked" or "grace" means for a given expiry date.
enum SubscriptionStatusKind { trial, active, grace, locked }

// Must match kGracePeriodDays in subscription_plans.dart and the
// isSubscriptionLocked() function in Firestore rules.
const int kGracePeriodDaysUtil = 3;

SubscriptionStatusKind computeSubscriptionStatus(DateTime? expiresAt) {
  if (expiresAt == null) return SubscriptionStatusKind.trial;

  final now = DateTime.now();
  if (now.isBefore(expiresAt)) return SubscriptionStatusKind.active;

  final graceEnd = expiresAt.add(const Duration(days: kGracePeriodDaysUtil));
  if (now.isBefore(graceEnd)) return SubscriptionStatusKind.grace;

  return SubscriptionStatusKind.locked;
}

String subscriptionStatusLabel(SubscriptionStatusKind status) {
  switch (status) {
    case SubscriptionStatusKind.trial:
      return 'Trial';
    case SubscriptionStatusKind.active:
      return 'Active';
    case SubscriptionStatusKind.grace:
      return 'Grace Period';
    case SubscriptionStatusKind.locked:
      return 'Locked';
  }
}
