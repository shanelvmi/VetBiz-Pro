import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/collections.dart';

/// Who made a subscription payment claim, and who reviewed it (SUBS-1), for
/// accountability.
///
/// A claim (payment_submissions) stores its submitter three ways:
/// submittedBy (the email, or the uid for an account without one),
/// submittedById (the uid firestore.rules checks) and, since SUBS-1,
/// submittedByName (the profile's full name, or the email). A Platform
/// Admin's review stores reviewedBy (the email) and reviewedByName. Older
/// documents have no name fields: they show the email.

/// The `source` of a record the platform team made itself. Shown as the
/// team, whoever's email is on it. No writer records one yet (a manual
/// subscription update from the operator console writes only the facility).
const String manualSubmissionSource = 'manual';

String? _text(Object? value) {
  final s = value is String ? value.trim() : null;
  return (s == null || s.isEmpty) ? null : s;
}

/// The name to store for a person: the full name, else the email, else the
/// uid.
String personNameToStore({String? fullName, String? email, String? uid}) =>
    _text(fullName) ?? _text(email) ?? _text(uid) ?? 'Unknown';

/// What a review stores about the reviewer.
Map<String, Object?> reviewerFields({String? email, String? uid, String? fullName}) => {
      'reviewedBy': email ?? uid ?? 'Unknown',
      'reviewedByName': personNameToStore(fullName: fullName, email: email, uid: uid),
    };

/// Who submitted [claim], as shown: [team] for the platform team's own
/// record, else the name, else the email; null when nothing is stored.
String? submitterShown(Map<String, dynamic> claim, {required String team}) {
  if (claim['source'] == manualSubmissionSource) return team;
  return _text(claim['submittedByName']) ?? _text(claim['submittedBy']);
}

/// Who reviewed [claim], as shown: the name, else the email; null if nobody.
String? reviewerShown(Map<String, dynamic> claim) => _text(claim['reviewedByName']) ?? _text(claim['reviewedBy']);

/// The full name on [uid]'s profile (users/{uid}.fullName), or null when
/// there is none or it can't be read: the caller then stores the email.
Future<String?> profileFullName(String? uid, {FirebaseFirestore? firestore}) async {
  if (uid == null) return null;
  try {
    final doc = await (firestore ?? FirebaseFirestore.instance).collection(Collections.users).doc(uid).get();
    return _text(doc.data()?['fullName']);
  } catch (_) {
    return null;
  }
}
