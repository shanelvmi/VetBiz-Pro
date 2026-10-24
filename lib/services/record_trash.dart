import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/activity_type.dart';
import '../data/collections.dart';
import '../data/fields.dart';
import '../models/restore_outcome.dart';
import '../providers/product_provider.dart';
import '../utils/activity_logger.dart';
import 'record_changes.dart';

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

  // Fields only a trash copy has; a restore drops them.
  static const _trashFields = ['deletedAt', 'deletedBy', 'stockReturned', 'trashedDebt', 'trashedExpense'];

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
    RecordChanges.changed(facilityId, type.liveCollection);
  }

  /// Puts the record back with every effect its delete reversed: the stock
  /// is taken again (FIFO, new batchAllocations; the stored prices and
  /// profits are kept, so the daily summary gets back exactly what it lost,
  /// on the original day), the debt, the balance and the oldest unpaid date,
  /// and a service's expense.
  ///
  /// Refused, writing nothing and leaving the record in Trash, when a
  /// product is gone, the client is gone, or the stock does not cover a
  /// line: [RestoreRefusedException]. If the record is already back (a
  /// second tap, a retry after a lost answer) it writes nothing and returns
  /// [RestoreResult.alreadyRestored]. Any other error is thrown as it is.
  Future<RestoreResult> restore(String facilityId, String id) async {
    final facilityRef = firestore.collection(Collections.facilities).doc(facilityId);
    final liveRef = facilityRef.collection(type.liveCollection).doc(id);
    final trashRef = facilityRef.collection(type.trashCollection).doc(id);
    final userInfo = await currentUserInfo();

    final preData = (await trashRef.get()).data();
    if (preData == null) {
      if ((await liveRef.get()).exists) return RestoreResult.alreadyRestored;
      throw StateError('${type.trashCollection}/$id is no longer in Trash');
    }
    final lines = _lines(preData);
    final candidateRefs = <String, List<DocumentReference<Map<String, dynamic>>>>{};
    for (final productId in lines.map((l) => l.productId).toSet()) {
      final snap = await facilityRef
          .collection(Collections.products)
          .doc(productId)
          .collection(Collections.batches)
          .where('sellableQty', isGreaterThan: 0)
          .get();
      candidateRefs[productId] =
          (snap.docs.toList()..sort(ProductProvider.compareByExpiry)).map((d) => d.reference).toList();
    }
    final clientId = _clientId(preData);
    final clientRef = clientId == null ? null : facilityRef.collection(Collections.clients).doc(clientId);

    // A refusal or a purge is thrown below, outside the transaction, so it
    // reaches the screen as itself on every platform (as addSale does).
    Object? stop;
    final result = await firestore.runTransaction<RestoreResult?>((transaction) async {
      stop = null;

      // --- Reads ---
      if ((await transaction.get(liveRef)).exists) return RestoreResult.alreadyRestored;
      final data = (await transaction.get(trashRef)).data();
      if (data == null) {
        stop = StateError('${type.trashCollection}/$id is no longer in Trash');
        return null;
      }
      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final batchSnaps = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final productId in candidateRefs.keys) {
        batchSnaps[productId] = [for (final ref in candidateRefs[productId]!) await transaction.get(ref)];
        productSnaps[productId] = await transaction.get(facilityRef.collection(Collections.products).doc(productId));
      }
      final clientSnap = clientRef == null ? null : await transaction.get(clientRef);
      final debtRef = facilityRef.collection(Collections.debts).doc('${type.idPrefix}_$id');

      // --- Refusals (nothing written yet) ---
      final linesNow = _lines(data);
      final needed = <String, int>{};
      for (final line in linesNow) {
        if (!productSnaps[line.productId]!.exists) {
          stop = RestoreRefusedException(RestoreRefusal.productGone, productName: line.name);
          return null;
        }
        needed[line.productId] = (needed[line.productId] ?? 0) + line.quantity;
      }
      if (clientSnap != null && !clientSnap.exists) {
        stop = const RestoreRefusedException(RestoreRefusal.clientGone);
        return null;
      }
      for (final line in linesNow) {
        final batches = batchSnaps[line.productId]!;
        final available = batches.isEmpty
            ? (productSnaps[line.productId]!.data()?['sellableQty'] ?? 0) as int
            : batches.fold<int>(0, (total, b) => total + ((b.data()?['sellableQty'] ?? 0) as int));
        if (needed[line.productId]! > available) {
          stop = RestoreRefusedException(RestoreRefusal.notEnoughStock,
              productName: line.name, needed: needed[line.productId], available: available);
          return null;
        }
      }

      // --- Plan: FIFO, as a new sale or service takes it ---
      final plan = SellableStockPlan();
      final items = [for (final item in (data[type.itemsField] as List? ?? const [])) Map<String, dynamic>.from(item as Map)];
      for (final line in linesNow) {
        items[line.index]['batchAllocations'] = plan.take(
          product: productSnaps[line.productId]!,
          batches: batchSnaps[line.productId]!,
          quantity: line.quantity,
        );
      }

      // --- Writes ---
      final restored = Map<String, dynamic>.from(data)..removeWhere((key, _) => _trashFields.contains(key));
      if (data.containsKey(type.itemsField)) restored[type.itemsField] = items;
      transaction.set(liveRef, {
        ...restored,
        ...type.searchFields(id, restored),
        Fields.updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.delete(trashRef);
      plan.apply(transaction);

      final owed = _owed(data);
      if (clientSnap != null && owed != 0) {
        final update = <String, dynamic>{'balance': FieldValue.increment(owed)};
        if (owed > 0) {
          final trashedDebt = data['trashedDebt'] as Map?;
          final debt = trashedDebt == null
              ? type.newDebt(id, data, owed, clientSnap.data()?['phone'] as String?)
              : Map<String, dynamic>.from(trashedDebt);
          debt['amountOwed'] = owed;
          transaction.set(debtRef, debt);
          final debtDate = debt['timestamp'];
          final oldest = clientSnap.data()?['oldestUnpaidDebtDate'];
          if (debtDate is Timestamp && (oldest is! Timestamp || debtDate.compareTo(oldest) < 0)) {
            update['oldestUnpaidDebtDate'] = debtDate;
          }
        }
        transaction.update(clientRef!, update);
      }

      final recompute = type.recomputedExpense;
      if (recompute != null) {
        final expense = data.containsKey('trashedExpense')
            ? data['trashedExpense'] as Map?
            : recompute(id, restored, userInfo['userName'] ?? 'Unknown');
        if (expense != null) {
          transaction.set(facilityRef.collection(Collections.transactions).doc('${type.idPrefix}_$id'),
              Map<String, dynamic>.from(expense));
        }
      }

      final deletedAt = data['deletedAt'];
      ActivityLogger.logActivityIn(
        transaction,
        facilityRef
            .collection(Collections.activityLogs)
            .doc('restore_${type.idPrefix}_${id}_${deletedAt is Timestamp ? deletedAt.millisecondsSinceEpoch : 0}'),
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'] ?? 'Unknown',
        actionType: ActivityType.trash.key,
        description: 'Restored ${data['name'] ?? data['clientName'] ?? type.liveCollection}',
      );

      return data['stockReturned'] == true ? RestoreResult.restored : RestoreResult.restoredFromOldCopy;
    });

    if (result == null) throw stop!;
    RecordChanges.changed(facilityId, type.liveCollection);
    return result;
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
