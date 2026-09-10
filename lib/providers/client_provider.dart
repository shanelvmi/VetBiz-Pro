import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../utils/paginated_stream_loader.dart';

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
