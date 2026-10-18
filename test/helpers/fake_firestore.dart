// Test harness for provider code that writes to Firestore: an in-memory
// Firestore (fake_cloud_firestore), a signed-in user, and seed helpers for
// the documents a sale touches. No Firebase app, no network.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/sale.dart';
import 'package:vetbiz_pro/providers/sale_provider.dart';

const testFacilityId = 'facility1';
const testUserId = 'user1';
const testUserName = 'Asha Seller';

/// What ActivityLogger.getCurrentUserInfo returns for the signed-in user.
Future<Map<String, String>> testUserInfo() async =>
    {'userId': testUserId, 'userName': testUserName};

FakeFirebaseFirestore newFakeFirestore() => FakeFirebaseFirestore();

SaleProvider newSaleProvider(FirebaseFirestore firestore) =>
    SaleProvider(firestore: firestore, currentUserInfo: testUserInfo);

DocumentReference<Map<String, dynamic>> facilityDoc(FirebaseFirestore fs) =>
    fs.collection(Collections.facilities).doc(testFacilityId);

CollectionReference<Map<String, dynamic>> facilityCollection(FirebaseFirestore fs, String name) =>
    facilityDoc(fs).collection(name);

/// A product with batches ([batchQty]: batch id -> sellable quantity, all at
/// [buyPrice]); its aggregate sellableQty is their sum. With no batches it
/// is a legacy product whose aggregate is [legacyQty].
Future<void> seedProduct(
  FirebaseFirestore fs, {
  required String id,
  Map<String, int> batchQty = const {},
  int legacyQty = 0,
  double buyPrice = 1000,
}) async {
  final productRef = facilityCollection(fs, Collections.products).doc(id);
  final total = batchQty.isEmpty ? legacyQty : batchQty.values.fold(0, (a, b) => a + b);
  await productRef.set({'name': id, 'sellableQty': total, 'stockQty': 0, 'buyPrice': buyPrice});
  var day = 1;
  for (final entry in batchQty.entries) {
    await productRef.collection(Collections.batches).doc(entry.key).set({
      'sellableQty': entry.value,
      'stockQty': 0,
      'buyPrice': buyPrice,
      'expiry': Timestamp.fromDate(DateTime(2030, 1, day++)),
    });
  }
}

Future<void> seedClient(FirebaseFirestore fs,
    {required String id, String name = 'Juma', String phone = '0712000000', double balance = 0}) {
  return facilityCollection(fs, Collections.clients)
      .doc(id)
      .set({'name': name, 'phone': phone, 'balance': balance});
}

SaleItem saleItem(String productId, int quantity, {double unitPrice = 2000}) => SaleItem(
      productId: productId,
      name: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      costPrice: 1000,
      unit: 'pcs',
    );

/// A sale as AddSaleScreen builds it, with the id the form made.
Sale testSale({
  required String id,
  required List<SaleItem> items,
  double? paid,
  String? clientId,
  String? clientName,
}) {
  final total = items.fold(0.0, (t, i) => t + i.unitPrice * i.quantity);
  final totalPaid = paid ?? total;
  return Sale(
    id: id,
    clientId: clientId,
    clientName: clientName,
    timestamp: DateTime.now(),
    updatedAt: DateTime.now(),
    items: items,
    totalAmount: total,
    totalPaid: totalPaid,
    facilityId: testFacilityId,
    soldById: testUserId,
    soldByName: testUserName,
    saleOnCredit: totalPaid < total,
    paymentMethod: totalPaid > 0 ? 'Cash' : null,
  );
}

Future<int> sellableQty(FirebaseFirestore fs, String productId, [String? batchId]) async {
  final productRef = facilityCollection(fs, Collections.products).doc(productId);
  final snap = batchId == null
      ? await productRef.get()
      : await productRef.collection(Collections.batches).doc(batchId).get();
  return (snap.data()?['sellableQty'] as num).toInt();
}

Future<int> countDocs(FirebaseFirestore fs, String collection) async =>
    (await facilityCollection(fs, collection).get()).docs.length;

/// Lets the fake finish its writes. Its transactions apply each write
/// without awaiting it (and ignore SetOptions, and never roll back), so a
/// check right after a call could see a write half done.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Everything stored, parsed (so key order doesn't count) and without the
/// empty nodes the fake leaves where a missing document was only read.
Object? storedData(FakeFirebaseFirestore fs) => _pruneEmpty(jsonDecode(fs.dump()));

Object? _pruneEmpty(Object? node) {
  if (node is! Map) return node;
  final pruned = <String, Object?>{};
  node.forEach((key, value) {
    final child = _pruneEmpty(value);
    if (child is Map && child.isEmpty) return;
    pruned[key as String] = child;
  });
  return pruned;
}
