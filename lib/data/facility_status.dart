/// A facility's status, as stored on `facilities/{id}.status` by the facility
/// screen (edit dialog and Deactivate/Reactivate). [key] is the stored string
/// and never changes. Not the same thing as a user's [UserStatus] or a
/// payment submission's status.
///
/// Readers compare case-insensitively (some older facilities hold
/// lower-case values), and a facility with no status is [active].
enum FacilityStatus {
  active('Active'),
  inactive('Inactive'),

  /// Only read: the status chip colours it, but nothing in the app writes it.
  pending('pending');

  const FacilityStatus(this.key);

  final String key;

  /// The status for a stored value, ignoring case. Missing gives [active];
  /// an unknown value gives null (shown as is, in a neutral colour).
  static FacilityStatus? fromKey(String? key) {
    if (key == null) return active;
    for (final s in values) {
      if (s.key.toLowerCase() == key.toLowerCase()) return s;
    }
    return null;
  }
}
