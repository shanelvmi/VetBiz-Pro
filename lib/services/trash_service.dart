import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/activity_type.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../models/restore_outcome.dart';
import '../providers/sale_provider.dart';
import '../providers/service_provider.dart';
import '../utils/activity_logger.dart';

/// Putting something back from Trash.
///
/// Moved out of the Trash screen unchanged (Phase 2, step 2D-0) so the same
/// restore serves both the Trash screen and the Undo on a delete message,
/// instead of a second copy. Throws if the restore fails; the caller tells
/// the user.
///
/// Sales and services go to SaleProvider.restoreSale and
/// ServiceProvider.restoreService (E2, docs/design/delete_restore.md): one
/// transaction that also takes the stock again and re-creates the debt, the
/// balance and a service's expense, or refuses with a
/// [RestoreRefusedException] and writes nothing. Products, clients and
/// transactions move back as before. [firestore] and [currentUserInfo] are
/// for tests; the app uses the defaults.
class TrashService {
  TrashService._();

  /// Moves [id] from [trashCollection] back to [liveCollection] in one batch
  /// (the trash-only fields deletedAt and deletedBy are dropped), then logs
  /// "Restored (the item's name)" in the activity log. [data] is the trash document's
  /// data.
  static Future<RestoreResult> restore({
    required String facilityId,
    required String trashCollection,
    required String liveCollection,
    required String id,
    required Map<String, dynamic> data,
    FirebaseFirestore? firestore,
    Future<Map<String, String>> Function()? currentUserInfo,
  }) async {
    firestore ??= FirebaseFirestore.instance;
    if (liveCollection == Collections.sales) {
      final provider = SaleProvider(firestore: firestore, currentUserInfo: currentUserInfo);
      try {
        return await provider.restoreSale(id, facilityId);
      } finally {
        provider.dispose();
      }
    }
    if (liveCollection == Collections.services) {
      final provider = ServiceProvider(firestore: firestore, currentUserInfo: currentUserInfo);
      try {
        return await provider.restoreService(id, facilityId);
      } finally {
        provider.dispose();
      }
    }

    final restoredData = Map<String, dynamic>.from(data)
      ..remove('deletedAt')
      ..remove('deletedBy');

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
    await _logRestore(facilityId, liveCollection, data);
    return RestoreResult.restored;
  }

  /// [restore], for a caller that only knows the id (the Undo on a delete
  /// message): reads the trash document first. Throws a StateError if it is
  /// no longer in Trash (already restored, or deleted for good); a sale or a
  /// service already back returns [RestoreResult.alreadyRestored] instead.
  static Future<RestoreResult> restoreById({
    required String facilityId,
    required String trashCollection,
    required String liveCollection,
    required String id,
    FirebaseFirestore? firestore,
    Future<Map<String, String>> Function()? currentUserInfo,
  }) async {
    final fs = firestore ?? FirebaseFirestore.instance;
    final isSaleOrService = liveCollection == Collections.sales || liveCollection == Collections.services;
    final snap = isSaleOrService
        ? null
        : await fs.collection(Collections.facilities).doc(facilityId).collection(trashCollection).doc(id).get();
    final data = isSaleOrService ? const <String, dynamic>{} : snap!.data();
    if (data == null) throw StateError('$trashCollection/$id is no longer in Trash');
    return restore(
      facilityId: facilityId,
      trashCollection: trashCollection,
      liveCollection: liveCollection,
      id: id,
      data: data,
      firestore: fs,
      currentUserInfo: currentUserInfo,
    );
  }

  static Future<void> _logRestore(String facilityId, String liveCollection, Map<String, dynamic> data) async {
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
