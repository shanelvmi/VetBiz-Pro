import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/activity_logger.dart';
import '../utils/facility_limit_helper.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../data/user_role.dart';
import '../data/user_status.dart';
import '../data/activity_type.dart';

/// Changing someone's role - done ONLY by a Platform Admin (Platform Admin >
/// Users > the person > Change role). Nobody else can: not the person
/// themselves, and not a facility's Admin.
///
/// Promoting an Assistant makes them a CO-ADMIN: an Admin of the facility
/// they're in, but not its owner. They keep appearing in the facility's team
/// list (Manage Assistants), labelled "Co-admin".
///
/// A role isn't just a label here, so this refuses changes that would leave
/// the data in a state the rest of the app can't cope with:
///
///  - A facility has an OWNER - its creator. Only the owner can delete it,
///    and Manage Account won't let an owner delete their account while they
///    still own facilities, precisely so none is left with nobody who can
///    manage or delete it. So an owner can't be demoted.
///  - An Assistant belongs to exactly one facility (the rest of the app is
///    built on that), so someone in several can't be demoted.
///  - A facility must always keep another Admin.
///  - A Platform Admin account's role is not changed here.
///
/// Everyone affected is told: the person (a personal notification), and the
/// facility's Admins (an admins-only notification), and the change is written
/// to the facility's Activity Log.

/// What's known about an account before changing its role.
class RoleChangeFacts {
  final String role;
  final String? previousRole;
  final String status;
  final bool isPlatformAdminAccount;
  final List<String> facilityIds;
  final Map<String, String> facilityNames;
  final List<String> ownedFacilityNames;

  /// facilityId -> how many OTHER operational Admins it has (Platform Admin
  /// accounts and deactivated ones don't count). Only filled in for an Admin.
  final Map<String, int> otherAdminsByFacility;
  final int maxFacilitiesPerAdmin;

  const RoleChangeFacts({
    required this.role,
    required this.previousRole,
    required this.status,
    required this.isPlatformAdminAccount,
    required this.facilityIds,
    required this.facilityNames,
    required this.ownedFacilityNames,
    required this.otherAdminsByFacility,
    required this.maxFacilitiesPerAdmin,
  });
}

/// The verdict: whether the change is allowed, and in plain words why not or
/// what it will do.
class RoleChangePlan {
  final String currentRole;
  final String newRole;

  /// What each is CALLED: "Co-admin", not "Admin", for a promoted Assistant.
  final String currentLabel;
  final String newLabel;
  final List<String> blockers;
  final List<String> effects;
  final List<String> warnings;

  const RoleChangePlan({
    required this.currentRole,
    required this.newRole,
    required this.currentLabel,
    required this.newLabel,
    required this.blockers,
    required this.effects,
    required this.warnings,
  });

  bool get allowed => blockers.isEmpty;
}

/// What happened when a change was applied.
class RoleChangeOutcome {
  final RoleChangePlan plan;

  /// False if any notification couldn't be sent. The role change itself
  /// still went through - a notification failing never undoes it.
  final bool notificationsSent;
  const RoleChangeOutcome({required this.plan, required this.notificationsSent});
}

class RoleChangeBlockedException implements Exception {
  final List<String> reasons;
  RoleChangeBlockedException(this.reasons);

  @override
  String toString() => reasons.join(' ');
}

class RoleChangeService {
  RoleChangeService._();

  static String newRoleFor(String role) => role == UserRole.admin.key ? UserRole.assistant.key : UserRole.admin.key;

  static String roleLabel(String role) {
    if (role == UserRole.admin.key) return 'Admin';
    if (role == UserRole.assistant.key) return 'Assistant';
    return role.isEmpty ? 'Unknown' : role;
  }

  /// What a person is CALLED. An Admin who started as an Assistant - promoted
  /// by a Platform Admin - is a Co-admin; an Admin who created their facility
  /// is simply an Admin. [previousRole] is what the change itself records, so
  /// no separate flag is needed.
  static String displayRole(String role, {String? previousRole}) {
    if (role == UserRole.admin.key && previousRole == UserRole.assistant.key) return 'Co-admin';
    return roleLabel(role);
  }

  /// True for the people displayRole calls Co-admin.
  static bool isCoAdmin(Map<String, dynamic> userData) =>
      userData[Fields.role] == UserRole.admin.key && userData['previousRole'] == UserRole.assistant.key;

  // "Ukuli Agrovet" rather than "Ukuli" - unless the name already says it.
  static String _facilityLabel(Map<dynamic, dynamic> f) {
    final name = ((f['name'] as String?) ?? 'Facility').trim();
    final type = ((f['type'] as String?) ?? '').trim();
    if (type.isEmpty || name.toLowerCase().contains(type.toLowerCase())) return name;
    return '$name $type';
  }

