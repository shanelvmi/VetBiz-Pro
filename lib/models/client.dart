import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double balance; 
  final String type; 
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
    required this.type,
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
  })  : crops = crops ?? [],
        animalSpecies = animalSpecies ?? [];

  factory Client.fromMap(String id, Map<String, dynamic> data) {
    return Client(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      balance: (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0,
      type: data['type'] ?? 'Farmer',
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
      'phone': phone,
      'address': address,
      'balance': balance,
      'type': type,
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
    String? type,
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
      type: type ?? this.type,
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
