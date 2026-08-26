import 'package:cloud_firestore/cloud_firestore.dart';

/// Assigns the next receipt number for [facilityId] - one shared,
/// sequential numbering across both sales and services, since they're
/// both "receipts" from the same business, and a business owner
/// expects one continuous sequence for their own records, not two
/// separate #1s that could be confused with each other during
/// reconciliation or an audit.
///
/// Uses an isolated Firestore transaction scoped to just this counter
/// document, rather than wrapping the entire sale/service save in one
/// transaction - the surrounding save logic (FIFO stock deduction
/// across multiple documents, for sales) is already complex enough
/// that folding it into the same transaction would risk breaking it.
/// The number itself is still atomically and uniquely assigned even
/// though this transaction completes on its own, moments before the
/// sale/service document itself is written - the rare worst case if
/// that following write then fails is a small gap in the sequence,
/// not a duplicate number, which is an acceptable trade-off any real
/// receipt numbering system already has to tolerate.
Future<int> nextReceiptNumber(String facilityId) async {
  final firestore = FirebaseFirestore.instance;
  final counterRef = firestore
      .collection('facilities')
      .doc(facilityId)
      .collection('counters')
      .doc('receiptNumber');

  return firestore.runTransaction<int>((transaction) async {
    final snapshot = await transaction.get(counterRef);
    final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
    final next = current + 1;
    transaction.set(counterRef, {'value': next}, SetOptions(merge: true));
    return next;
  });
}
