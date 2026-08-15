import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double balance;
  // A client can genuinely be more than one thing at once - a vet who
  // also farms, a retailer who also buys wholesale - so this is a list,
  // not a single exclusive category.
  final List<String> types;
  final String? farmerSubType;
  final List<String> crops;
  final List<String> animalSpecies;
  final String? farmLocation;
  final double? farmSize;
  final String? businessName;
  final String? licenseNumber;
  final String? vetPracticeType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.balance = 0.0,
    List<String>? types,
    this.farmerSubType,
    List<String>? crops,
    List<String>? animalSpecies,
    this.farmLocation,
    this.farmSize,
    this.businessName,
    this.licenseNumber,
    this.vetPracticeType,
    this.createdAt,
    this.updatedAt,
  })  : types = types ?? [],
        crops = crops ?? [],
        animalSpecies = animalSpecies ?? [];

  factory Client.fromMap(String id, Map<String, dynamic> data) {
    // New documents store 'types' as a list. Older documents only have
    // the legacy single 'type' string - read-time migration wraps that
    // into a single-item list automatically, so every existing client
    // keeps working the moment this ships, with no separate batch
    // migration needed. The next time that client is edited and saved,
    // it's written back in the new format via toMap() below.
    List<String> resolvedTypes;
    if (data['types'] != null) {
      resolvedTypes = List<String>.from(data['types']);
    } else if (data['type'] != null && (data['type'] as String).isNotEmpty) {
      resolvedTypes = [data['type'] as String];
    } else {
      resolvedTypes = [];
    }

    return Client(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      balance: (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0,
      types: resolvedTypes,
      farmerSubType: data['farmerSubType'],
      crops: data['crops'] != null ? List<String>.from(data['crops']) : [],
      animalSpecies: data['animalSpecies'] != null ? List<String>.from(data['animalSpecies']) : [],
      farmLocation: data['farmLocation'],
      farmSize: data['farmSize'] != null ? (data['farmSize'] as num).toDouble() : null,
      businessName: data['businessName'],
      licenseNumber: data['licenseNumber'],
      vetPracticeType: data['vetPracticeType'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // Stored purely so Firestore can do a case-insensitive prefix
      // search server-side - queries can't call toLowerCase() on the
      // fly, so this needs to physically exist as its own field.
      'nameLower': name.toLowerCase(),
      'phone': phone,
      'address': address,
      'balance': balance,
      'types': types,
      // Also kept in the legacy single-string field, best-effort (first
      // selected type) - in case anything outside this codebase (an
      // export, a report not covered by this project) still reads it.
      // Everything checked in this app itself reads 'types' now.
      'type': types.isNotEmpty ? types.first : '',
      'farmerSubType': farmerSubType,
      'crops': crops,
      'animalSpecies': animalSpecies,
      'farmLocation': farmLocation,
      'farmSize': farmSize,
      'businessName': businessName,
      'licenseNumber': licenseNumber,
      'vetPracticeType': vetPracticeType,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // ✅ Add copyWith for safe editing
  Client copyWith({
    String? name,
    String? phone,
    String? address,
    double? balance,
    List<String>? types,
    String? farmerSubType,
    List<String>? crops,
    List<String>? animalSpecies,
    String? farmLocation,
    double? farmSize,
    String? businessName,
    String? licenseNumber,
    String? vetPracticeType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      types: types ?? this.types,
      farmerSubType: farmerSubType ?? this.farmerSubType,
      crops: crops ?? this.crops,
      animalSpecies: animalSpecies ?? this.animalSpecies,
      farmLocation: farmLocation ?? this.farmLocation,
      farmSize: farmSize ?? this.farmSize,
      businessName: businessName ?? this.businessName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vetPracticeType: vetPracticeType ?? this.vetPracticeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
