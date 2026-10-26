import 'package:cloud_functions/cloud_functions.dart';
import '../config/app_rules.dart';
import '../ui/feedback/friendly_error.dart';
import '../l10n/l10n.dart';

/// The region the membership functions run in - the same one as the database
/// (africa-south1, Johannesburg). They make several database round trips each,
/// so run from the default region (us-central1) every one crossed continents
/// and registering took many seconds. Everything that calls them uses this, so
/// the app and the server can't drift apart (see MEMBERSHIP_REGION in
/// functions/index.js).
const String kMembershipFunctionsRegion = 'africa-south1';

/// What a person needs to know about the facility an invite code is for.
/// Deliberately NOT its id: the id is what membership is built on, so it never
/// reaches someone who hasn't joined yet.
class InviteCheck {
  final String facilityName;
  final String facilityType;

  /// An Other facility's own words for its type (RW2b2), when it has them.
  final String? facilityTypeDetail;
  const InviteCheck({required this.facilityName, required this.facilityType, this.facilityTypeDetail});

  /// The server's answer (checkInviteCode, joinWithInvite,
  /// joinFacilityWithInvite).
  factory InviteCheck.fromResult(Map<String, dynamic> data) => InviteCheck(
        facilityName: (data['facilityName'] ?? '').toString(),
        facilityType: (data['facilityType'] ?? '').toString(),
      );
}

class CreatedInvite {
  final String code;
  final DateTime expiresAt;
  const CreatedInvite({required this.code, required this.expiresAt});
}

/// Everything that decides WHO belongs to WHICH facility.
///
/// The app no longer writes any of it: creating an account's profile, adding a
/// facility, joining with an invite, moving or removing an assistant. Each is a
/// request to the server (functions/membership.js), which checks who is asking
/// and what they're entitled to, and makes the change itself. That is what
/// stops a person writing themselves into a facility that isn't theirs,
/// marking themselves approved, or choosing their own trial length - the app
/// can't, because the security rules no longer allow it to write those fields.
class MembershipService {
  final FirebaseFunctions _functions;

