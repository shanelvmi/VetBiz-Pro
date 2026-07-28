import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

mixin PaginatedStreamLoader<T> on ChangeNotifier {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  /// Override this in your provider to convert a Firestore doc into your model
  T fromDoc(DocumentSnapshot doc);

  /// Start real-time listening to Firestore
  void initStream({
    required Query query,
    int limit = 100, // Load first 100 instantly
  }) {
    _subscription?.cancel();
    _items.clear();
    _lastDocument = null;
    _hasMore = true;

    _subscription = query.limit(limit).snapshots().listen((snapshot) {
      _items.clear();
      for (var doc in snapshot.docs) {
        _items.add(fromDoc(doc));
      }
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      notifyListeners();
    });
  }

  /// Load more for pagination
  Future<void> loadMore({
    required Query query,
    int limit = 50, // Load 50 at a time when scrolling
  }) async {
    if (!_hasMore || _isLoading || _lastDocument == null) return;

    _isLoading = true;
    notifyListeners();

    final snapshot = await query
        .startAfterDocument(_lastDocument!)
        .limit(limit)
        .get();

    if (snapshot.docs.isEmpty) {
      _hasMore = false;
    } else {
      for (var doc in snapshot.docs) {
        _items.add(fromDoc(doc));
      }
      _lastDocument = snapshot.docs.last;
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
