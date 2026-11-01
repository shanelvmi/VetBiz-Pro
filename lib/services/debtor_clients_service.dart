import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/collections.dart';
import '../models/client.dart';

/// Every client of [facilityId] who owes money now (balance above 0), fetched
/// fresh: the Record Payment picker must offer every debtor, not just the
/// page a list has loaded. Shared by Debtors (its Record Payment button and
/// its export) and the phone's "+" sheet (PH3). An empty list when no
/// facility is open.
Future<List<Client>> fetchAllDebtorClients(FirebaseFirestore db, String? facilityId) async {
  if (facilityId == null) return [];
  final snap = await db
      .collection(Collections.facilities)
      .doc(facilityId)
      .collection(Collections.clients)
      .where('balance', isGreaterThan: 0)
      .get();
  return snap.docs.map((d) => Client.fromMap(d.id, d.data())).toList();
}
