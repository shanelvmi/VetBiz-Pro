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

  /// Written by the add-sale screen; sale_provider writes [sales]. Two
  /// spellings for the same kind of entry, both already stored, so both are
  /// kept. See design-open-questions.md.
  sale('Sale'),
  services('Services'),
  transactions('Transactions'),
  trash('Trash'),
  reportDraftDeleted('Report Draft Deleted');

  const ActivityType(this.key);

  final String key;
}
