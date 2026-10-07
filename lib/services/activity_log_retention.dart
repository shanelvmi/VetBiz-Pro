import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/collections.dart';

/// Removes activity logs that have aged out of a facility's "keep logs for
/// N days" setting.
///
/// One implementation, shared by the Activity Log screen and the View
/// Facilities settings. They each used to have their own copy, and both had
/// the same two faults: they deleted at most 500 logs in a single batch no
/// matter how many were due, and they swallowed every error - so when the
/// security rules refused the delete, the setting still reported "Logs will
/// now be kept for 30 days" while nothing was removed.
class ActivityLogRetention {
  ActivityLogRetention._();

  /// A log older than this is outside the window.
  static DateTime cutoffFor(int retentionDays) =>
      DateTime.now().subtract(Duration(days: retentionDays));

  /// Deletes every log older than the retention window and returns how many
  /// were removed. Works through the backlog 500 at a time (Firestore's batch
  /// limit) rather than stopping after the first batch.
  ///
  /// THROWS if a delete fails - for example, when the security rules don't
  /// allow it - so the caller can tell the user instead of claiming success.
  /// [maxRounds] only guards against a runaway loop (60 x 500 = 30,000 logs);
  /// anything left over is picked up the next time this runs.
  static Future<int> deleteExpired(String facilityId, int retentionDays, {int maxRounds = 60}) async {
    final firestore = FirebaseFirestore.instance;
    final logs = firestore.collection(Collections.facilities).doc(facilityId).collection(Collections.activityLogs);
    final cutoff = Timestamp.fromDate(cutoffFor(retentionDays));

    var deleted = 0;
    for (var round = 0; round < maxRounds; round++) {
      final snap = await logs.where('timestamp', isLessThan: cutoff).limit(500).get();
      if (snap.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;

      if (snap.docs.length < 500) break;
    }
    return deleted;
  }

  /// A short, plain-English reason for a failed delete, for a snackbar.
  static String explainFailure(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return "the security rules don't currently allow deleting logs";
    }
    return '$error';
  }
}
