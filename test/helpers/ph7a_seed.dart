// PH7a: products and their batches as the app stores them, for Products,
// Stock Store, the batches screens and the product form on the real
// providers over a fake Firestore (phone_list_harness.dart's pumpPh5).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vetbiz_pro/data/collections.dart';

import 'fake_firestore.dart';
import 'screen_size_matrix.dart';

/// One seeded product. [shelf] is the sellable quantity, [store] the Stock
/// Store's; [expiryDays] days from today (negative: expired), none if null.
class Ph7Product {
  final String id;
  final String name;
  final int shelf;
  final int store;
  final double sell;
  final double buy;
  final String category;
  final String type;
  final int? expiryDays;
  final String? imageUrl;
  final bool watchlisted;
  final String? batchNo;
  final String? description;

  const Ph7Product(
    this.id,
    this.name, {
    this.shelf = 20,
    this.store = 0,
    this.sell = 15000,
    this.buy = 9000,
    this.category = 'Anthelmintics',
    this.type = 'Oral Liquid',
    this.expiryDays = 400,
    this.imageUrl,
    this.watchlisted = false,
    this.batchNo = 'BN-001',
    this.description,
  });
}

/// A fixed day well inside a year from now, so expiry texts keep their shape.
DateTime ph7Expiry(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

/// Every product kind the lists tell apart: in stock (one with a photo),
/// low, reorder soon, expiring soon, expired, depleted, and one with a very
/// long Kiswahili name and an 8-digit price; plus two in the Stock Store.
final ph7Products = [
  const Ph7Product('p1', 'Albendazole 10%', shelf: 40, imageUrl: 'https://img.test/albendazole.jpg', watchlisted: true,
      description: 'For cattle, goats and sheep'),
  const Ph7Product('p2', 'Ivermectin 1%', shelf: 4, sell: 8000, type: 'Injectable', category: 'Ectoparasiticides'),
  const Ph7Product('p3', 'Vitamin B12', shelf: 8, sell: 4500, category: 'Vitamin & Supplements'),
  const Ph7Product('p4', 'Oxytetracycline 20%', shelf: 25, sell: 12000, expiryDays: 10, category: 'Antibiotic'),
  const Ph7Product('p5', 'Penstrep', shelf: 12, sell: 9000, expiryDays: -10, category: 'Antibiotic'),
  const Ph7Product('p6', 'Newcastle vaccine', shelf: 0, store: 0, sell: 3000, category: 'Vaccines'),
  const Ph7Product('p7', matrixLongProductName, shelf: 30, store: 60, sell: matrixBigAmount, buy: 9000000,
      category: 'Anthelmintics'),
  const Ph7Product('p8', 'Dairy meal 70kg', shelf: 0, store: 15, sell: 65000, buy: 52000, category: 'Feeds', type: 'Feed',
      expiryDays: 120),
];

/// Writes [products] (and one batch each, holding the product's quantities)
/// under the test facility.
Future<void> ph7SeedProducts(FirebaseFirestore fs, [List<Ph7Product>? products]) async {
  for (final p in products ?? ph7Products) {
    final ref = facilityCollection(fs, Collections.products).doc(p.id);
    final expiry = p.expiryDays == null ? null : Timestamp.fromDate(ph7Expiry(p.expiryDays!));
    await ref.set({
      'name': p.name,
      'sellPrice': p.sell,
      'buyPrice': p.buy,
      'sellableQty': p.shelf,
      'stockQty': p.store,
      'unit': 'pcs',
      'category': p.category,
      'type': p.type,
      'hasEverHadStock': true,
      'isWatchlisted': p.watchlisted,
      'batchNo': p.batchNo,
      'description': p.description,
      'imageUrl': p.imageUrl,
      'expiry': expiry,
      'facilityId': testFacilityId,
    });
    await ref.collection(Collections.batches).doc('${p.id}-b1').set({
      'batchNo': p.batchNo,
      'sellableQty': p.shelf,
      'stockQty': p.store,
      'buyPrice': p.buy,
      'expiry': expiry,
    });
  }
}
