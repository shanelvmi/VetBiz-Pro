import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_rules.dart';
import '../../config/money.dart';
import '../../data/activity_type.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../l10n/l10n.dart';
import '../../services/trash_service.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../ui/feedback/restore_feedback.dart';
import '../../utils/activity_logger.dart';

/// PH8a: what Trash does with a deleted record, the same on every width (the
/// tabs on wider windows, the one list on a phone). Moved from the tabs'
/// list unchanged.

/// One kind of deleted record: its Trash and live collections, the icon
/// and the tab label it is shown with, and how its title is built when it
/// has no name.
class TrashKind {
  final String trashCollection;
  final String liveCollection;
  final IconData icon;
  final String Function(AppLocalizations l) label;
  final String Function(Map<String, dynamic> data)? titleBuilder;

  const TrashKind(this.trashCollection, this.liveCollection, this.icon, this.label, {this.titleBuilder});

  /// The title: also in the saved activity description ("Permanently
  /// deleted: ..."), so it stays English.
  String titleOf(Map<String, dynamic> data) =>
      titleBuilder != null ? titleBuilder!(data) : (data['name'] as String?) ?? 'Untitled';
}

String _saleTitle(Map<String, dynamic> data) {
  final client = (data['clientName'] as String?) ?? 'Walk-in';
  final amount = (data['totalAmount'] as num?) ?? 0;
  return 'Sale - $client - ${Money.format(amount)}';
}

String _transactionTitle(Map<String, dynamic> data) {
  final description = (data['description'] as String?) ?? '';
  final type = (data['type'] as String?) ?? '';
  final amount = (data['amount'] as num?) ?? 0;
  final label = description.isNotEmpty ? description : (type.isNotEmpty ? type : 'Transaction');
  return '$label - ${Money.format(amount)}';
}

/// The five kinds, in the tabs' order.
final List<TrashKind> trashKinds = [
  TrashKind(Collections.trashProducts, Collections.products, AppIcons.products.outlined, (l) => l.activityType_products),
  TrashKind(Collections.trashClients, Collections.clients, AppIcons.clients.outlined, (l) => l.clients_title),
  TrashKind(Collections.trashServices, Collections.services, AppIcons.services.outlined, (l) => l.common_serviceRecords),
  TrashKind(Collections.trashSales, Collections.sales, AppIcons.sales.outlined, (l) => l.payments_typeSales,
      titleBuilder: _saleTitle),
  TrashKind(Collections.trashTransactions, Collections.transactions, AppIcons.transactions.outlined,
      (l) => l.transactions_title,
      titleBuilder: _transactionTitle),
];

/// Items within this many days of auto-purge trigger the warning banner.
const int trashWarningThresholdDays = 7;

int? trashDaysRemaining(DateTime? deletedAt) {
  if (deletedAt == null) return null;
  final purgeDate = deletedAt.add(AppRules.trashRetention);
  return purgeDate.difference(DateTime.now()).inDays;
}

/// When the record leaves Trash for good, and in which colour to say it
/// ('' when the record has no deletion date).
(String, Color) trashExpiry(BuildContext context, DateTime? deletedAt) {
  final remaining = trashDaysRemaining(deletedAt);
  final colors = context.colors;
  if (remaining == null) return ('', colors.textMuted);
  if (remaining <= 0) return (context.l10n.trash_deletingSoon, colors.dangerAccent);
  if (remaining == 1) return (context.l10n.trash_expiresTomorrow, colors.dangerAccent);
  if (remaining <= trashWarningThresholdDays) return (context.l10n.trash_expiresIn(remaining), colors.warningStrong);
  return (context.l10n.trash_expiresIn(remaining), colors.textMuted);
}

/// Restores a record; true when it is back. Sales and services restore with
/// their stock, debt and balance (E2, delete_restore.md), so no warning
/// first; a refusal says why. The lists that show the record (Sales,
/// Services, Clients, ...) start over on their own (RecordChanges, BUG-1).
Future<bool> restoreTrashed({
  required FirebaseFirestore firestore,
  required Future<Map<String, String>> Function() currentUserInfo,
  required String facilityId,
  required TrashKind kind,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final record = kind.liveCollection == Collections.sales
      ? TrashedRecord.sale
      : kind.liveCollection == Collections.services
          ? TrashedRecord.service
          : null;
  try {
    final result = await TrashService.restore(
      facilityId: facilityId,
      trashCollection: kind.trashCollection,
      liveCollection: kind.liveCollection,
      id: id,
      data: data,
      firestore: firestore,
      currentUserInfo: currentUserInfo,
    );

    if (record != null) {
      RestoreFeedback.restored(record, result);
    } else {
      AppFeedback.success(L10n.current.trash_restored);
    }
    // Every result is a record back in its list (a refusal throws).
    return true;
  } catch (e, st) {
    if (record != null) {
      RestoreFeedback.failed(record, e, st);
    } else {
      AppFeedback.error(L10n.current.trash_restoreFailed, error: e, stackTrace: st);
    }
    return false;
  }
}

/// Deletes a record for good after today's question; true when it is gone.
Future<bool> deleteTrashedForever(
  BuildContext context, {
  required FirebaseFirestore firestore,
  required Future<Map<String, String>> Function() currentUserInfo,
  required String facilityId,
  required String trashCollection,
  required String id,
  required String label,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.trash_deleteForeverTitle),
      content: Text(context.l10n.trash_deleteForeverBody(label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.common_cancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.trash_deleteForever, style: TextStyle(color: context.colors.danger)),
        ),
      ],
    ),
  );

  if (confirm != true) return false;

  try {
    // A trashed product's batches subcollection is never touched when
    // it was trashed (Firestore doesn't cascade-delete subcollections)
    // - it just sits there, dangling, at the same path. Restoring the
    // product later reconnects to it automatically, which is fine -
    // but permanently deleting it needs to clean this up explicitly,
    // or it's orphaned in Firestore forever with nothing left pointing
    // to it.
    if (trashCollection == Collections.trashProducts) {
      final batchesSnap = await firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.products)
          .doc(id)
          .collection(Collections.batches)
          .get();
      for (final batchDoc in batchesSnap.docs) {
        await batchDoc.reference.delete();
      }
    }

    await firestore
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(trashCollection)
        .doc(id)
        .delete();

    final userInfo = await currentUserInfo();
    await ActivityLogger.logActivity(
      firestore: firestore,
      facilityId: facilityId,
      userId: userInfo[Fields.userId]!,
      userName: userInfo['userName'],
      actionType: ActivityType.trash.key,
      description: 'Permanently deleted: $label',
    );

    // A hard delete: plain success, no Undo (PHASE2_FEEDBACK_SPEC section 8).
    AppFeedback.success(L10n.current.trash_deleted);
    return true;
  } catch (e, st) {
    AppFeedback.error(L10n.current.trash_deleteFailed, error: e, stackTrace: st);
    return false;
  }
}
