/// A user's membership status, as stored on `users/{uid}.status` by the
/// server (functions/membership.js). [key] is the stored string and never
/// changes.
enum UserStatus {
  pending('pending'),
  active('active'),
  deactivated('deactivated'),
  rejected('rejected');

  const UserStatus(this.key);

  final String key;

  /// The status for a stored value. Unknown or missing gives [pending]: it
  /// grants nothing, and never crashes the app.
  static UserStatus fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return pending;
  }
}
