import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FacilityProvider with ChangeNotifier {
  String? _facilityId;
  String? _facilityName;
  String? _facilityType;
  String? _logoUrl;
  StreamSubscription<DocumentSnapshot>? _facilitySub;

  FacilityProvider() {
    _loadFromPrefs(); // auto-load facility on provider init
  }

  // ==================== LIVE LISTENER ====================
  // Keeps name/type/logo in sync automatically with whatever's actually
  // in Firestore - previously this provider was purely a one-time
  // snapshot set at login (via setFacility below), with no way for a
  // change made elsewhere (e.g. updating the logo from Settings) to
  // ever reach it except by logging out and back in. Even then it
  // didn't work, since the login flow itself never passed logoUrl to
  // setFacility in the first place - it only had the denormalized
  // {facilityId, name, type} from the user's own document, which never
  // included the logo at all.
  void listenToFacility(String facilityId) {
    _facilitySub?.cancel();
    _facilitySub = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data()!;
      _facilityId = doc.id;
      _facilityName = data['name'] ?? _facilityName;
      _facilityType = data['type'] ?? _facilityType;
      _logoUrl = data['logoUrl'];
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('facilityId', _facilityId!);
      if (_facilityName != null) await prefs.setString('facilityName', _facilityName!);
      if (_facilityType != null) await prefs.setString('facilityType', _facilityType!);
      if (_logoUrl != null) {
        await prefs.setString('facilityLogoUrl', _logoUrl!);
      } else {
        await prefs.remove('facilityLogoUrl');
      }
    }, onError: (e) {
      debugPrint('FacilityProvider listen error: $e');
    });
  }

  // ==================== SET FACILITY ====================
  Future<void> setFacility({
    required String id,
    required String name,
    required String type,
    String? logoUrl,
  }) async {
    _facilityId = id;
    _facilityName = name;
    _facilityType = type;
    _logoUrl = logoUrl;
    notifyListeners();

    // persist facility
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('facilityId', id);
    await prefs.setString('facilityName', name);
    await prefs.setString('facilityType', type);
    if (logoUrl != null) await prefs.setString('facilityLogoUrl', logoUrl);
  }

  // ==================== CLEAR FACILITY ====================
  Future<void> clearFacility() async {
    _facilitySub?.cancel();
    _facilityId = null;
    _facilityName = null;
    _facilityType = null;
    _logoUrl = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('facilityId');
    await prefs.remove('facilityName');
    await prefs.remove('facilityType');
    await prefs.remove('facilityLogoUrl');
  }

  // ==================== GETTERS ====================
  String? get selectedFacilityId => _facilityId;
  String? get selectedFacilityName => _facilityName;
  String? get selectedFacilityType => _facilityType;
  String? get logoUrl => _logoUrl;

  Map<String, String?>? get selectedFacility {
    if (_facilityId == null) return null;
    return {
      'id': _facilityId,
      'name': _facilityName,
      'type': _facilityType,
      'logoUrl': _logoUrl,
    };
  }

  // ==================== LOAD FACILITY FROM FIRESTORE ====================
  Future<void> loadFacility(String facilityId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .get()
          .timeout(const Duration(seconds: 15));

      if (doc.exists) {
        final data = doc.data()!;
        _facilityId = doc.id;
        _facilityName = data['name'] ?? '';
        _facilityType = data['type'] ?? '';
        _logoUrl = data['logoUrl'];
        notifyListeners();

        // persist loaded facility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('facilityId', _facilityId!);
        await prefs.setString('facilityName', _facilityName!);
        await prefs.setString('facilityType', _facilityType!);
        if (_logoUrl != null) await prefs.setString('facilityLogoUrl', _logoUrl!);
      }
    } catch (e) {
      print('Error loading facility: $e');
    }
  }

  // ==================== LOAD FACILITY FROM SHARED PREFERENCES ====================
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('facilityId');
    if (id != null) {
      _facilityId = id;
      _facilityName = prefs.getString('facilityName');
      _facilityType = prefs.getString('facilityType');
      _logoUrl = prefs.getString('facilityLogoUrl');
      notifyListeners();
    }
  }
}
