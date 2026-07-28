import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogger {
  /// Logs an activity to the 'activity_logs' subcollection under a facility in Firestore
  /// Automatically fetches the user's fullName from Firestore if userName is null
  static Future<void> logActivity({
    required String facilityId,
    required String userId,
    String? userName, // optional, will fetch from Firestore if null
    required String actionType,
    required String description,
  }) async {
    try {
      // Fetch fullName from Firestore if userName not provided
      if (userName == null || userName.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        userName = userDoc.exists
            ? (userDoc.data()?['fullName'] ?? 'Unknown')
            : 'Unknown';
      }

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .add({
        'userId': userId,
        'userName': userName,
        'actionType': actionType,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Activity logged: $actionType by $userName in facility $facilityId');
    } catch (e) {
      print('❌ Failed to log activity: $e');
    }
  }

  /// Helper to get current FirebaseAuth userId and fullName
  static Future<Map<String, String>> getCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'userId': '', 'userName': 'Unknown'};

    String userName = 'Unknown';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      userName = doc.exists ? (doc.data()?['fullName'] ?? user.email ?? 'Unknown') : user.email ?? 'Unknown';
    } catch (_) {}

    return {'userId': user.uid, 'userName': userName};
  }
}
