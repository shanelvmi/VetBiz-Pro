import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';

class ClientProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Client> _clients = [];
  List<Client> get clients => [..._clients];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clientsSubscription;

  /// Real-time listening to clients for a facility
  void listenToClients(String facilityId) {
    debugPrint('ClientProvider.listenToClients called with facilityId: $facilityId');
    _clientsSubscription?.cancel();
    if (facilityId.isEmpty) return;

    final collection = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients');

    _clientsSubscription = collection.snapshots().listen((snapshot) {
      _clients = snapshot.docs
          .map((doc) => Client.fromMap(doc.id, doc.data()))
          .toList();

      debugPrint('ClientProvider: loaded ${_clients.length} clients');
      notifyListeners();
    }, onError: (error) {
      debugPrint('Client listen error: $error');
    });
  }

  /// Clear all clients
  void clear() {
    _clients.clear();
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

      debugPrint('ClientProvider snapshot length: ${_clients.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
    }
  }

  /// Add a new client (fully supports all fields from AddClientScreen)
  Future<String> addClient(
    String facilityId, {
    required String name,
    required String phone,
    required String address,
    String type = 'Farmer',
    String? farmerSubType,
    List<String>? crops,
    List<String>? animalSpecies,
    String? businessName,
    String? vetPracticeType,
  }) async {
    final clientsCollection = _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('clients');

    final docRef = await clientsCollection.add({
      'name': name,
      'phone': phone,
      'address': address,
      'balance': 0.0,
      'type': type,
      'farmerSubType': farmerSubType,
      'crops': crops ?? [],
      'animalSpecies': animalSpecies ?? [],
      'businessName': businessName,
      'vetPracticeType': vetPracticeType,
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

  /// Get client by ID
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

  @override
  void dispose() {
    _clientsSubscription?.cancel();
    super.dispose();
  }
}
