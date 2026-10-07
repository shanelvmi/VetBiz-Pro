/// A user's role, as stored on `users/{uid}.role` by the server
/// (functions/membership.js). [key] is the stored string and never changes.
///
/// "Owner" and "Co-admin" are not stored roles: an owner is the admin who
/// created the facility, and a co-admin is `role: admin` with
/// `previousRole: assistant`. Screens work those out from the record.
enum UserRole {
  admin('admin'),
  assistant('assistant');

  const UserRole(this.key);

  final String key;

  /// The role for a stored value. Unknown or missing gives [assistant], the
  /// role with the least access - an odd record must never crash the app or
  /// grant admin screens. (Access itself is enforced by the server and rules.)
  static UserRole fromKey(String? key) {
    final k = key?.toLowerCase();
    for (final r in values) {
      if (r.key == k) return r;
    }
    return assistant;
  }
}