  /// PURE: decides from the facts alone, with no database access.
  static RoleChangePlan evaluate({required String userName, required RoleChangeFacts facts}) {
    final current = facts.role;
    final next = newRoleFor(current);
    final currentLabel = displayRole(current, previousRole: facts.previousRole);
    // Whoever is promoted from Assistant is, from then on, a Co-admin.
    final newLabel = next == UserRole.admin.key ? 'Co-admin' : 'Assistant';
    final blockers = <String>[];
    final effects = <String>[];
    final warnings = <String>[];

    if (current != UserRole.admin.key && current != UserRole.assistant.key) {
      blockers.add('This account\'s role ("$current") isn\'t one that can be changed here.');
    }
    if (facts.isPlatformAdminAccount) {
      blockers.add('This is a Platform Admin account. Its role can\'t be changed here.');
    }

    if (current == UserRole.assistant.key) {
      if (facts.status != UserStatus.active.key) {
        blockers.add('This account is ${facts.status}. Approve or reactivate it before promoting them.');
      }
      effects.add('$userName becomes a Co-admin: they can manage assistants, create invite codes, delete records, '
          'and create facilities (up to ${facts.maxFacilitiesPerAdmin}).');
      if (facts.facilityIds.isEmpty) {
        warnings.add('They aren\'t in a facility yet. As a Co-admin they can create their own.');
      } else {
        final names = facts.facilityIds.map((id) => facts.facilityNames[id] ?? 'their facility').join(', ');
        effects.add('They stay in the team list for $names, now labelled Co-admin. '
            'Only a facility\'s creator can delete the facility itself.');
        effects.add('They\'re told, and so are the facility\'s Admins.');
      }
    } else if (current == UserRole.admin.key) {
      if (facts.ownedFacilityNames.isNotEmpty) {
        blockers.add('They own ${facts.ownedFacilityNames.join(', ')}. A facility\'s owner has to stay an Admin - '
            'delete the facility first (ownership can\'t be transferred yet).');
      }
      if (facts.facilityIds.length > 1) {
        blockers.add('They belong to ${facts.facilityIds.length} facilities, and an Assistant can belong to only one. '
            'Remove them from the others first.');
      } else if (facts.facilityIds.length == 1) {
        final id = facts.facilityIds.first;
        if ((facts.otherAdminsByFacility[id] ?? 0) == 0) {
          blockers.add('${facts.facilityNames[id] ?? 'Their facility'} would be left with no other Admin. '
              'Promote someone else first.');
        }
        effects.add('They\'re told, and so are the facility\'s Admins.');
      }
      effects.add('$userName becomes an Assistant: they lose Admin access - managing assistants, creating invite '
          'codes, deleting records, and creating facilities.');
      effects.add('Their facility membership, and everything they recorded, stays as it is.');
      if (facts.facilityIds.isEmpty) {
        warnings.add('They aren\'t in any facility. Use Move to Facility afterwards so they can work.');
      }
    }

    effects.add('It takes effect straight away. If their screen looks out of date, ask them to sign in again.');

    return RoleChangePlan(
      currentRole: current,
      newRole: next,
      currentLabel: currentLabel,
      newLabel: newLabel,
      blockers: blockers,
      effects: effects,
      warnings: warnings,
    );
  }

  /// Looks up what [evaluate] needs. Reads only - and only things a Platform
  /// Admin is allowed to read.
  static Future<RoleChangeFacts> gatherFacts(String userId, Map<String, dynamic> userData) async {
    final db = FirebaseFirestore.instance;
    final role = (userData[Fields.role] ?? '').toString();
    final status = (userData[Fields.status] ?? UserStatus.active.key).toString();

    // Both fields are read: they're meant to stay in step, but an older
    // account might only have one of them.
    final ids = <String>{
      for (final id in (userData['facilityIds'] as List? ?? const [])) id.toString(),
    };
    final names = <String, String>{};
    for (final f in (userData['facilities'] as List? ?? const [])) {
      if (f is Map && f[Fields.facilityId] != null && f[Fields.facilityId].toString().isNotEmpty) {
        ids.add(f[Fields.facilityId].toString());
        names[f[Fields.facilityId].toString()] = _facilityLabel(f);
      }
    }
    final facilityIds = ids.where((id) => id.isNotEmpty).toList();

    // A facility the user's own list doesn't name still gets a proper name in
    // the dialog and the notifications.
    for (final fid in facilityIds.where((id) => !names.containsKey(id))) {
      final snap = await db.collection(Collections.facilities).doc(fid).get();
      if (snap.exists) names[fid] = _facilityLabel(snap.data() ?? const {});
    }

    final platformAdminDocs = await db.collection(Collections.platformAdmins).get();
    final platformAdminIds = platformAdminDocs.docs.map((d) => d.id).toSet();

    final owned = await db.collection(Collections.facilities).where('createdBy', isEqualTo: userId).get();
    final ownedNames = owned.docs.map((d) => _facilityLabel(d.data())).toList();

    // Whether a facility keeps another Admin only matters when demoting one.
    final others = <String, int>{};
    if (role == UserRole.admin.key) {
      for (final fid in facilityIds) {
        final admins =
            await db.collection(Collections.users).where(Fields.role, isEqualTo: UserRole.admin.key).where('facilityIds', arrayContains: fid).get();
        others[fid] = admins.docs
            .where((d) =>
                d.id != userId &&
                !platformAdminIds.contains(d.id) &&
                (d.data()[Fields.status] ?? UserStatus.active.key).toString() != UserStatus.deactivated.key)
            .length;
      }
    }

    return RoleChangeFacts(
      role: role,
      previousRole: userData['previousRole']?.toString(),
      status: status,
      isPlatformAdminAccount: platformAdminIds.contains(userId),
      facilityIds: facilityIds,
      facilityNames: names,
      ownedFacilityNames: ownedNames,
      otherAdminsByFacility: others,
      maxFacilitiesPerAdmin: await loadMaxFacilitiesPerAdmin(),
    );
  }

