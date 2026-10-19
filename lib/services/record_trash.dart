import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/collections.dart';
import '../data/fields.dart';
import '../providers/product_provider.dart';
import '../utils/activity_logger.dart';

/// What differs between a sale and a service for [RecordTrash].
class TrashedRecordType {
  final String liveCollection;
  final String trashCollection;

  /// 'sale' or 'service': the deterministic ids debts/{idPrefix}_{id},
  /// transactions/{idPrefix}_{id} and the activity entries'.
  final String idPrefix;

  /// The debt field that links a debt with an older random id to its record.
  final String debtLinkField;
  final String itemsField;
  final String itemNameField;

  /// Services take one unit per item matched to a product; a sale line takes
  /// its 'quantity'.
  final bool oneUnitPerItem;
  final String actionType;
  final String Function(Map<String, dynamic> data) deletedDescription;
  final Map<String, dynamic> Function(String id, Map<String, dynamic> data) searchFields;

  /// The debt to re-create when the trash copy has no trashedDebt (deleted
  /// by the old code, or its debt was missing).
  final Map<String, dynamic> Function(String id, Map<String, dynamic> data, double owed, String? clientPhone) newDebt;

  /// Services only: the expense to re-create for a trash copy written by the
  /// old delete (no trashedExpense), by E1b's rule; null when nothing was
  /// bought outside. Null for sales, which have no expense.
  final Map<String, dynamic>? Function(String id, Map<String, dynamic> data, String recordedBy)? recomputedExpense;

  const TrashedRecordType({
    required this.liveCollection,
    required this.trashCollection,
    required this.idPrefix,
    required this.debtLinkField,
    required this.itemsField,
    required this.itemNameField,
    required this.oneUnitPerItem,
    required this.actionType,
    required this.deletedDescription,
    required this.searchFields,
    required this.newDebt,
    this.recomputedExpense,
  });
}

/// Deletes a sale or a service to Trash, and restores it, each in ONE
/// transaction (docs/design/delete_restore.md, option a): the record, its
/// stock, its debt, the client's balance and oldest unpaid date, a service's
/// expense, and the activity entry change together or not at all. The
/// upfront payment is never touched: it stays counted while the record is in
/// Trash (owner condition 3).
class RecordTrash {
  final FirebaseFirestore firestore;
  final TrashedRecordType type;
  final Future<Map<String, String>> Function() currentUserInfo;
  final String Function() deletedBy;

  RecordTrash(this.firestore, this.type, {required this.currentUserInfo, required this.deletedBy});

