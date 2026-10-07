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
}
