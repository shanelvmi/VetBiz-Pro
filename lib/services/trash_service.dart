import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/activity_type.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../utils/activity_logger.dart';

/// Putting something back from Trash.
///
/// Moved out of the Trash screen unchanged (Phase 2, step 2D-0) so the same
/// restore serves both the Trash screen and the Undo on a delete message,
/// instead of a second copy. Throws if the restore fails; the caller tells
/// the user.
class TrashService {
  TrashService._();

  /// Moves [id] from [trashCollection] back to [liveCollection] in one batch
  /// (the trash-only fields deletedAt and deletedBy are dropped), then logs
  /// "Restored (the item's name)" in the activity log. [data] is the trash document's
  /// data.
  static Future<void> restore({
    required String facilityId,
    required String trashCollection,
    required String liveCollection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final restoredData = Map<String, dynamic>.from(data)
      ..remove('deletedAt')
      ..remove('deletedBy');

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    batch.set(
      firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(liveCollection)
          .doc(id),
      restoredData,
    );
    batch.delete(
      firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(trashCollection)
          .doc(id),
    );

    await batch.commit();

    final userInfo = await ActivityLogger.getCurrentUserInfo();
    await ActivityLogger.logActivity(
      facilityId: facilityId,
      userId: userInfo[Fields.userId]!,
      userName: userInfo['userName'],
      actionType: ActivityType.trash.key,
      description: 'Restored ${data['name'] ?? data['clientName'] ?? liveCollection}',
    );
  }
}
