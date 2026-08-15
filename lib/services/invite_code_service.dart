import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Short-lived, single-use codes for inviting a specific Assistant to
/// join a facility - deliberately separate from the facility's own
/// permanent code. That permanent code never expires and is used for
/// nothing else (display, support, internal reference), so reusing it
/// as the assistant join-mechanism meant anyone who'd ever seen it -
/// including a former employee - could keep using it indefinitely.
/// An invite code only ever matters for one specific hire, once: it
/// dies the moment it's used, or after 48 hours, whichever comes first.
class InviteCodeService {
  // Deliberately excludes visually ambiguous characters (0/O, 1/I/L) -
  // this code gets read aloud over the phone and typed on small mobile
  // keyboards, so nobody should ever have to guess whether a character
  // was a zero or a letter O.
  static const _unambiguousChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const codeLength = 6; // displayed as "XXX-XXX"
  static const validityDuration = Duration(hours: 48);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  String _generateRawCode() {
    return List.generate(
      codeLength,
      (_) => _unambiguousChars[_random.nextInt(_unambiguousChars.length)],
    ).join();
  }

  /// "JK72P4" -> "JK7-2P4" - grouped for readability, since chunked
  /// codes are read aloud and re-typed far more reliably than one long,
  /// unbroken string (the same reasoning behind how product keys and
  /// 2FA backup codes are formatted).
  String formatForDisplay(String rawCode) {
    if (rawCode.length != codeLength) return rawCode;
    return '${rawCode.substring(0, 3)}-${rawCode.substring(3)}';
  }

  /// Strips dashes/spaces and uppercases, so "jk7 2p4", "JK7-2P4", and
  /// "jk72p4" are all treated as the same code when someone types it in.
  String _normalizeInput(String input) {
    return input.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }

  /// Generates a new invite code for a facility, first invalidating any
  /// previous unused invite for that same facility - only one active
  /// invite exists per facility at a time, so there's never ambiguity
  /// about which code is the current, real one.
  Future<String> generateInviteCode({
    required String facilityId,
    required String createdByUserId,
  }) async {
    await revokeInviteCode(facilityId);

    String code;
    // Collision is extremely unlikely given the character set and
    // length, but this guards against it rather than assuming.
    do {
      code = _generateRawCode();
    } while ((await _firestore.collection('inviteCodes').doc(code).get()).exists);

    await _firestore.collection('inviteCodes').doc(code).set({
      'facilityId': facilityId,
      'createdByUserId': createdByUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validityDuration)),
      'usedAt': null,
      'usedByUserId': null,
    });

    return code;
  }

  /// Validates an entered invite code and returns the facilityId it
  /// belongs to if valid - null if it doesn't exist, has already been
  /// used, or has expired. Does NOT mark it as used; that only happens
  /// once registration has actually succeeded, via markInviteCodeUsed.
  Future<String?> validateInviteCode(String enteredCode) async {
    final normalized = _normalizeInput(enteredCode);
    if (normalized.length != codeLength) return null;

    final doc = await _firestore.collection('inviteCodes').doc(normalized).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    if (data['usedAt'] != null) return null;

    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return null;

    return data['facilityId'] as String?;
  }

  /// Marks an invite code as consumed - call only after the new
  /// assistant's account has genuinely been created successfully, so a
  /// failed registration attempt doesn't burn the invite for nothing.
  Future<void> markInviteCodeUsed(String enteredCode, String usedByUserId) async {
    final normalized = _normalizeInput(enteredCode);
    await _firestore.collection('inviteCodes').doc(normalized).update({
      'usedAt': FieldValue.serverTimestamp(),
      'usedByUserId': usedByUserId,
    });
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
