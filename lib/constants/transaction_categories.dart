// Transaction categories. The chosen one is saved as `category` on the
// transaction as this English text, so the values and their order never
// change; the expense group names are headings only. What is shown is their
// label (lib/l10n/transaction_category_labels.dart). Moved here from
// add_transaction_screen.dart unchanged.

/// Expense categories, grouped for the picker.
const Map<String, List<String>> kExpenseCategoryGroups = {
  'Administration': ['Meals & Refreshments', 'Salaries & Wages', 'Office Supplies'],
  'Premises & Utilities': ['Electricity', 'Water', 'Rent'],
  'Operations': ['Drugs & Medicines', 'Vaccines', 'Veterinary Supplies'],
  'Transport': ['Fuel', 'Vehicle Maintenance'],
  'Business': ['Marketing', 'Licences & Registration'],
  'Other': ['Miscellaneous'],
};

/// Income categories - flat, no grouping needed for this shorter list.
const List<String> kIncomeCategories = [
  'Commission Income',
  'Delivery Income',
  'Training Income',
  'Consultancy Income',
  'Rental Income',
  'Interest Income',
  'Refunds Received',
  'Discounts Received',
  'Asset Disposal Income',
  'Other Income',
];
