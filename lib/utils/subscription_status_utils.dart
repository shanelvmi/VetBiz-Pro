/// Shared subscription status logic - used by SubscriptionProvider (one
/// facility's own live status) and the Platform Admin Shops Directory
/// (every facility at a glance), so the two can never disagree about
/// what "locked" or "grace" means for a given expiry date.
enum SubscriptionStatusKind { trial, active, grace, locked }

// Must match kGracePeriodDays in subscription_plans.dart and the
// isSubscriptionLocked() function in Firestore rules.
const int kGracePeriodDaysUtil = 3;

SubscriptionStatusKind computeSubscriptionStatus(DateTime? subscriptionExpiresAt, [DateTime? trialExpiresAt]) {
  // A real, paid subscription cycle takes priority whenever it exists.
  if (subscriptionExpiresAt != null) {
    final now = DateTime.now();
    if (now.isBefore(subscriptionExpiresAt)) return SubscriptionStatusKind.active;
    final graceEnd = subscriptionExpiresAt.add(const Duration(days: kGracePeriodDaysUtil));
    if (now.isBefore(graceEnd)) return SubscriptionStatusKind.grace;
    return SubscriptionStatusKind.locked;
  }

  // No paid subscription yet - a real, timed trial (only present on
  // facilities created after this feature shipped) counts down the
  // same way, reusing the same grace/locked flow once it runs out.
  if (trialExpiresAt != null) {
    final now = DateTime.now();
    if (now.isBefore(trialExpiresAt)) return SubscriptionStatusKind.trial;
    final graceEnd = trialExpiresAt.add(const Duration(days: kGracePeriodDaysUtil));
    if (now.isBefore(graceEnd)) return SubscriptionStatusKind.grace;
    return SubscriptionStatusKind.locked;
  }

  // Neither set - a facility created before this feature existed.
  // Same permanently-open trial behavior as before, never retroactively
  // changed.
  return SubscriptionStatusKind.trial;
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
