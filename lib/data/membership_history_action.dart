/// One step in an assistant's membership: what the app asks the server for
/// ([request], the `action` sent to `setAssistantStatus`) and what the server
/// stores in the person's history ([key], `users/{uid}.statusHistory[].action`).
///
/// Both strings belong to functions/membership.js (`STATUS_ACTIONS`): the
/// object keys are the requests, `history:` the stored keys. Neither ever
/// changes, and functions/test/endpoints.test.js fails if the two sides drift.
enum MembershipHistoryAction {
  approved('approve', 'approved'),
  rejected('reject', 'rejected'),
  deactivated('deactivate', 'deactivated'),
  reactivated('reactivate', 'reactivated');

  const MembershipHistoryAction(this.request, this.key);

  final String request;
  final String key;

  /// The action for a stored history key; null for anything unknown (shown
  /// as is).
  static MembershipHistoryAction? fromKey(String? key) {
    for (final a in values) {
      if (a.key == key) return a;
    }
    return null;
  }
}
