// PH8b: Team Members on a fake Firestore. A team of every kind (the owner,
// a Co-admin, assistants pending, active and deactivated, one in a second
// facility, and an Admin who is neither, who is never listed), a fake
// sign-in for whoever is looking, and a fake server that records each
// request and answers the sign-in outcome a test chooses (C2).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

import 'fake_firestore.dart';
import 'screen_size_matrix.dart';

const ph8bSecondFacilityId = 'facility2';
const ph8bCoAdminId = 'c1';

class Ph8bUser extends Fake implements User {
  @override
  final String uid;
  Ph8bUser(this.uid);
  @override
  String? get email => '$uid@kilimo.co.tz';
}

class Ph8bAuth extends Fake implements FirebaseAuth {
  final String uid;
  Ph8bAuth([this.uid = testUserId]);
  @override
  User? get currentUser => Ph8bUser(uid);
}

/// What the screen asked the server to do, in order.
class FakeMembership extends Fake implements MembershipService {
  final calls = <String>[];

  /// What setAssistantStatus and removeAssistantFromFacility answer: ''
  /// (signed out) or MembershipService.signInFailed (C2).
  String signIn = '';

  @override
  Future<String> setAssistantStatus({required String assistantUid, required String action}) async {
    calls.add('status $assistantUid $action');
    return signIn;
  }

  @override
  Future<void> reassignAssistant({required String assistantUid, required String newFacilityId}) async {
    calls.add('reassign $assistantUid $newFacilityId');
  }

  @override
  Future<String> removeAssistantFromFacility({required String assistantUid, required String facilityId}) async {
    calls.add('remove $assistantUid $facilityId');
    return signIn;
  }
}

Timestamp _at(int day) => Timestamp.fromDate(DateTime(2026, 10, day, 9, 30));

/// The team, with [longNames] the matrix's very long names.
Future<void> ph8bSeedTeam(FirebaseFirestore fs, {bool longNames = false, bool twoFacilities = true}) async {
  final facilities = fs.collection(Collections.facilities);
  await facilities.doc(testFacilityId).set(
      {'name': longNames ? matrixLongFacilityName : 'Kilimo Agrovet', 'type': 'Agrovet', 'createdBy': testUserId},
      SetOptions(merge: true));
  if (twoFacilities) {
    await facilities.doc(ph8bSecondFacilityId).set({'name': 'Mifugo Clinic', 'type': 'Vet Clinic', 'createdBy': testUserId});
  }
  final users = fs.collection(Collections.users);
  final mine = [testFacilityId, if (twoFacilities) ph8bSecondFacilityId];
  Future<void> user(String id, String name, Map<String, dynamic> extra) => users.doc(id).set({
        'fullName': longNames ? '$name $matrixLongClientName' : name,
        'phone': '+255 712 000 ${100 + id.codeUnits.fold<int>(0, (a, c) => a + c) % 900}',
        'email': '$id@kilimo.co.tz',
        'createdAt': _at(1),
        'facilityIds': [testFacilityId],
        ...extra,
      });
  await user(testUserId, 'Asha Owner', {'role': 'admin', 'status': 'active', 'facilityIds': mine});
  await user(ph8bCoAdminId, 'Zawadi Co-admin', {'role': 'admin', 'previousRole': 'assistant', 'status': 'active'});
  await user('a1', 'Juma Pending', {'role': 'assistant', 'status': 'pending'});
  await user('a2', 'Neema Active', {
    'role': 'assistant',
    'status': 'active',
    'approvedAt': _at(2),
    'approvedBy': 'Asha Owner',
    'statusHistory': [
      {'action': 'approved', 'at': _at(2), 'by': 'Asha Owner'},
    ],
  });
  await user('a3', 'Baraka Paused', {
    'role': 'assistant',
    'status': 'deactivated',
    'statusChangedAt': _at(3),
    'statusChangedBy': 'owner@kilimo.co.tz',
    'statusChangedByRole': 'Facility Admin',
  });
  if (twoFacilities) {
    await user('a4', 'Rehema Clinic', {'role': 'assistant', 'status': 'active', 'facilityIds': [ph8bSecondFacilityId]});
  }
  // An Admin who is neither the owner nor a Co-admin: never listed.
  await user('x1', 'Support Admin', {'role': 'admin', 'status': 'active'});
}

/// The screen as the app builds it, on [fs], as [uid].
Widget ph8bTeamScreen(FirebaseFirestore fs, {String uid = testUserId, FakeMembership? membership}) =>
    ManageAssistantsScreen(
      firestore: fs,
      auth: Ph8bAuth(uid),
      membership: membership ?? FakeMembership(),
      currentUserInfo: () async => {'userId': uid, 'userName': 'Asha Owner'},
    );
