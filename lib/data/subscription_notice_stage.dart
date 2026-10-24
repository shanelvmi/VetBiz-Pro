/// How far the subscription notice has escalated (NOTIF-2b), as stored in a
/// person's notification state (`seenStage`): the stage they last read it
/// at. [key] is the stored string and never changes; the order is the
/// escalation order.
///
/// A stage, not the notice's wording: "7 days left" and "6 days left" are the
/// same stage, and a change of language cannot look like an escalation.
enum SubscriptionNoticeStage {
  none('none'),
  expiring('expiring'),
  grace('grace'),
  locked('locked');

  const SubscriptionNoticeStage(this.key);

  final String key;

  /// The stage for a stored value; unknown or missing gives null.
  static SubscriptionNoticeStage? fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// The id of the subscription notice: the document checkSubscriptionExpiry
/// writes (functions/index.js), and the row the app builds in its place.
const String subscriptionNoticeId = 'subscription_expiring';
