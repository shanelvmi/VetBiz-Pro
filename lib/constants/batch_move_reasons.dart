// Why a batch is moved back to the Stock Store or taken off Sellable. The
// chosen reason is saved as `reason` on the move record and written into its
// activity entry, so the values never change; what the dialog shows is their
// label. Moved here from move_expired_to_stock_dialog.dart unchanged.

const String kBatchMoveReasonExpired = 'Expired';

/// The one that needs a note.
const String kBatchMoveReasonOther = 'Other (specify)';

const List<String> kBatchMoveReasons = [kBatchMoveReasonExpired, 'Deteriorated', kBatchMoveReasonOther];