  /// [functions] lets registration call the server as the brand-new account
  /// (which signs in on a separate, temporary Firebase app) rather than as
  /// whoever the main app is signed in as.
  MembershipService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: kMembershipFunctionsRegion);

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable(name).call<dynamic>(data);
    final raw = result.data;
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// One facility as registerOwner and addFacility receive it: the name and
  /// the stored type, and typeDetail only for Other (RW2b2).
  static Map<String, dynamic> facilityPayload(Map<String, dynamic> facility) => {
        'name': facility['name'],
        'type': facility['type'],
      };

  List<Map<String, dynamic>> _facilityList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Checks an invite code. Works before the person has an account. Null if the
  /// code is wrong, used, or expired.
  Future<InviteCheck?> checkInviteCode(String code) async {
    final data = await _call('checkInviteCode', {'code': code});
    if (data['valid'] != true) return null;
    return InviteCheck(
      facilityName: (data['facilityName'] ?? '').toString(),
      facilityType: (data['facilityType'] ?? '').toString(),
    );
  }

  /// Creates an owner's profile and their facilities in one go. Returns the
  /// facilities with the ids the server gave them.
  Future<List<Map<String, dynamic>>> registerOwner({
    required String fullName,
    required String phone,
    required List<Map<String, dynamic>> facilities,
    String avatarUrl = '',
  }) async {
    final data = await _call('registerOwner', {
      'fullName': fullName,
      'phone': phone,
      'facilities': facilities.map((f) => {'name': f['name'], 'type': f['type']}).toList(),
      'avatarUrl': avatarUrl,
    });
    return _facilityList(data['facilities']);
  }

  /// Creates an assistant's profile in the facility the invite was made for,
  /// and uses the invite up.
  Future<InviteCheck> joinWithInvite({
    required String code,
    required String fullName,
    required String phone,
    String avatarUrl = '',
  }) async {
    final data = await _call('joinWithInvite', {
      'code': code,
      'fullName': fullName,
      'phone': phone,
      'avatarUrl': avatarUrl,
    });
    return InviteCheck(
      facilityName: (data['facilityName'] ?? '').toString(),
      facilityType: (data['facilityType'] ?? '').toString(),
    );
  }

  /// For someone already registered who is in no facility any more (they were
  /// removed from theirs): asks to join another with a fresh invite code. They
  /// keep their account, name, phone and photo, and come back "pending" - the
  /// new facility's admin decides.
  Future<InviteCheck> joinFacilityWithInvite({required String code}) async {
    final data = await _call('joinFacilityWithInvite', {'code': code});
    return InviteCheck(
      facilityName: (data['facilityName'] ?? '').toString(),
      facilityType: (data['facilityType'] ?? '').toString(),
    );
  }

  /// Adds a facility for the signed-in admin. The server enforces the facility
  /// limit and sets the trial. Returns {facilityId, name, type}: the code stays
  /// on the facility document (E4b, b3).
  Future<Map<String, dynamic>> addFacility({required String name, required String type}) {
    return _call('addFacility', {'name': name, 'type': type});
  }

  Future<CreatedInvite> createInviteCode(String facilityId) async {
    final data = await _call('createInviteCode', {'facilityId': facilityId});
    return CreatedInvite(
      code: (data['code'] ?? '').toString(),
      expiresAt: DateTime.tryParse((data['expiresAt'] ?? '').toString())?.toLocal() ??
          DateTime.now().add(AppRules.inviteValidity),
    );
  }

  /// Approve, reject, deactivate or reactivate an assistant. The server stamps
  /// each change with its own clock and keeps a short history (that's where
  /// "approved on ..." comes from), refuses one that no longer makes sense (a
  /// stale screen), and for "reject" takes the person out of the facility so
  /// they land on the invite-code screen when they next sign in.
  ///
  /// [action] is a `MembershipHistoryAction.request`: 'approve', 'reject', 'deactivate' or 'reactivate'.
  ///
  /// Returns the server's `signIn` answer (see [signInFailed]).
  Future<String> setAssistantStatus({required String assistantUid, required String action}) async {
    return _signIn(await _call('setAssistantStatus', {'assistantUid': assistantUid, 'action': action}));
  }

  Future<void> reassignAssistant({required String assistantUid, required String newFacilityId}) async {
    await _call('reassignAssistant', {'assistantUid': assistantUid, 'newFacilityId': newFacilityId});
  }

  /// Returns the server's `signIn` answer (see [signInFailed]).
  Future<String> removeAssistantFromFacility({required String assistantUid, required String facilityId}) async {
    return _signIn(await _call('removeAssistantFromFacility', {'assistantUid': assistantUid, 'facilityId': facilityId}));
  }

  /// Operator console only: a Platform Admin sets any user's status to
  /// 'active' or 'deactivated' (a `UserStatus` key). The server checks the
  /// caller is a Platform Admin and switches the person's sign-in to match.
  /// Returns the server's `signIn` answer (see [signInFailed]).
  Future<String> platformSetUserStatus({required String userId, required String status}) async {
    return _signIn(await _call('platformSetUserStatus', {'userId': userId, 'status': status}));
  }

  /// What the server says it did to the person's sign-in after a status
  /// change or a removal (C2): 'disabled', 'enabled', 'revoked', 'unchanged',
  /// or this one, when the change itself was saved but Firebase Auth could not
  /// be updated. The admin is told, since the person may still be signed in.
  static const String signInFailed = 'failed';

  static String _signIn(Map<String, dynamic> data) => (data['signIn'] ?? '').toString();

  /// Brings every member's copy of a facility's name and type into line after
  /// it's been edited.
  Future<void> syncFacilityDetails(String facilityId) async {
    await _call('syncFacilityDetails', {'facilityId': facilityId});
  }

  /// A message fit to show a person, for anything these calls can throw.
  static String errorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return L10n.current.membership_unreachable;
        case 'unauthenticated':
          return L10n.current.membership_signInAgain;
        // P1: only the invite-code callables refuse this way (too many wrong
        // codes); the server's English sentence is replaced by the ARB one.
        case 'resource-exhausted':
          return L10n.current.membership_tooManyInviteAttempts(AppRules.inviteAttemptWindowMinutes);
      }
      final message = error.message;
      if (message != null && message.isNotEmpty && message.toUpperCase() != 'INTERNAL') return message;
      return L10n.current.membership_generic;
    }
    // Anything else (Firestore, a timeout, a plain exception) used to reach
    // the screen as raw text; FriendlyError turns it into a sentence.
    return FriendlyError.messageFor(error);
  }
}
