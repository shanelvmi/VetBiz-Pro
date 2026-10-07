/// The review status of a subscription payment submission, as stored on
/// `payment_submissions/{id}.status`. [key] is the stored string and never
/// changes.
///
/// Not a user status (see UserStatus): the same words, a different record.
enum PaymentSubmissionStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const PaymentSubmissionStatus(this.key);

  final String key;

  /// The status for a stored value. Anything that isn't approved or rejected
  /// counts as pending - the same rule the subscription history already
  /// applies - and never crashes the app.
  static PaymentSubmissionStatus fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return pending;
  }
}
