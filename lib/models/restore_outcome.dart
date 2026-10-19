/// What restoring a sale or a service from Trash did
/// (SaleProvider.restoreSale, ServiceProvider.restoreService).
enum RestoreResult {
  /// Restored with every effect its delete had reversed.
  restored,

  /// Restored, from a trash copy written before the update (no
  /// `stockReturned`): its delete may not have put the stock back, so the
  /// screen asks the person to check the stock (owner condition 5).
  restoredFromOldCopy,

  /// It was already back (a second tap, or a retry after a lost answer);
  /// nothing was written.
  alreadyRestored,
}

/// Why a restore was refused (docs/design/delete_restore.md, owner
/// conditions 1, 2 and 4).
enum RestoreRefusal { notEnoughStock, clientGone, productGone }

/// A restore was refused before anything was written; the record stays in
/// Trash. [productName] is the name on the record's line, for
/// [RestoreRefusal.notEnoughStock] and [RestoreRefusal.productGone];
/// [needed] and [available] are for [RestoreRefusal.notEnoughStock].
class RestoreRefusedException implements Exception {
  final RestoreRefusal reason;
  final String? productName;
  final int? needed;
  final int? available;

  const RestoreRefusedException(this.reason, {this.productName, this.needed, this.available});

  @override
  String toString() => 'RestoreRefusedException(${reason.name}, $productName, $needed, $available)';
}
