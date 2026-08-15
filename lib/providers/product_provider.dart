import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_batch.dart';
import 'facility_provider.dart';
import '../utils/activity_logger.dart';

class ProductProvider with ChangeNotifier {
  final List<Product> _products = [];

  /// -------------------------------
  /// SINGLE SOURCE OF TRUTH
  /// -------------------------------
  List<Product> get products => List.unmodifiable(_products);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _facilityId;

  /// -------------------------------
  /// STOCK STORE (warehouse)
  /// -------------------------------
  List<Product> get stockStoreProducts =>
      _products.where((p) => p.stockQty > 0).toList();

  /// -------------------------------
  /// SELLABLE (front shop / POS)
  /// -------------------------------
  List<Product> get sellableProducts =>
      _products.where((p) => p.sellableQty > 0).toList();

  /// Sellable products by category
  List<Product> getSellableByCategory(String category) {
    return sellableProducts
        .where(
          (p) => p.category.toLowerCase() == category.toLowerCase(),
        )
        .toList();
  }

  /// -------------------------------
  /// LISTEN (real-time) - products used to only ever load via a one-time
  /// fetch, so a product added or restocked on one device wouldn't show up
  /// on another until someone manually refreshed. This brings Products in
  /// line with every other provider in the app (Sales, Clients, Debts,
  /// Services, Transactions all already stream live).
  /// -------------------------------
  void listenToProducts(String facilityId) {
    if (_facilityId == facilityId && _subscription != null) return;

    _facilityId = facilityId;
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      _products
        ..clear()
        ..addAll(
          snapshot.docs.map(
            (doc) => Product.fromFirestore(doc.data(), doc.id),
          ),
        );
      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ ProductProvider listen error: $e');
    });
  }

  /// -------------------------------
  /// ONE-TIME FETCH - kept available for an explicit pull-to-refresh
  /// gesture; the live listener above is what keeps things in sync day to
  /// day, this is just a manual "check right now" escape hatch.
  /// -------------------------------
  Future<void> fetchProducts(String facilityId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .orderBy('name')
          .get();

      _products
        ..clear()
        ..addAll(
          snapshot.docs.map(
            (doc) => Product.fromFirestore(
              doc.data(),
              doc.id,
            ),
          ),
        );

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Fetch products failed: $e');
    }
  }

  /// -------------------------------
  /// ADD PRODUCT
  /// -------------------------------
  /// New products usually start in STOCK
  Future<void> addProduct(
    Product product,
    BuildContext context,
  ) async {
    try {
      final facilityId = product.facilityId.isNotEmpty
          ? product.facilityId
          : Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) return;

      final docRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc();

      final now = DateTime.now();

      final newProduct = product.copyWith(
        id: docRef.id,
        facilityId: facilityId,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(newProduct.toMap());

      // The first delivery is itself a batch - recorded from day one, so
      // "add more stock later" always means "add another batch" instead
      // of silently overwriting this one's real expiry.
      final batchRef = docRef.collection('batches').doc();
      final firstBatch = ProductBatch(
        id: batchRef.id,
        productId: docRef.id,
        batchNo: product.batchNo,
        expiry: product.expiry,
        buyPrice: product.buyPrice,
        stockQty: product.stockQty,
        sellableQty: product.sellableQty,
        receivedAt: now,
      );
      await batchRef.set(firstBatch.toMap());

      // Only append manually if the live listener isn't already
      // watching this facility - if it is (the common case, since
      // Stock Store and Products both start it in initState),
      // Firestore delivers an optimistic local snapshot update to it
      // immediately, often before this very await resolves, so it's
      // already added this product once. Appending here too used to
      // add it a second time - one Firestore document, two entries in
      // the local list, which is exactly why a single product could
      // appear twice in Stock Store. If nothing is listening yet
      // (e.g. adding directly from Dashboard without ever having
      // visited Stock Store or Products first), still append here so
      // the new product shows up immediately rather than silently
      // waiting for some other screen to eventually refresh it.
      if (_subscription == null || _facilityId != facilityId) {
        _products.add(newProduct);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Add product failed: $e');
      rethrow;
    }
  }

  /// -------------------------------
  /// ADD BATCH (new delivery of an existing product)
  /// -------------------------------
  /// Creates a new batch record with its own batch number, expiry, and
  /// quantity - never touches an existing batch's data. Updates the
  /// product's own aggregate stockQty (+ this batch's quantity) and its
  /// `expiry` field to the soonest expiry across all of that product's
  /// batches, so existing screens that read `product.expiry` directly
  /// (Stock Alerts, Products list) keep showing a sensible value without
  /// needing to know about batches at all yet - full per-batch detail is
  /// a later phase.
  Future<bool> addBatch({
    required String facilityId,
    required String productId,
    String? batchNo,
    DateTime? expiry,
    required double buyPrice,
    required int stockQty,
    // 'stock' = warehouse (needs a later "Release" step before it can be
    // sold), 'sellable' = straight to the shelf, ready to sell right
    // away - not every real delivery goes through the warehouse first.
    String destination = 'stock',
  }) async {
    try {
      final productRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(productId);
      final batchesRef = productRef.collection('batches');
      final toSellable = destination == 'sellable';

      // If this batch number + expiry exactly match a batch that
      // already exists, this is really the same delivery/lot arriving
      // again (e.g. a second truck of the same shipment) - merge into
      // it (add quantity, blend buy price) instead of fragmenting one
      // real batch into several records that all mean the same thing.
      // An unlabeled batch number is too ambiguous to match against, so
      // always creates a new record.
      DocumentReference? matchedBatchRef;
      if (batchNo != null && batchNo.trim().isNotEmpty) {
        final candidates = await batchesRef.where('batchNo', isEqualTo: batchNo.trim()).get();
        for (final doc in candidates.docs) {
          final data = doc.data();
          final docExpiry = data['expiry'] is Timestamp ? (data['expiry'] as Timestamp).toDate() : null;
          final sameExpiry = (docExpiry == null && expiry == null) ||
              (docExpiry != null &&
                  expiry != null &&
                  docExpiry.year == expiry.year &&
                  docExpiry.month == expiry.month &&
                  docExpiry.day == expiry.day);
          if (sameExpiry) {
            matchedBatchRef = doc.reference;
            break;
          }
        }
      }

      final wasMerged = matchedBatchRef != null;

      if (matchedBatchRef != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final batchSnap = await transaction.get(matchedBatchRef!);
          if (!batchSnap.exists) return;
          final data = batchSnap.data() as Map<String, dynamic>;

          final existingStock = (data['stockQty'] ?? 0) as int;
          final existingSellable = (data['sellableQty'] ?? 0) as int;
          final existingBuyPrice = (data['buyPrice'] ?? 0).toDouble();
          final existingTotal = existingStock + existingSellable;

          // Weighted average so the batch's recorded cost reflects both
          // deliveries fairly, not just whichever was entered last.
          final blendedBuyPrice = existingTotal + stockQty > 0
              ? ((existingBuyPrice * existingTotal) + (buyPrice * stockQty)) / (existingTotal + stockQty)
              : buyPrice;

          transaction.update(matchedBatchRef, {
            'stockQty': toSellable ? existingStock : existingStock + stockQty,
            'sellableQty': toSellable ? existingSellable + stockQty : existingSellable,
            'buyPrice': blendedBuyPrice,
          });
        });
      } else {
        final batchRef = batchesRef.doc();
        final batch = ProductBatch(
          id: batchRef.id,
          productId: productId,
          batchNo: batchNo,
          expiry: expiry,
          buyPrice: buyPrice,
          stockQty: toSellable ? 0 : stockQty,
          sellableQty: toSellable ? stockQty : 0,
          receivedAt: DateTime.now(),
        );
        await batchRef.set(batch.toMap());
      }

      // Recalculates the product's aggregate fields from every batch's
      // actual current state (including the one just added/merged
      // above), rather than only ever comparing the new batch's expiry
      // against whatever the product's own expiry already was. That
      // older approach could leave a product showing "Expired" even
      // after a fresh, good batch was just added, if an older expired
      // batch was still sitting around with stock - min(old, new) always
      // keeps the earlier date, expired or not.
      final allBatchesSnap = await batchesRef.get();
      final allBatchRefs = allBatchesSnap.docs.map((d) => d.reference).toList();

      Map<String, dynamic>? finalAggregates;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshDocs = <DocumentSnapshot>[];
        for (final ref in allBatchRefs) {
          freshDocs.add(await transaction.get(ref));
        }
        final productSnap = await transaction.get(productRef);
        if (!productSnap.exists) return;

        final batchStates = <String, Map<String, dynamic>>{};
        for (final doc in freshDocs) {
          if (!doc.exists) continue;
          final d = doc.data() as Map<String, dynamic>;
          batchStates[doc.id] = {
            'stockQty': (d['stockQty'] ?? 0) as int,
            'sellableQty': (d['sellableQty'] ?? 0) as int,
            'expiry': d['expiry'] != null ? (d['expiry'] as Timestamp).toDate() : null,
          };
        }

        final aggregates = _recalculateProductAggregates(batchStates);
        finalAggregates = aggregates;

        final pData = productSnap.data()!;
        transaction.update(productRef, {
          'stockQty': aggregates['stockQty'],
          'sellableQty': aggregates['sellableQty'],
          'expiry': aggregates['expiry'] != null ? Timestamp.fromDate(aggregates['expiry']) : null,
          // Kept for quick reference only - the batches subcollection is
          // the real source of truth once more than one batch exists.
          'batchNo': batchNo ?? pData['batchNo'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (finalAggregates != null) {
        final index = _products.indexWhere((p) => p.id == productId);
        if (index != -1) {
          final current = _products[index];
          _products[index] = Product(
            id: current.id,
            name: current.name,
            description: current.description,
            supplier: current.supplier,
            batchNo: batchNo ?? current.batchNo,
            expiry: finalAggregates!['expiry'],
            buyPrice: current.buyPrice,
            sellPrice: current.sellPrice,
            stockQty: finalAggregates!['stockQty'],
            sellableQty: finalAggregates!['sellableQty'],
            unit: current.unit,
            type: current.type,
            category: current.category,
            facilityId: current.facilityId,
            target: current.target,
            createdAt: current.createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }

      return wasMerged;
    } catch (e) {
      debugPrint('❌ Add batch failed: $e');
      rethrow;
    }
  }

  /// Permanently removes one batch - only meant to be offered for a
  /// batch that's already expired (the UI enforces this, not this
  /// method itself, so it stays reusable if that ever needs to change).
  /// Recalculates the product's own aggregate fields from whatever
  /// batches remain afterward, same reasoning as adjustExistingBatch -
  /// this is specifically what correctly clears the product's expiry
  /// once the batch that was carrying it is gone, rather than leaving a
  /// stale expiry date pointing at a batch that no longer exists.
  Future<void> deleteBatch({
    required String facilityId,
    required String productId,
    required String batchId,
  }) async {
    final productRef = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .doc(productId);
    final batchesRef = productRef.collection('batches');

    final allBatchesSnap = await batchesRef.get();
    final allBatchRefs = allBatchesSnap.docs.map((d) => d.reference).toList();

    Map<String, dynamic>? finalAggregates;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final freshDocs = <DocumentSnapshot>[];
      for (final ref in allBatchRefs) {
        freshDocs.add(await transaction.get(ref));
      }

      final targetExists = freshDocs.any((d) => d.id == batchId && d.exists);
      if (!targetExists) return; // already gone - nothing to do

      final batchStates = <String, Map<String, dynamic>>{};
      for (final doc in freshDocs) {
        if (!doc.exists) continue;
        if (doc.id == batchId) continue; // being deleted - excluded entirely
        final d = doc.data() as Map<String, dynamic>;
        batchStates[doc.id] = {
          'stockQty': (d['stockQty'] ?? 0) as int,
          'sellableQty': (d['sellableQty'] ?? 0) as int,
          'expiry': d['expiry'] != null ? (d['expiry'] as Timestamp).toDate() : null,
        };
      }

      final aggregates = _recalculateProductAggregates(batchStates);
      finalAggregates = aggregates;

      transaction.delete(batchesRef.doc(batchId));

      transaction.update(productRef, {
        'stockQty': aggregates['stockQty'],
        'sellableQty': aggregates['sellableQty'],
        'expiry': aggregates['expiry'] != null ? Timestamp.fromDate(aggregates['expiry']) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (finalAggregates != null) {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final current = _products[index];
        _products[index] = Product(
          id: current.id,
          name: current.name,
          description: current.description,
          supplier: current.supplier,
          batchNo: current.batchNo,
          expiry: finalAggregates!['expiry'],
          buyPrice: current.buyPrice,
          sellPrice: current.sellPrice,
          stockQty: finalAggregates!['stockQty'],
          sellableQty: finalAggregates!['sellableQty'],
          unit: current.unit,
          type: current.type,
          category: current.category,
          facilityId: current.facilityId,
          target: current.target,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }
  }

  /// Computes a product's own stockQty, sellableQty, and expiry directly
  /// from the current state of all its batches - the soonest expiry
  /// among batches that still have something left (a fully depleted
  /// batch's expiry shouldn't count toward what's actually on hand).
  /// [batchStates] maps batch ID to its current {stockQty, sellableQty,
  /// expiry} - the caller is responsible for already having applied
  /// whatever change (an adjustment, a deletion) before calling this,
  /// so what's passed in reflects the batches' state *after* that
  /// change, not before it.
  Map<String, dynamic> _recalculateProductAggregates(
    Map<String, Map<String, dynamic>> batchStates,
  ) {
    int totalStock = 0;
    int totalSellable = 0;
    // Tracked separately so a product with any genuinely good stock left
    // never gets labeled "Expired" as a whole just because some other,
    // smaller batch has gone bad - that would wrongly discourage staff
    // from selling stock that's perfectly fine. The soonest *good* date
    // still drives "Expiring Soon" normally. Only when every last unit
    // remaining is expired does the product fall back to showing that
    // expired date - which is the one case where "Expired" for the
    // whole product is actually true. A batch that's individually
    // expired is still separately surfaced in Notifications regardless
    // of this, since that screen queries batches directly rather than
    // relying on this aggregate.
    DateTime? soonestGoodExpiry;
    DateTime? soonestExpiredExpiry;
    final now = DateTime.now();

    for (final state in batchStates.values) {
      final stock = state['stockQty'] as int? ?? 0;
      final sellable = state['sellableQty'] as int? ?? 0;
      totalStock += stock;
      totalSellable += sellable;

      if (stock + sellable > 0) {
        final expiry = state['expiry'] as DateTime?;
        if (expiry != null) {
          if (expiry.isBefore(now)) {
            if (soonestExpiredExpiry == null || expiry.isBefore(soonestExpiredExpiry)) {
              soonestExpiredExpiry = expiry;
            }
          } else {
            if (soonestGoodExpiry == null || expiry.isBefore(soonestGoodExpiry)) {
              soonestGoodExpiry = expiry;
            }
          }
        }
      }
    }

    final chosenExpiry = soonestGoodExpiry ?? soonestExpiredExpiry;

    return {'stockQty': totalStock, 'sellableQty': totalSellable, 'expiry': chosenExpiry};
  }

  /// Directly adjusts one specific existing batch's quantity - either
  /// adding to it (a delivery top-up for that exact batch) or correcting
  /// it to an exact value (fixing a miscount). Recalculates the
  /// product's own aggregate fields from every batch's actual current
  /// state afterward, rather than applying a delta on top of whatever
  /// the product's stockQty/sellableQty/expiry already were - deltas
  /// applied independently across several different methods over time
  /// (adding a batch, adjusting one, deleting one) can drift out of sync
  /// with what the batches actually add up to, and never self-correct.
  /// Recalculating from the batches themselves, every time, means the
  /// product's totals are always exactly what's really there.
  Future<void> adjustExistingBatch({
    required String facilityId,
    required String productId,
    required String batchId,
    required String mode, // 'add' or 'set'
    int? stockQty,
    int? sellableQty,
  }) async {
    final productRef = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .doc(productId);
    final batchesRef = productRef.collection('batches');

    // The list of batches to recalculate from - queried outside the
    // transaction, since Firestore transactions can only read specific
    // documents you already know, not run queries.
    final allBatchesSnap = await batchesRef.get();
    final allBatchRefs = allBatchesSnap.docs.map((d) => d.reference).toList();

    Map<String, dynamic>? finalAggregates;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads before any writes, every one of them - see the note
      // above this method's previous version for exactly why that order
      // matters.
      final freshDocs = <DocumentSnapshot>[];
      for (final ref in allBatchRefs) {
        freshDocs.add(await transaction.get(ref));
      }

      final targetDoc = freshDocs.firstWhere(
        (d) => d.id == batchId,
        orElse: () => throw Exception('Batch no longer exists'),
      );
      final data = targetDoc.data() as Map<String, dynamic>;
      final currentStock = (data['stockQty'] ?? 0) as int;
      final currentSellable = (data['sellableQty'] ?? 0) as int;

      final int newStock;
      final int newSellable;
      if (mode == 'set') {
        newStock = stockQty ?? currentStock;
        newSellable = sellableQty ?? currentSellable;
      } else {
        newStock = currentStock + (stockQty ?? 0);
        newSellable = currentSellable + (sellableQty ?? 0);
      }
      final clampedStock = newStock < 0 ? 0 : newStock;
      final clampedSellable = newSellable < 0 ? 0 : newSellable;

      // Build the post-change state of every batch, substituting the
      // freshly-computed values for the one actually being adjusted.
      final batchStates = <String, Map<String, dynamic>>{};
      for (final doc in freshDocs) {
        if (!doc.exists) continue;
        final d = doc.data() as Map<String, dynamic>;
        if (doc.id == batchId) {
          batchStates[doc.id] = {
            'stockQty': clampedStock,
            'sellableQty': clampedSellable,
            'expiry': d['expiry'] != null ? (d['expiry'] as Timestamp).toDate() : null,
          };
        } else {
          batchStates[doc.id] = {
            'stockQty': (d['stockQty'] ?? 0) as int,
            'sellableQty': (d['sellableQty'] ?? 0) as int,
            'expiry': d['expiry'] != null ? (d['expiry'] as Timestamp).toDate() : null,
          };
        }
      }

      final aggregates = _recalculateProductAggregates(batchStates);
      finalAggregates = aggregates;

      transaction.update(batchesRef.doc(batchId), {
        'stockQty': clampedStock,
        'sellableQty': clampedSellable,
      });

      transaction.update(productRef, {
        'stockQty': aggregates['stockQty'],
        'sellableQty': aggregates['sellableQty'],
        'expiry': aggregates['expiry'] != null ? Timestamp.fromDate(aggregates['expiry']) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (finalAggregates != null) {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final current = _products[index];
        // Built directly rather than via copyWith, since copyWith can't
        // express "clear expiry to null" - only "leave it as-is" or
        // "replace it with a non-null value" - and a product whose last
        // remaining expiring batch was just fully cleared out needs
        // exactly that: expiry genuinely becoming null, not staying at
        // whatever it was before.
        _products[index] = Product(
          id: current.id,
          name: current.name,
          description: current.description,
          supplier: current.supplier,
          batchNo: current.batchNo,
          expiry: finalAggregates!['expiry'],
          buyPrice: current.buyPrice,
          sellPrice: current.sellPrice,
          stockQty: finalAggregates!['stockQty'],
          sellableQty: finalAggregates!['sellableQty'],
          unit: current.unit,
          type: current.type,
          category: current.category,
          facilityId: current.facilityId,
          target: current.target,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }
  }

  /// Real-time list of a product's batches, soonest-expiry first - useful
  /// for seeing at a glance which delivery should be sold/used first,
  /// even before Sales enforces that automatically (a later phase).
  Stream<List<ProductBatch>> streamBatchesForProduct(String facilityId, String productId) {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .doc(productId)
        .collection('batches')
        .orderBy('expiry', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductBatch.fromFirestore(doc.data(), doc.id, productId))
            .toList());
  }

  /// -------------------------------
  /// UPDATE PRODUCT
  /// -------------------------------
  Future<void> updateProduct(
    Product updatedProduct,
    BuildContext context,
  ) async {
    try {
      final facilityId = updatedProduct.facilityId.isNotEmpty
          ? updatedProduct.facilityId
          : Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) return;

      final updated = updatedProduct.copyWith(
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(updated.id)
          .set(updated.toMap());

      final index = _products.indexWhere((p) => p.id == updated.id);
      if (index != -1) {
        _products[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Update product failed: $e');
      rethrow;
    }
  }

  /// -------------------------------
  /// PRO MOVE: STOCK → SELLABLE
  /// -------------------------------
  /// ✔ Partial moves supported
  /// ✔ No duplication
  /// ✔ Quantities tracked correctly
  /// ✔ Transaction-safe - reads the CURRENT server value and validates
  ///   inside the same atomic transaction, instead of trusting the
  ///   quantity on the in-memory `product` object passed in. Two staff
  ///   releasing stock on the same product at nearly the same moment can
  ///   no longer silently overwrite each other's update.
  /// -------------------------------
  /// FIFO STOCK DEDUCTION (Sales & Services)
  /// -------------------------------
  /// Deducts [quantity] from sellable stock, taking from the batch with
  /// the soonest expiry first - so stock at the greatest risk of
  /// expiring unsold gets sold first. Returns the specific batches
  /// consumed (and how much from each), so a later deletion can restore
  /// exactly those amounts to exactly those batches.
  ///
  /// Falls back to the old aggregate-only behavior when a product has no
  /// batch records at all - this is what keeps every product created
  /// before batch tracking existed fully sellable without any manual
  /// migration. The single legacy allocation this produces still
  /// restores correctly if that sale is later deleted.
  Future<List<Map<String, dynamic>>> deductSellableFIFO({
    required String facilityId,
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) return [];

    final firestore = FirebaseFirestore.instance;
    final productRef =
        firestore.collection('facilities').doc(facilityId).collection('products').doc(productId);
    final batchesRef = productRef.collection('batches');

    // Query outside the transaction (Firestore transactions can only
    // read specific documents you already know, not run queries) to
    // work out which batches to target, soonest-expiry first. No expiry
    // set sorts last - treated as "keep aside", not urgent.
    final candidateSnap = await batchesRef.where('sellableQty', isGreaterThan: 0).get();

    if (candidateSnap.docs.isEmpty) {
      // No batches at all for this product - legacy path.
      return _deductLegacyAggregate(productRef: productRef, quantity: quantity);
    }

    final candidates = candidateSnap.docs.toList()
      ..sort((a, b) {
        final aExp = a.data()['expiry'] as Timestamp?;
        final bExp = b.data()['expiry'] as Timestamp?;
        if (aExp == null && bExp == null) return 0;
        if (aExp == null) return 1;
        if (bExp == null) return -1;
        return aExp.compareTo(bExp);
      });

    final allocations = <Map<String, dynamic>>[];

    await firestore.runTransaction((transaction) async {
      final freshDocs = <DocumentSnapshot>[];
      for (final doc in candidates) {
        freshDocs.add(await transaction.get(doc.reference));
      }
      final productSnap = await transaction.get(productRef);

      allocations.clear();
      int remaining = quantity;

      for (final snap in freshDocs) {
        if (remaining <= 0) break;
        if (!snap.exists) continue;
        final data = snap.data() as Map<String, dynamic>;
        final available = (data['sellableQty'] ?? 0) as int;
        if (available <= 0) continue;

        final take = remaining < available ? remaining : available;
        final buyPrice = (data['buyPrice'] ?? 0).toDouble();

        transaction.update(snap.reference, {'sellableQty': available - take});
        allocations.add({'batchId': snap.id, 'quantity': take, 'buyPrice': buyPrice});
        remaining -= take;
      }

      if (remaining > 0) {
        throw Exception('Not enough sellable stock across all batches');
      }

      if (productSnap.exists) {
        final currentAgg = (productSnap.data()?['sellableQty'] ?? 0) as int;
        transaction.update(productRef, {'sellableQty': currentAgg - quantity});
      }
    });

    return allocations;
  }

  Future<List<Map<String, dynamic>>> _deductLegacyAggregate({
    required DocumentReference productRef,
    required int quantity,
  }) async {
    double buyPrice = 0;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception('Product no longer exists');
      final data = snapshot.data() as Map<String, dynamic>;
      final currentSellable = (data['sellableQty'] ?? 0) as int;
      buyPrice = (data['buyPrice'] ?? 0).toDouble();
      if (quantity > currentSellable) {
        throw Exception('Not enough sellable stock');
      }
      transaction.update(productRef, {'sellableQty': currentSellable - quantity});
    });
    return [
      {'batchId': null, 'quantity': quantity, 'buyPrice': buyPrice}
    ];
  }

  /// Reverses a previous FIFO deduction (or legacy deduction) - used when
  /// a sale is deleted. Restores each recorded allocation to its exact
  /// batch; a legacy allocation (batchId null) just restores the
  /// product's own aggregate directly.
  Future<void> restoreSellableFIFO({
    required String facilityId,
    required String productId,
    required List<Map<String, dynamic>> allocations,
  }) async {
    if (allocations.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final productRef =
        firestore.collection('facilities').doc(facilityId).collection('products').doc(productId);
    final batchesRef = productRef.collection('batches');

    int totalRestored = 0;

    await firestore.runTransaction((transaction) async {
      final batchRefs = allocations
          .where((a) => a['batchId'] != null)
          .map((a) => batchesRef.doc(a['batchId'] as String))
          .toList();
      final freshDocs = <DocumentSnapshot>[];
      for (final ref in batchRefs) {
        freshDocs.add(await transaction.get(ref));
      }
      final productSnap = await transaction.get(productRef);

      var docIndex = 0;
      for (final alloc in allocations) {
        final qty = (alloc['quantity'] ?? 0) as int;
        totalRestored += qty;
        if (alloc['batchId'] == null) continue;

        final snap = freshDocs[docIndex++];
        if (!snap.exists) continue; // batch may have been deleted since
        final data = snap.data() as Map<String, dynamic>;
        final current = (data['sellableQty'] ?? 0) as int;
        transaction.update(snap.reference, {'sellableQty': current + qty});
      }

      if (productSnap.exists) {
        final currentAgg = (productSnap.data()?['sellableQty'] ?? 0) as int;
        transaction.update(productRef, {'sellableQty': currentAgg + totalRestored});
      }
    });
  }

  Future<void> moveToSellable(
    Product product,
    int qty,
    BuildContext context, {
    String? notes,
  }) async {
    if (qty <= 0) {
      debugPrint('❌ Invalid quantity');
      return;
    }

    final facilityId = product.facilityId;
    final productRef = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .doc(product.id);

    try {
      final userInfo = await ActivityLogger.getCurrentUserInfo();
      final userId = userInfo['userId']!;
      final userName = userInfo['userName']!;

      late int stockBefore;
      late int sellableBefore;
      late int newStock;
      late int newSellable;

      // Query outside the transaction to find which batches to move from
      // (soonest-expiry warehouse stock first) - falls back to the old
      // aggregate-only behavior below when a product has no batch
      // records yet (created before batch tracking existed).
      final batchesRef = productRef.collection('batches');
      final candidateSnap = await batchesRef.where('stockQty', isGreaterThan: 0).get();

      if (candidateSnap.docs.isNotEmpty) {
        final candidates = candidateSnap.docs.toList()
          ..sort((a, b) {
            final aExp = a.data()['expiry'] as Timestamp?;
            final bExp = b.data()['expiry'] as Timestamp?;
            if (aExp == null && bExp == null) return 0;
            if (aExp == null) return 1;
            if (bExp == null) return -1;
            return aExp.compareTo(bExp);
          });

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final freshDocs = <DocumentSnapshot>[];
          for (final doc in candidates) {
            freshDocs.add(await transaction.get(doc.reference));
          }
          final productSnap = await transaction.get(productRef);
          if (!productSnap.exists) throw Exception('Product no longer exists');

          final currentStock = (productSnap.data()?['stockQty'] ?? 0) as int;
          final currentSellable = (productSnap.data()?['sellableQty'] ?? 0) as int;
          if (qty > currentStock) throw Exception('Not enough stock available');

          stockBefore = currentStock;
          sellableBefore = currentSellable;

          int remaining = qty;
          for (final snap in freshDocs) {
            if (remaining <= 0) break;
            if (!snap.exists) continue;
            final data = snap.data() as Map<String, dynamic>;
            final availableStock = (data['stockQty'] ?? 0) as int;
            final batchSellable = (data['sellableQty'] ?? 0) as int;
            if (availableStock <= 0) continue;

            final take = remaining < availableStock ? remaining : availableStock;
            transaction.update(snap.reference, {
              'stockQty': availableStock - take,
              'sellableQty': batchSellable + take,
            });
            remaining -= take;
          }

          newStock = currentStock - qty;
          newSellable = currentSellable + qty;
          transaction.update(productRef, {
            'stockQty': newStock,
            'sellableQty': newSellable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(productRef);
          if (!snapshot.exists) {
            throw Exception('Product no longer exists');
          }

          final currentStock = (snapshot.data()?['stockQty'] ?? 0) as int;
          final currentSellable = (snapshot.data()?['sellableQty'] ?? 0) as int;

          if (qty > currentStock) {
            throw Exception('Not enough stock available');
          }

          stockBefore = currentStock;
          sellableBefore = currentSellable;
          newStock = currentStock - qty;
          newSellable = currentSellable + qty;

          transaction.update(productRef, {
            'stockQty': newStock,
            'sellableQty': newSellable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }

      // Update local state
      final updatedProduct = product.copyWith(
        stockQty: newStock,
        sellableQty: newSellable,
        updatedAt: DateTime.now(),
      );
      final index = _products.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _products[index] = updatedProduct;
        notifyListeners();
      }

      // Log the movement activity
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userId,
        userName: userName,
        actionType: "Inventory Move",
        description: "📦→🛒 ${product.name}: $qty ${product.unit} | "
            "Stock: $stockBefore→$newStock | "
            "Sellable: $sellableBefore→$newSellable"
            "${notes != null ? ' | Note: $notes' : ''}",
      );

      debugPrint('🔍 Logged inventory move for ${product.name} in facility: $facilityId');
    } catch (e) {
      debugPrint('❌ Move to sellable failed: $e');
      rethrow;
    }
  }

  /// -------------------------------
  /// DELETE PRODUCT
  /// -------------------------------
  /// Moves the product to `trash_products` instead of erasing it
  /// permanently, so an accidental delete can be undone from the Trash
  /// screen. Auto-purged after 30 days by a scheduled Cloud Function.
  Future<void> deleteProduct(
    BuildContext context,
    String productId,
  ) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) return;

      final docRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(productId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final userInfo = await ActivityLogger.getCurrentUserInfo();

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('trash_products')
          .doc(productId)
          .set({
        ...snapshot.data()!,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': userInfo['userName'],
      });

      await docRef.delete();

      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Delete product failed: $e');
      rethrow;
    }
  }

  ///CALCULATIONS
  /// Total product value (inventory cost)
  double get totalProductValue {
    double total = 0;
    for (final p in _products) {
      total += (p.stockQty + p.sellableQty) * p.buyPrice;
    }
    return total;
  }

  /// Optional: total potential revenue
  double get totalPotentialRevenue {
    double total = 0;
    for (final p in _products) {
      total += (p.stockQty + p.sellableQty) * p.sellPrice;
    }
    return total;
  }

  /// -------------------------------
  /// CLEAR (logout / switch facility)
  /// -------------------------------
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _facilityId = null;
    _products.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
