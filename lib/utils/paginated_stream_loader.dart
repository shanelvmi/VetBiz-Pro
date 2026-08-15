import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

mixin PaginatedStreamLoader<T> on ChangeNotifier {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  StreamSubscription<QuerySnapshot>? _subscription;

  // Set when the live stream itself fails (most commonly a missing
  // Firestore composite index for whatever query was passed in) -
  // previously this failed completely silently, leaving the screen
  // stuck on a loading spinner forever with nothing to tell the user,
  // or the developer, that anything had gone wrong.
  Object? _streamError;
  Object? get streamError => _streamError;

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
    _streamError = null;

    _subscription = query.limit(limit).snapshots().listen((snapshot) {
      _items.clear();
      for (var doc in snapshot.docs) {
        _items.add(fromDoc(doc));
      }
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      // If Firestore handed back fewer docs than the requested limit,
      // that's genuinely everything there is - no further page to load.
      // Previously this only ever got set inside loadMore(), so the very
      // first page (however small) always showed a Load More control
      // regardless of whether there was actually anything more to load.
      _hasMore = snapshot.docs.length >= limit;
      _streamError = null;
      notifyListeners();
    }, onError: (error) {
      _streamError = error;
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

    try {
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
        _hasMore = snapshot.docs.length >= limit;
      }
    } catch (e) {
      _streamError = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
