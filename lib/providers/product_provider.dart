import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import 'facility_provider.dart';
import '../utils/activity_logger.dart';

class ProductProvider with ChangeNotifier {
  final List<Product> _products = [];

  /// -------------------------------
  /// SINGLE SOURCE OF TRUTH
  /// -------------------------------
  List<Product> get products => List.unmodifiable(_products);

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
  /// FETCH PRODUCTS
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

      _products.add(newProduct);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Add product failed: $e');
    }
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
    }
  }

  /// -------------------------------
  /// PRO MOVE: STOCK → SELLABLE
  /// -------------------------------
  /// ✔ Partial moves supported
  /// ✔ No duplication
  /// ✔ Quantities tracked correctly
/// PRO MOVE: STOCK → SELLABLE (with enhanced logging)
Future<void> moveToSellable(
  Product product,
  int qty,
  BuildContext context, {
  String? notes,
}) async {
  if (qty <= 0 || qty > product.stockQty) {
    debugPrint('❌ Invalid quantity');
    return;
  }

  try {
    // Get user info FIRST (before any async gaps)
    final userInfo = await ActivityLogger.getCurrentUserInfo();
    final userId = userInfo['userId']!;
    final userName = userInfo['userName']!;

    // Store before state for logging
    final stockBefore = product.stockQty;
    final sellableBefore = product.sellableQty;

    // Calculate new quantities
    final updatedProduct = product.copyWith(
      stockQty: product.stockQty - qty,
      sellableQty: product.sellableQty + qty,
      updatedAt: DateTime.now(),
    );

    // Update in Firestore directly (avoid context issues)
    final facilityId = updatedProduct.facilityId;
    
    await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .doc(updatedProduct.id)
        .set(updatedProduct.toMap());

    // Update local state
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
          "Stock: $stockBefore→${updatedProduct.stockQty} | "
          "Sellable: $sellableBefore→${updatedProduct.sellableQty}"
          "${notes != null ? ' | Note: $notes' : ''}",
    );

    // Debug print to verify logging
    debugPrint('🔍 Logged inventory move for ${product.name} in facility: $facilityId');
    
  } catch (e) {
    debugPrint('❌ Move to sellable failed: $e');
    rethrow;
  }
}
  /// -------------------------------
  /// PRO SELL (POS): SELLABLE → SOLD
  /// -------------------------------
  Future<void> sellProduct(
    Product product,
    int qty,
    BuildContext context,
  ) async {
    if (qty <= 0 || qty > product.sellableQty) {
      debugPrint('❌ Invalid sell quantity');
      return;
    }

    final updatedProduct = product.copyWith(
      sellableQty: product.sellableQty - qty,
      updatedAt: DateTime.now(),
    );

    await updateProduct(updatedProduct, context);
  }

  /// -------------------------------
  /// DELETE PRODUCT
  /// -------------------------------
  /// (manual only – not used for moves)
  Future<void> deleteProduct(
    BuildContext context,
    String productId,
  ) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false)
              .selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .doc(productId)
          .delete();

      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Delete product failed: $e');
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
    _products.clear();
    notifyListeners();
  }
}
