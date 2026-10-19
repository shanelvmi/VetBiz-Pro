import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/collections.dart';

/// Each facility's permanent code, read from the facility document itself.
///
/// Profiles used to carry a copy in `users/{uid}.facilities[].code`, and
/// profiles are read by other admins. Since E4b (b3) the server stops
/// copying it, so screens that show the code read it here, from the one
/// place only the facility's members (and its creator, and Platform Admins)
/// may read. This is the facility's identifier, not an invite code: joining
/// goes through the short-lived codes in InviteCodeService.
class FacilityCodes {
  FacilityCodes({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// The field on `facilities/{id}`.
  static const String field = 'code';

  /// facilityId -> code, for the given ids. Empty ids, facilities that are
  /// gone, and facilities with no code are left out.
  Future<Map<String, String>> fetch(Iterable<String> facilityIds) async {
    final ids = facilityIds.where((id) => id.isNotEmpty).toSet();
    final snaps = await Future.wait(ids.map((id) => _db.collection(Collections.facilities).doc(id).get()));
    return {
      for (final snap in snaps)
        if (snap.data()?[field] case final String code when code.isNotEmpty) snap.id: code,
    };
  }
}
