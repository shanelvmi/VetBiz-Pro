import 'package:cloud_firestore/cloud_firestore.dart';

import 'membership_service.dart';

/// Short-lived, single-use codes for inviting a specific Assistant to
/// join a facility - deliberately separate from the facility's own
/// permanent code. That permanent code never expires and is used for
/// nothing else (display, support, internal reference), so reusing it
/// as the assistant join-mechanism meant anyone who'd ever seen it -
/// including a former employee - could keep using it indefinitely.
/// An invite code only ever matters for one specific hire, once: it
/// dies the moment it's used, or after 48 hours, whichever comes first.
///
/// Creating a code, checking one, and using one up are all done by the
/// server now (see MembershipService): a code is made by someone who
/// administers the facility, checked without ever revealing the facility's
/// id, and used up in the same step that creates the new assistant, so it
/// really can only be used once. What's left here is what an Admin does with
/// their own facility's codes: see the active one, and revoke it.
class InviteCodeService {
  static const codeLength = 6; // displayed as "XXX-XXX"
  static const validityDuration = Duration(hours: 48);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MembershipService _membership = MembershipService();

  /// "JK72P4" -> "JK7-2P4" - grouped for readability, since chunked
  /// codes are read aloud and re-typed far more reliably than one long,
  /// unbroken string (the same reasoning behind how product keys and
  /// 2FA backup codes are formatted).
  String formatForDisplay(String rawCode) {
    if (rawCode.length != codeLength) return rawCode;
    return '${rawCode.substring(0, 3)}-${rawCode.substring(3)}';
  }

  /// Generates a new invite code for a facility. Any earlier unused invite for
  /// the same facility is replaced - only one active invite exists per
  /// facility at a time, so there's never ambiguity about which code is the
  /// current, real one. The server does both, and checks you administer this
  /// facility. ([createdByUserId] is kept so existing callers compile; the
  /// server records who asked from their sign-in, not from what the app says.)
  Future<String> generateInviteCode({
    required String facilityId,
    String createdByUserId = '',
  }) async {
    final invite = await _membership.createInviteCode(facilityId);
    return invite.code;
  }

  /// The currently active (unused, unexpired) invite for a facility, if
  /// any - lets Manage Assistants show "you already have an active
  /// invite: JK7-2P4" instead of only ever offering to generate a new
  /// one with no visibility into whether one already exists.
  Future<Map<String, dynamic>?> getActiveInvite(String facilityId) async {
    final snap = await _firestore
        .collection('inviteCodes')
        .where('facilityId', isEqualTo: facilityId)
        .where('usedAt', isNull: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final data = snap.docs.first.data();
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return null;

    return {'code': snap.docs.first.id, 'expiresAt': expiresAt};
  }

  /// Explicitly revokes a facility's active invite code, if any exists.
  Future<void> revokeInviteCode(String facilityId) async {
    final existing = await _firestore
        .collection('inviteCodes')
        .where('facilityId', isEqualTo: facilityId)
        .where('usedAt', isNull: true)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }
  }
}