  // One notification document. Written by the Platform Admin, which the
  // rules already allow (promotions are sent the same way).
  static Future<void> _notify({
    required String facilityId,
    required String title,
    required String message,
    required String audience,
    String? targetUserId,
    String? excludeUserId,
  }) {
    return FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).collection(Collections.notifications).add({
      'type': 'roleChanged',
      'title': title,
      'message': message,
      Fields.createdAt: FieldValue.serverTimestamp(),
      'audience': audience,
      if (targetUserId != null) 'targetUserId': targetUserId,
      if (excludeUserId != null) 'excludeUserId': excludeUserId,
    });
  }

  /// Changes the role. Re-checks everything first, with fresh data - the
  /// dialog may have been open for a while, and things change.
  ///
  /// Throws [RoleChangeBlockedException] if the change is no longer allowed.
  static Future<RoleChangeOutcome> apply({
    required String userId,
    required Map<String, dynamic> userData,
    String? reason,
  }) async {
    final name = (userData['fullName'] ?? 'This user').toString();
    final facts = await gatherFacts(userId, userData);
    final plan = evaluate(userName: name, facts: facts);
    if (!plan.allowed) throw RoleChangeBlockedException(plan.blockers);

    final admin = FirebaseAuth.instance.currentUser;
    final by = admin?.email ?? admin?.uid ?? 'Unknown';
    final cleanReason = (reason ?? '').trim();

    // The same audit fields a status change leaves (statusChangedBy, ...).
    // previousRole is also what makes someone a Co-admin (an Admin whose
    // previous role was Assistant), so it must always be written.
    await FirebaseFirestore.instance.collection(Collections.users).doc(userId).update({
      Fields.role: plan.newRole,
      'previousRole': plan.currentRole,
      'previousRoleLabel': plan.currentLabel,
      'roleChangedBy': by,
      'roleChangedByRole': 'Platform Admin',
      'roleChangedAt': FieldValue.serverTimestamp(),
      if (cleanReason.isNotEmpty) 'roleChangeReason': cleanReason,
    });

    // From here on the role HAS changed - so nothing below may throw out of
    // this method, or the caller would report a failure for a change that
    // happened. Everything is best-effort and just recorded in the outcome.
    final reasonNote = cleanReason.isEmpty ? '' : ' Reason: $cleanReason.';
    final promoted = plan.newRole == UserRole.admin.key;
    var allSent = true;

    for (final fid in facts.facilityIds) {
      final facilityName = facts.facilityNames[fid] ?? 'the facility';

      // 1. The Activity Log - for the facility's Admins.
      await ActivityLogger.logActivity(
        facilityId: fid,
        userId: admin?.uid ?? '',
        userName: 'Platform Admin',
        actionType: ActivityType.account.key,
        targetUserId: userId,
        description: 'Platform Admin changed $name\'s role from ${plan.currentLabel} to ${plan.newLabel}'
            '${cleanReason.isEmpty ? '' : ' ($cleanReason)'}',
      );

      // 2. The person themselves.
      try {
        await _notify(
          facilityId: fid,
          audience: 'user',
          targetUserId: userId,
          title: promoted ? 'You\'re now a co-admin' : 'Your role has changed',
          message: promoted
              ? 'The platform administrator made you a co-admin of $facilityName. '
                  'You can now manage its assistants and invite codes.$reasonNote'
              : 'The platform administrator changed your role to Assistant at $facilityName. '
                  'You no longer have admin access.$reasonNote',
        );
      } catch (_) {
        allSent = false;
      }

      // 3. The facility's Admins - but not the person it's about, who has
      // just been told directly (and, once promoted, counts as an Admin).
      try {
        await _notify(
          facilityId: fid,
          audience: 'admins',
          excludeUserId: userId,
          title: promoted ? '$name is now a co-admin' : '$name is now an assistant',
          message: 'The platform administrator changed $name\'s role from ${plan.currentLabel} '
              'to ${plan.newLabel} at $facilityName.$reasonNote',
        );
      } catch (_) {
        allSent = false;
      }
    }

    return RoleChangeOutcome(plan: plan, notificationsSent: allSent);
  }
}