  /// What a trash copy's deletedBy holds: the signed-in user's email (or uid).
  static String signedInUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? user?.uid ?? 'Unknown';
  }

  /// The trash copy keeps everything the restore needs to give back exactly
  /// what the delete took: the record as stored, its debt (so the restored
  /// debt keeps its own date, and the client's oldest unpaid date comes back
  /// the same, owner condition 6), and a service's expense. stockReturned
  /// marks a copy written by this delete, which always returns the stock.
  /// A second delete of a record already gone writes nothing.
  Future<void> delete(String facilityId, String id) async {
    final facilityRef = firestore.collection(Collections.facilities).doc(facilityId);
    final liveRef = facilityRef.collection(type.liveCollection).doc(id);
    final userInfo = await currentUserInfo();

    // Queries cannot run in a transaction, so what they find is read here
    // and re-read inside it.
    final preData = (await liveRef.get()).data();
    if (preData == null) return;
    final debts = facilityRef.collection(Collections.debts);
    final debtRefs = {
      debts.doc('${type.idPrefix}_$id'),
      for (final d in (await debts.where(type.debtLinkField, isEqualTo: id).get()).docs) d.reference,
    }.toList();
    final transactions = facilityRef.collection(Collections.transactions);
    final expenseRefs = type.recomputedExpense == null
        ? <DocumentReference<Map<String, dynamic>>>[]
        : {
            transactions.doc('${type.idPrefix}_$id'),
            for (final d in (await transactions.where('serviceId', isEqualTo: id).get()).docs) d.reference,
          }.toList();
    final clientId = _clientId(preData);
    final clientRef = clientId == null ? null : facilityRef.collection(Collections.clients).doc(clientId);
    // The client's debts, oldest first, for the oldest unpaid date after
    // this record's debt is gone.
    final clientDebts = clientId == null
        ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : (await debts.where('clientId', isEqualTo: clientId).orderBy('timestamp').get()).docs;
    final stock = SellableStockReturn();
    for (final line in _lines(preData)) {
      stock.add(facilityRef.collection(Collections.products).doc(line.productId), line.allocations, line.quantity);
    }
    final logRef = facilityRef
        .collection(Collections.activityLogs)
        .doc('delete_${type.idPrefix}_${id}_${DateTime.now().millisecondsSinceEpoch}');

    await firestore.runTransaction((transaction) async {
      // --- Reads ---
      final data = (await transaction.get(liveRef)).data();
      if (data == null) return; // deleted meanwhile
      final debtSnaps = [for (final ref in debtRefs) await transaction.get(ref)].where((s) => s.exists).toList();
      final expenseSnaps =
          [for (final ref in expenseRefs) await transaction.get(ref)].where((s) => s.exists).toList();
      await stock.read(transaction);
      final clientSnap = clientRef == null ? null : await transaction.get(clientRef);

      // --- Writes ---
      transaction.set(facilityRef.collection(type.trashCollection).doc(id), {
        ...data,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': deletedBy(),
        'stockReturned': true,
        if (debtSnaps.isNotEmpty) 'trashedDebt': debtSnaps.first.data(),
        if (type.recomputedExpense != null) 'trashedExpense': expenseSnaps.isEmpty ? null : expenseSnaps.first.data(),
      });
      transaction.delete(liveRef);
      stock.apply(transaction);
      for (final snap in [...debtSnaps, ...expenseSnaps]) {
        transaction.delete(snap.reference);
      }

      final owed = _owed(data);
      // A client deleted outright (until E3) has no balance to lower: the
      // old code re-created it as a stub with a negative balance.
      if (clientSnap != null && clientSnap.exists && (owed != 0 || debtSnaps.isNotEmpty)) {
        final deletedIds = debtSnaps.map((s) => s.id).toSet();
        final remaining = clientDebts.where((d) => !deletedIds.contains(d.id)).toList();
        final next = remaining.isEmpty ? null : remaining.first.data()['timestamp'];
        transaction.update(clientRef!, {
          if (owed != 0) 'balance': FieldValue.increment(-owed),
          'oldestUnpaidDebtDate': next is Timestamp ? next : null,
        });
      }

      ActivityLogger.logActivityIn(
        transaction,
        logRef,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'] ?? 'Unknown',
        actionType: type.actionType,
        description: type.deletedDescription(data),
      );
    });
  }

  static String? _clientId(Map<String, dynamic> data) {
    final clientId = data['clientId'] as String?;
    return clientId == null || clientId.isEmpty ? null : clientId;
  }

  static double _owed(Map<String, dynamic> data) =>
      ((data['totalAmount'] as num?) ?? 0).toDouble() - ((data['totalPaid'] as num?) ?? 0).toDouble();

  /// The record's lines that came out of stock, with their index in
  /// [TrashedRecordType.itemsField].
  List<_StockLine> _lines(Map<String, dynamic> data) {
    final lines = <_StockLine>[];
    final items = data[type.itemsField] as List? ?? const [];
    for (var i = 0; i < items.length; i++) {
      final item = Map<String, dynamic>.from(items[i] as Map);
      final productId = item['productId'] as String?;
      if (productId == null || productId.isEmpty) continue;
      lines.add(_StockLine(
        index: i,
        productId: productId,
        name: (item[type.itemNameField] as String?) ?? productId,
        quantity: type.oneUnitPerItem ? 1 : ((item['quantity'] as num?) ?? 0).toInt(),
        allocations: [
          for (final a in (item['batchAllocations'] as List? ?? const [])) Map<String, dynamic>.from(a as Map),
        ],
      ));
    }
    return lines;
  }
}

class _StockLine {
  final int index;
  final String productId;
  final String name;
  final int quantity;
  final List<Map<String, dynamic>> allocations;

  const _StockLine({
    required this.index,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.allocations,
  });
}
