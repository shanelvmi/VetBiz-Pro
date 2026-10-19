import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import '../../models/restore_outcome.dart';
import 'app_feedback.dart';

/// A sale or a service, for the messages of a restore from Trash.
enum TrashedRecord { sale, service }

/// What the Trash screen and the Undo on a delete say after restoring a
/// sale or a service (docs/design/delete_restore.md, owner condition 8).
class RestoreFeedback {
  RestoreFeedback._();

  /// "Sale moved to Trash" / "Service moved to Trash" with Undo, after a
  /// delete. Undo runs [restore] (the Trash restore: stock, debt, balance
  /// and a service's expense come back) and says how it went; [onRestored]
  /// runs after a restore, for a screen that is still there to refresh.
  static void offerUndo(TrashedRecord record,
      {required Future<RestoreResult> Function() restore, VoidCallback? onRestored}) {
    final l = L10n.current;
    AppFeedback.undo(
      record == TrashedRecord.sale ? l.sales_movedToTrash : l.services_movedToTrash,
      onUndo: () => _undo(record, restore, onRestored),
    );
  }

  static Future<void> _undo(
      TrashedRecord record, Future<RestoreResult> Function() restore, VoidCallback? onRestored) async {
    try {
      restored(record, await restore());
      onRestored?.call();
    } catch (e, st) {
      failed(record, e, st);
    }
  }

  /// "Sale restored" / "Service restored" with what was updated; a copy
  /// deleted before the update adds the stock check (condition 5).
  static void restored(TrashedRecord record, RestoreResult result) {
    final l = L10n.current;
    final updated = record == TrashedRecord.sale ? l.sales_restoredDetail : l.services_restoredDetail;
    AppFeedback.success(
      record == TrashedRecord.sale ? l.sales_restored : l.services_restored,
      detail: result == RestoreResult.restoredFromOldCopy ? '$updated\n${l.trash_restoredOldCopy}' : updated,
    );
  }

  /// "Can't restore this sale" / "...service": the second line is the
  /// refusal's reason (FriendlyError), or the usual sentence for any other
  /// error.
  static void failed(TrashedRecord record, Object error, StackTrace stackTrace) {
    final l = L10n.current;
    AppFeedback.error(
      record == TrashedRecord.sale ? l.sales_cantRestore : l.services_cantRestore,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
