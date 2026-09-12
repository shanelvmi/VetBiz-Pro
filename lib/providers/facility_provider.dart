import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FacilityProvider with ChangeNotifier {
  String? _facilityId;
  String? _facilityName;
  String? _facilityType;
  String? _logoUrl;
  String? _facilityEmail;
  String? _facilityPhone;
  // Per-day closing times (weekday/Saturday/Sunday), each with its own
  // "closed all day" flag, plus a standing admin override to allow
  // report generation at any time regardless of the schedule below -
  // see isReportGenerationAllowedNow().
  Map<String, dynamic>? _businessHours;
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
      _facilityEmail = data['email'];
      _facilityPhone = data['phone'];
      _businessHours = data['businessHours'] != null
          ? Map<String, dynamic>.from(data['businessHours'] as Map)
          : null;
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
      if (_facilityEmail != null) {
        await prefs.setString('facilityEmail', _facilityEmail!);
      } else {
        await prefs.remove('facilityEmail');
      }
      if (_facilityPhone != null) {
        await prefs.setString('facilityPhone', _facilityPhone!);
      } else {
        await prefs.remove('facilityPhone');
      }
      if (_businessHours != null) {
        await prefs.setString('facilityBusinessHours', jsonEncode(_businessHours));
      } else {
        await prefs.remove('facilityBusinessHours');
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
    _facilityEmail = null;
    _facilityPhone = null;
    _businessHours = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('facilityId');
    await prefs.remove('facilityName');
    await prefs.remove('facilityType');
    await prefs.remove('facilityLogoUrl');
    await prefs.remove('facilityEmail');
    await prefs.remove('facilityPhone');
    await prefs.remove('facilityBusinessHours');
  }

  // ==================== GETTERS ====================
  String? get selectedFacilityId => _facilityId;
  String? get selectedFacilityName => _facilityName;
  String? get selectedFacilityType => _facilityType;
  String? get facilityEmail => _facilityEmail;
  String? get facilityPhone => _facilityPhone;
  String? get logoUrl => _logoUrl;
  Map<String, dynamic>? get businessHours => _businessHours;

  // Whether report generation should be active right now - the single
  // source of truth the View Reports screen's Generate button reads,
  // so the day-of-week/closing-time logic lives in exactly one place
  // rather than being reimplemented at each call site.
  // Returns today's actual closing DateTime, or null when there's no
  // specific deadline to point to - no schedule configured yet, the
  // standing "allow anytime" override is on, or today is marked
  // closed all day (a closed day has no closing time to count down
  // to, it's simply not available at all).
  DateTime? _todaysClosingDateTime() {
    final hours = _businessHours;
    if (hours == null) return null;
    if (hours['allowAnytime'] == true) return null;

    final now = DateTime.now();
    final String closedKey;
    final String timeKey;
    if (now.weekday == DateTime.saturday) {
      closedKey = 'saturdayClosed';
      timeKey = 'saturdayClosingTime';
    } else if (now.weekday == DateTime.sunday) {
      closedKey = 'sundayClosed';
      timeKey = 'sundayClosingTime';
    } else {
      closedKey = 'weekdayClosed';
      timeKey = 'weekdayClosingTime';
    }

    if (hours[closedKey] == true) return null;

    final closingTimeStr = hours[timeKey] as String?;
    if (closingTimeStr == null) return null;
    final parts = closingTimeStr.split(':');
    if (parts.length != 2) return null;
    final closingHour = int.tryParse(parts[0]);
    final closingMinute = int.tryParse(parts[1]);
    if (closingHour == null || closingMinute == null) return null;

    return DateTime(now.year, now.month, now.day, closingHour, closingMinute);
  }

  bool isReportGenerationAllowedNow() {
    final hours = _businessHours;
    // No schedule configured yet - don't block a brand-new facility
    // from ever using this feature before an admin has visited the
    // new settings screen.
    if (hours == null) return true;
    if (hours['allowAnytime'] == true) return true;

    final now = DateTime.now();
    final String closedKey;
    if (now.weekday == DateTime.saturday) {
      closedKey = 'saturdayClosed';
    } else if (now.weekday == DateTime.sunday) {
      closedKey = 'sundayClosed';
    } else {
      closedKey = 'weekdayClosed';
    }
    // Marked closed all day - the schedule itself never activates the
    // button; only the standing "allow anytime" override (checked
    // above) can open it on a day like this.
    if (hours[closedKey] == true) return false;

    final closingDateTime = _todaysClosingDateTime();
    if (closingDateTime == null) return true;
    return !now.isBefore(closingDateTime);
  }

  /// Today's closing time, for display purposes (e.g. "Available at
  /// 7:00pm") - null when there's nothing specific to show, either
  /// because generation is already allowed right now, or because
  /// today is closed all day with no time to point to.
  DateTime? todaysClosingTime() {
    if (isReportGenerationAllowedNow()) return null;
    return _todaysClosingDateTime();
  }

  /// True specifically when today is marked closed all day (and the
  /// standing override isn't on) - the UI needs to say something
  /// different here than "available at [time]", since there is no
  /// time today it becomes available.
  bool get isClosedAllDayToday {
    final hours = _businessHours;
    if (hours == null) return false;
    if (hours['allowAnytime'] == true) return false;
    final now = DateTime.now();
    final String closedKey;
    if (now.weekday == DateTime.saturday) {
      closedKey = 'saturdayClosed';
    } else if (now.weekday == DateTime.sunday) {
      closedKey = 'sundayClosed';
    } else {
      closedKey = 'weekdayClosed';
    }
    return hours[closedKey] == true;
  }

  Map<String, String?>? get selectedFacility {
    if (_facilityId == null) return null;
    return {
      'id': _facilityId,
      'name': _facilityName,
      'type': _facilityType,
      'logoUrl': _logoUrl,
      'email': _facilityEmail,
      'phone': _facilityPhone,
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
        _facilityEmail = data['email'];
        _facilityPhone = data['phone'];
        _businessHours = data['businessHours'] != null
            ? Map<String, dynamic>.from(data['businessHours'] as Map)
            : null;
        notifyListeners();

        // persist loaded facility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('facilityId', _facilityId!);
        await prefs.setString('facilityName', _facilityName!);
        await prefs.setString('facilityType', _facilityType!);
        if (_logoUrl != null) await prefs.setString('facilityLogoUrl', _logoUrl!);
        if (_facilityEmail != null) await prefs.setString('facilityEmail', _facilityEmail!);
        if (_facilityPhone != null) await prefs.setString('facilityPhone', _facilityPhone!);
        if (_businessHours != null) {
          await prefs.setString('facilityBusinessHours', jsonEncode(_businessHours));
        }
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
      _facilityEmail = prefs.getString('facilityEmail');
      _facilityPhone = prefs.getString('facilityPhone');
      final cachedHours = prefs.getString('facilityBusinessHours');
      if (cachedHours != null) {
        try {
          _businessHours = Map<String, dynamic>.from(jsonDecode(cachedHours) as Map);
        } catch (_) {
          _businessHours = null;
        }
      }
      notifyListeners();
    }
  }
}
