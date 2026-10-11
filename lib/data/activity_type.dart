/// The `actionType` written on an activity-log entry
/// (`ActivityLogger.logActivity(actionType: ...)`). [key] is the stored string
/// and never changes: existing entries were written with it.
///
/// Readers match these case-insensitively (`actionType.toLowerCase()`) and
/// also know older types nothing writes any more, so they keep their own
/// lower-case cases.
enum ActivityType {
  account('Account'),
  debtors('Debtors'),
  products('Products'),
  inventoryMove('Inventory Move'),
  sales('Sales'),

  /// Read only: older sale entries were written as 'Sale' by the add-sale
  /// screen while sale_provider wrote [sales]. Since step 2E everything
  /// writes [sales]; the old spelling stays readable through [canonicalKey].
  sale('Sale'),
  services('Services'),
  transactions('Transactions'),
  trash('Trash'),
  reportDraftDeleted('Report Draft Deleted');

  const ActivityType(this.key);

  final String key;

  /// The type a stored entry is shown, counted and filtered under, so old
  /// 'Sale' entries sit with the 'Sales' ones. Anything else is unchanged.
  static String canonicalKey(String stored) =>
      stored.toLowerCase() == sale.key.toLowerCase() ? sales.key : stored;
}
