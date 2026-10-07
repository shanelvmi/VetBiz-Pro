/// Subscription status keys, as used in stored and counted data (for example
/// the platform overview's per-status counts). The existing
/// `SubscriptionStatus` enum in subscription_provider.dart keeps working;
/// these are its stored spellings.
class SubscriptionKeys {
  SubscriptionKeys._();

  static const String trial = 'trial';
  static const String active = 'active';
  static const String grace = 'grace';
  static const String locked = 'locked';
}
