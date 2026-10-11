/// The most-typed Firestore field names. Only these; other field names stay
/// where they are (Phase 2 spec, section 7).
class Fields {
  Fields._();

  static const String facilityId = 'facilityId';
  static const String status = 'status';
  static const String role = 'role';
  static const String userId = 'userId';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  /// A boolean field NAME (promotions/{id}.active: the one live promotion),
  /// not a status value. A user's 'active' status is `UserStatus.active`.
  static const String active = 'active';
}
