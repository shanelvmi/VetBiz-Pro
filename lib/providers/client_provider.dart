import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../utils/paginated_stream_loader.dart';
import '../services/cursor_paginated_list_controller.dart';

// Two genuinely different loading strategies coexist here, because they
// serve two genuinely different needs:
//
// - The unbounded listenToClients()/getClientById() path stays exactly
//   as it was - Debtors needs to look up ANY client by ID (whichever
//   debtor happens to have an outstanding balance right now), and a
//   partial, paginated list can't answer "does this specific client
//   exist and what's their current phone number" reliably.
//
// - The paginated path (via PaginatedStreamLoader) is new, and is what
//   the main Clients browse screen actually uses - loading the first
//   ~100 clients instead of the entire collection at once, with search
//   and the type filter both running as direct Firestore queries rather
//   than filtering whatever's already been paginated in, so they find
//   the right client regardless of whether that client has been loaded
//   into the current page yet.
class ClientProvider with ChangeNotifier, PaginatedStreamLoader<Client> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClientProvider() {
    clientsListController = CursorPaginatedListController<Client>(
      pageSize: 25,
      fetchPage: _fetchClientsListPage,
      countCreatedAfter: _countNewClients,
    );
    debtorsListController = CursorPaginatedListController<Client>(
      pageSize: 25,
      fetchPage: _fetchDebtorsListPage,
    );
  }

  @override
  Client fromDoc(DocumentSnapshot doc) {
    return Client.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // ==================== UNBOUNDED (Debtors' use case) ====================

  List<Client> _clients = [];
  List<Client> get clients => [..._clients];

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clientsSubscription;

  /// Real-time listening to ALL clients for a facility - kept unbounded
  /// deliberately, since this is what Debtors relies on via
  /// getClientById() to show any debtor's current name/phone, not just
  /// whichever page of clients has been paginated in so far.
  void listenToClients(String facilityId) {
    debugPrint('ClientProvider.listenToClients called with facilityId: $facilityId');
    _clientsSubscription?.cancel();
    _hasLoaded = false;
    if (facilityId.isEmpty) return;

    final collection = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients');

    _clientsSubscription = collection.snapshots().listen((snapshot) {
      _clients = snapshot.docs
          .map((doc) => Client.fromMap(doc.id, doc.data()))
          .toList();
      _hasLoaded = true;

      debugPrint('ClientProvider: loaded ${_clients.length} clients');
      notifyListeners();
    }, onError: (error) {
      debugPrint('Client listen error: $error');
      _hasLoaded = true; // stop showing a loading spinner forever on error too
      notifyListeners();
    });
  }

  /// Clear all clients
  void clear() {
    _clients.clear();
    _hasLoaded = false;
    notifyListeners();
  }

  /// One-time fetch
  Future<void> fetchClients(String facilityId) async {
    try {
      final snapshot = await _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .orderBy('name')
          .get();

      _clients = snapshot.docs
          .map((doc) => Client.fromMap(doc.id, doc.data()))
          .toList();
      _hasLoaded = true;

      debugPrint('ClientProvider snapshot length: ${_clients.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      _hasLoaded = true;
    }
  }

  /// Get client by ID - only reliable against the unbounded list above,
  /// not the paginated one, since the paginated list may not include
  /// this particular client yet.
  Client? getClientById(String id) {
    try {
      return _clients.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filtered lists
  List<Client> get debtors => _clients.where((c) => c.balance > 0).toList();
  List<Client> get nonDebtors => _clients.where((c) => c.balance <= 0).toList();

  double get totalOutstandingPayment {
    return _clients
        .where((c) => c.balance > 0)
        .fold(0.0, (sum, client) => sum + client.balance);
  }

  // ==================== PAGINATED (Clients browse screen) ====================

  String? _pagedFacilityId;
  String? _activeTypeFilter; // null = no type filter ("All")

  /// Starts (or restarts) the paginated client list for browsing - the
  /// first page loads live via initStream(); loadMoreClients() below
  /// fetches additional pages as the user scrolls. Called again
  /// whenever the type filter changes, since that changes the
  /// underlying query itself, not just a local filter.
  void listenToClientsPaginated(String facilityId, {String? typeFilter}) {
    if (facilityId.isEmpty) return;
    _pagedFacilityId = facilityId;
    _activeTypeFilter = typeFilter;

    Query query = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .orderBy('name');

    if (typeFilter != null) {
      query = query.where('types', arrayContains: typeFilter);
    }

    initStream(query: query, limit: 100);
  }

  /// Loads the next page of clients, using whichever query (with or
  /// without a type filter) is currently active.
  Future<void> loadMorePagedClients() async {
    if (_pagedFacilityId == null) return;

    Query query = _firestore
        .collection('facilities')
        .doc(_pagedFacilityId)
        .collection('clients')
        .orderBy('name');

    if (_activeTypeFilter != null) {
      query = query.where('types', arrayContains: _activeTypeFilter);
    }

    await loadMore(query: query, limit: 50);
  }

  /// Direct, one-time search against Firestore itself - not a filter
  /// over whatever's currently paginated in, since that would only ever
  /// find matches among however many clients happen to be loaded so
  /// far. Requires nameLower to be present on the document - see the
  /// note on rebuildSearchIndex() below for what that means for clients
  /// created before this field existed.
  Future<List<Client>> searchClientsByName(String facilityId, String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .orderBy('nameLower')
        .where('nameLower', isGreaterThanOrEqualTo: q)
        .where('nameLower', isLessThan: '$q\uf8ff')
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => Client.fromMap(doc.id, doc.data())).toList();
  }

  /// One-time, admin-triggered backfill for clients created before
  /// nameLower existed - without this, a client who's never been
  /// opened and re-saved since this feature shipped simply won't have
  /// nameLower set on their document at all, and Firestore queries
  /// can't match a field that isn't there. This is NOT run
  /// automatically (that would mean re-downloading the entire
  /// collection on every app load, exactly what pagination is meant to
  /// avoid) - it's meant to be triggered once, deliberately, from
  /// Settings.
  Future<int> rebuildSearchIndex(String facilityId) async {
    final snapshot = await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .get();

    final batch = _firestore.batch();
    int updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['nameLower'] == null) {
        final name = (data['name'] as String?) ?? '';
        batch.update(doc.reference, {'nameLower': name.toLowerCase()});
        updated++;
      }
    }

    if (updated > 0) {
      await batch.commit();
    }
    return updated;
  }

  // ==================== Clients browse screen: real cursor pagination ====================
  //
  // A third, separate mechanism, alongside the unbounded
  // listenToClients() above (Debtors' lookup needs) and the
  // PaginatedStreamLoader mixin's own paginated path (whose first page
  // is still a live listener - the exact instability this replaces).
  // Ordered by createdAt, not name - name is user-editable and isn't a
  // reliable, monotonic field for a stable cursor, the same reason
  // ServiceProvider's equivalent section uses serviceDate rather than
  // a field someone can freely edit after the fact.

  /// searchTerm reuses the exact same nameLower prefix-match
  /// searchClientsByName already used - see SaleProvider's identical
  /// field for why a search term can't combine with the snapshot
  /// boundary in the same query (Firestore's one-range-filter-per-query
  /// limit), and why that's an accepted, deliberate trade-off here too.
  ({String searchTerm, String typeFilter, String statusFilter}) _clientsListQuery =
      (searchTerm: '', typeFilter: 'All', statusFilter: 'All');

  late final CursorPaginatedListController<Client> clientsListController;

  String? _clientsListFacilityId;

  ({String searchTerm, String typeFilter, String statusFilter}) updateClientsListFilters({
    required String facilityId,
    required String searchTerm,
    required String typeFilter,
    required String statusFilter,
  }) {
    _clientsListFacilityId = facilityId;
    _clientsListQuery = (
      searchTerm: searchTerm.trim().toLowerCase(),
      typeFilter: typeFilter,
      statusFilter: statusFilter,
    );
    return _clientsListQuery;
  }

  Future<CursorPage<Client>> _fetchClientsListPage({
    required DateTime snapshotAt,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final facilityId = _clientsListFacilityId;
    if (facilityId == null) {
      return const CursorPage(items: [], lastDocument: null, hasMore: false);
    }

    final q = _clientsListQuery;
    final hasSearch = q.searchTerm.isNotEmpty;
    Query<Map<String, dynamic>> query =
        _firestore.collection('facilities').doc(facilityId).collection('clients');

    if (q.typeFilter != 'All') {
      query = query.where('types', arrayContains: q.typeFilter);
    }
    if (q.statusFilter != 'All') {
      query = query.where('status', isEqualTo: q.statusFilter);
    }

    if (hasSearch) {
      query = query
          .where('nameLower', isGreaterThanOrEqualTo: q.searchTerm)
          .where('nameLower', isLessThan: '${q.searchTerm}\uf8ff')
          .orderBy('nameLower')
          .orderBy(FieldPath.documentId);
    } else {
      query = query
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(snapshotAt))
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return CursorPage(
      items: snapshot.docs.map((d) => Client.fromMap(d.id, d.data())).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= pageSize,
    );
  }

  Future<int> _countNewClients({required DateTime after}) async {
    final facilityId = _clientsListFacilityId;
    if (facilityId == null) return 0;

    final q = _clientsListQuery;
    if (q.searchTerm.isNotEmpty) return 0;

    Query<Map<String, dynamic>> query = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(after));
    if (q.typeFilter != 'All') {
      query = query.where('types', arrayContains: q.typeFilter);
    }
    if (q.statusFilter != 'All') {
      query = query.where('status', isEqualTo: q.statusFilter);
    }

    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  // ==================== Debtors screen: clients where balance > 0 ====================
  //
  // A separate cursor session from clientsListController above - same
  // controller type, since this is still "browse one collection,
  // filtered and sorted," but a distinct instance so the Debtors and
  // Clients screens don't share (and clobber) each other's session
  // state if both happen to be relevant at once.
  //
  // debtOverdueDays is no longer a fixed constant here - it's a real,
  // per-facility, admin-configurable setting (FacilityProvider.
  // debtOverdueDays), passed in below by whoever calls
  // updateDebtorsListFilters. Individual debt records remain the
  // source of truth for the exact overdue amount; this and
  // oldestUnpaidDebtDate are only maintained summaries that let this
  // list-level filtering stay a real query instead of loading every
  // debt.

  late final CursorPaginatedListController<Client> debtorsListController;

  String? _debtorsListFacilityId;

  /// searchTerm: prefix match against nameLower, same trade-off as
  /// every other module this session - can't combine with the
  /// balance/oldestUnpaidDebtDate range in the same query, so an active
  /// search is a point-in-time lookup across all debtors, not bounded
  /// by the status/range filters. statusFilter is 'All' | 'Overdue' |
  /// 'Current'. overdueRangeFilter is 'All' | '1-30 days' | '31-60
  /// days' | '60+ days' - only meaningful when statusFilter isn't
  /// already narrowing by itself, matching the existing screen's own
  /// filter combination logic. overdueDays is the facility's own
  /// configured threshold (FacilityProvider.debtOverdueDays) - part of
  /// the query signature, so a facility admin changing it correctly
  /// opens a fresh session rather than silently keeping stale results.
  ({String searchTerm, String statusFilter, String overdueRangeFilter, int overdueDays}) _debtorsListQuery = (
    searchTerm: '',
    statusFilter: 'All',
    overdueRangeFilter: 'All',
    overdueDays: 30,
  );

  ({String searchTerm, String statusFilter, String overdueRangeFilter, int overdueDays}) updateDebtorsListFilters({
    required String facilityId,
    required String searchTerm,
    required String statusFilter,
    required String overdueRangeFilter,
    required int overdueDays,
  }) {
    _debtorsListFacilityId = facilityId;
    _debtorsListQuery = (
      searchTerm: searchTerm.trim().toLowerCase(),
      statusFilter: statusFilter,
      overdueRangeFilter: overdueRangeFilter,
      overdueDays: overdueDays,
    );
    return _debtorsListQuery;
  }

  /// Bounds for the active status/range filter, in terms of
  /// oldestUnpaidDebtDate - null,null means "no overdue-based filter is
  /// active," which tells the fetch method to range on balance instead.
  (DateTime? olderThanOrEqual, DateTime? newerThan) _overdueDateBounds(
    ({String searchTerm, String statusFilter, String overdueRangeFilter, int overdueDays}) q,
    DateTime now,
  ) {
    if (q.statusFilter == 'Overdue') {
      return (now.subtract(Duration(days: q.overdueDays)), null);
    }
    if (q.statusFilter == 'Current') {
      return (null, now.subtract(Duration(days: q.overdueDays)));
    }
    switch (q.overdueRangeFilter) {
      case '1-30 days':
        return (now.subtract(const Duration(days: 1)), now.subtract(const Duration(days: 30)));
      case '31-60 days':
        return (now.subtract(const Duration(days: 31)), now.subtract(const Duration(days: 60)));
      case '60+ days':
        return (now.subtract(const Duration(days: 60)), null);
      default:
        return (null, null);
    }
  }

  Future<CursorPage<Client>> _fetchDebtorsListPage({
    required DateTime snapshotAt,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final facilityId = _debtorsListFacilityId;
    if (facilityId == null) {
      return const CursorPage(items: [], lastDocument: null, hasMore: false);
    }

    final q = _debtorsListQuery;
    final hasSearch = q.searchTerm.isNotEmpty;
    Query<Map<String, dynamic>> query =
        _firestore.collection('facilities').doc(facilityId).collection('clients');

    if (hasSearch) {
      query = query
          .where('nameLower', isGreaterThanOrEqualTo: q.searchTerm)
          .where('nameLower', isLessThan: '${q.searchTerm}\uf8ff')
          .orderBy('nameLower')
          .orderBy(FieldPath.documentId);
    } else {
      final (olderThanOrEqual, newerThan) = _overdueDateBounds(q, snapshotAt);
      if (olderThanOrEqual != null || newerThan != null) {
        // An overdue-based filter is active - range on
        // oldestUnpaidDebtDate instead of balance (Firestore allows
        // only one inequality field per query). Any client with an
        // actual unpaid debt has this field set, so this stays
        // implicitly scoped to real debtors without also needing
        // balance > 0 in the same query.
        if (olderThanOrEqual != null) {
          query = query.where('oldestUnpaidDebtDate', isLessThanOrEqualTo: Timestamp.fromDate(olderThanOrEqual));
        }
        if (newerThan != null) {
          query = query.where('oldestUnpaidDebtDate', isGreaterThan: Timestamp.fromDate(newerThan));
        }
        query = query
            .orderBy('oldestUnpaidDebtDate')
            .orderBy(FieldPath.documentId);
      } else {
        query = query
            .where('balance', isGreaterThan: 0)
            .orderBy('balance', descending: true)
            .orderBy(FieldPath.documentId, descending: true);
      }
    }

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return CursorPage(
      items: snapshot.docs.map((d) => Client.fromMap(d.id, d.data())).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= pageSize,
    );
  }

  /// Facility-wide totals for the Debtors metrics row - real Firestore
  /// aggregate queries, so these reflect every debtor, not just
  /// whichever page the list has loaded so far.
  Future<({int totalDebtors, double totalOwed, int overdueDebtors})> fetchDebtorsMetrics(
      String facilityId, {required int overdueDays}) async {
    final clientsRef = _firestore.collection('facilities').doc(facilityId).collection('clients');
    final debtorsQuery = clientsRef.where('balance', isGreaterThan: 0);

    final countAgg = await debtorsQuery.count().get();
    final sumAgg = await debtorsQuery.aggregate(sum('balance')).get();
    final overdueAgg = await clientsRef
        .where('oldestUnpaidDebtDate',
            isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(Duration(days: overdueDays))))
        .count()
        .get();

    return (
      totalDebtors: countAgg.count ?? 0,
      totalOwed: (sumAgg.getSum('balance') ?? 0).toDouble(),
      overdueDebtors: overdueAgg.count ?? 0,
    );
  }

  // ==================== WRITE / MUTATE ====================

  /// Add a new client (fully supports all fields from AddClientScreen)
  Future<String> addClient(
    String facilityId, {
    required String name,
    required String phone,
    required String address,
    List<String> types = const ['Farmer'],
    String? farmerSubType,
    List<String>? crops,
    List<String>? animalSpecies,
    String? businessName,
    String? vetPracticeType,
    String? notes,
  }) async {
    final clientsCollection = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients');

    final docRef = await clientsCollection.add({
      'name': name,
      'nameLower': name.toLowerCase(),
      'phone': phone,
      'address': address,
      'balance': 0.0,
      'types': types,
      // Legacy single field kept for anything outside this app that
      // might still read it - best-effort, first selected type.
      'type': types.isNotEmpty ? types.first : '',
      'farmerSubType': farmerSubType,
      'crops': crops ?? [],
      'animalSpecies': animalSpecies ?? [],
      'businessName': businessName,
      'vetPracticeType': vetPracticeType,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Update client document
  Future<void> updateClient(String facilityId, Client client) async {
    final docRef = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .doc(client.id);

    await docRef.update(client.toMap());
  }

  /// Delete a client
  Future<void> deleteClient(String facilityId, String clientId) async {
    final docRef = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .doc(clientId);

    await docRef.delete();
  }

  @override
  void dispose() {
    _clientsSubscription?.cancel();
    super.dispose();
  }
}
