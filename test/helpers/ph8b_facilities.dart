// PH8b: Facilities on a fake Firestore. The signed-in admin (testUserId)
// has three facilities on their profile, as the server writes them: an
// Agrovet (the active one), a Vet Clinic with an assistant, and an Other one
// with its own words for the type (RW2b2), inactive.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vetbiz_pro/data/collections.dart';

import 'fake_firestore.dart';
import 'screen_size_matrix.dart';

const ph8bClinicId = 'facility2';
const ph8bOtherId = 'facility3';

Timestamp _at(int day) => Timestamp.fromDate(DateTime(2026, 10, day, 9, 30));

/// The facilities, with [longNames] the matrix's very long facility name.
Future<void> ph8bSeedFacilities(FirebaseFirestore fs, {bool longNames = false}) async {
  final first = longNames ? matrixLongFacilityName : 'Kilimo Agrovet';
  final entries = [
    {'facilityId': testFacilityId, 'name': first, 'type': 'Agrovet', 'typeDetail': null},
    {'facilityId': ph8bClinicId, 'name': 'Mifugo Clinic', 'type': 'Vet Clinic', 'typeDetail': null},
    {'facilityId': ph8bOtherId, 'name': 'Shamba Hub', 'type': 'Other', 'typeDetail': 'Kituo cha mafunzo'},
  ];
  await fs.collection(Collections.users).doc(testUserId).set({
    'role': 'admin',
    'fullName': 'Asha Owner',
    'email': testUserEmail,
    'facilityIds': [for (final e in entries) e['facilityId']],
    'facilities': entries,
  });
  final facilities = fs.collection(Collections.facilities);
  for (final (i, e) in entries.indexed) {
    await facilities.doc(e['facilityId'] as String).set({
      'name': e['name'],
      'type': e['type'],
      if (e['typeDetail'] != null) 'typeDetail': e['typeDetail'],
      'createdBy': testUserId,
      'code': 'VBP-00${i + 1}',
      'email': 'info${i + 1}@kilimo.co.tz',
      'phone': '+255 754 000 10$i',
      'address': i == 0 ? 'Mtaa wa Uhuru, Arusha' : 'Dodoma',
      'licenseNo': 'LIC-$i',
      'status': i == 2 ? 'inactive' : 'active',
      'createdAt': _at(1 + i),
      'updatedAt': _at(4 + i),
    });
  }
  await fs.collection(Collections.users).doc('a9').set({
    'role': 'assistant',
    'status': 'active',
    'fullName': 'Rehema Clinic',
    'facilityIds': [ph8bClinicId],
  });
}
