import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/collections.dart';
import '../data/fields.dart';

class ActivityLogger {
  /// Logs an activity to the 'activity_logs' subcollection under a facility in Firestore
  /// Automatically fetches the user's fullName from Firestore if userName is null
  static Future<void> logActivity({
    required String facilityId,
    required String userId,
    String? userName, // optional, will fetch from Firestore if null
    required String actionType,
    required String description,
    // Who the entry is ABOUT, when that isn't the person doing it - an admin
    // approving, rejecting or deactivating someone, a role being changed. It
    // is what lets that person see "I was approved" while everyone else's
    // admin matters stay out of their view: an assistant reads only entries
    // they did (userId) or that are about them (this).
    String? targetUserId,
  }) async {
    try {
      // Fetch fullName from Firestore if userName not provided
      if (userName == null || userName.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection(Collections.users)
            .doc(userId)
            .get();
        userName = userDoc.exists
            ? (userDoc.data()?['fullName'] ?? 'Unknown')
            : 'Unknown';
      }

      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.activityLogs)
          .add({
        Fields.userId: userId,
        'userName': userName,
        'actionType': actionType,
        'description': description,
        if (targetUserId != null && targetUserId.isNotEmpty) 'targetUserId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Activity logged: $actionType by $userName in facility $facilityId');
    } catch (e) {
      debugPrint('❌ Failed to log activity: $e');
    }
  }

  /// Helper to get current FirebaseAuth userId and fullName
  static Future<Map<String, String>> getCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {Fields.userId: '', 'userName': 'Unknown'};

    String userName = 'Unknown';
    try {
      final doc = await FirebaseFirestore.instance
          .collection(Collections.users)
          .doc(user.uid)
          .get();
      userName = doc.exists ? (doc.data()?['fullName'] ?? user.email ?? 'Unknown') : user.email ?? 'Unknown';
    } catch (_) {}

    return {Fields.userId: user.uid, 'userName': userName};
  }
}
