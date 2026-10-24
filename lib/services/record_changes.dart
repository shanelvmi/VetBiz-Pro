import 'dart:async';

/// One delete to Trash, or restore from it, that succeeded: the facility and
/// the live collection it changed (Collections.sales, ...).
typedef RecordChange = ({String facilityId, String collection});

/// Tells every provider that keeps a list when a record went to Trash or
/// came back (BUG-1). The live listeners follow on their own, but the list
/// pages (the cursor lists, the Payments ledger, the older pages behind a
/// live window) are fetched once and kept for the session, so a restored
/// sale stayed missing from the Sales list until the next sign-in.
///
/// Sent by the code that deletes and restores (RecordTrash, ClientProvider,
/// TrashService, ProductProvider, TransactionProvider), so every way in is
/// covered: a delete, the Trash screen, and the Undo on a delete message,
/// even after the screen that offered it is gone. Each provider starts its
/// own lists over; no screen has to.
class RecordChanges {
  RecordChanges._();

  static final _changes = StreamController<RecordChange>.broadcast();

  /// Says that [collection] changed in [facilityId].
  static void changed(String facilityId, String collection) =>
      _changes.add((facilityId: facilityId, collection: collection));

  /// Calls [onChange] with the facility after each change to one of
  /// [collections]. The caller cancels the subscription when it is disposed.
  static StreamSubscription<RecordChange> listen(Set<String> collections, void Function(String facilityId) onChange) =>
      _changes.stream.where((c) => collections.contains(c.collection)).listen((c) => onChange(c.facilityId));
}
