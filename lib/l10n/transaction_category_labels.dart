import 'app_localizations.dart';
import 'stored_labels.dart';

/// Labels for the categories saved on a transaction (kExpenseCategoryGroups
/// and kIncomeCategories share the one `category` field) and for the expense
/// picker's headings. See StoredLabelTable: only the display is translated,
/// and an unknown or older category is shown as stored.
class TransactionCategoryLabels {
  TransactionCategoryLabels._();

  /// Expense categories in their groups' order, then income categories.
  static final category = StoredLabelTable({
    'Meals & Refreshments': (l) => l.expenseCategory_mealsRefreshments,
    'Salaries & Wages': (l) => l.expenseCategory_salariesWages,
    'Office Supplies': (l) => l.expenseCategory_officeSupplies,
    'Electricity': (l) => l.expenseCategory_electricity,
    'Water': (l) => l.expenseCategory_water,
    'Rent': (l) => l.expenseCategory_rent,
    'Drugs & Medicines': (l) => l.expenseCategory_drugsMedicines,
    'Vaccines': (l) => l.productCategory_vaccines,
    'Veterinary Supplies': (l) => l.expenseCategory_veterinarySupplies,
    'Fuel': (l) => l.expenseCategory_fuel,
    'Vehicle Maintenance': (l) => l.expenseCategory_vehicleMaintenance,
    'Marketing': (l) => l.expenseCategory_marketing,
    'Licences & Registration': (l) => l.expenseCategory_licencesRegistration,
    'Miscellaneous': (l) => l.productCategory_miscellaneous,
    'Commission Income': (l) => l.incomeCategory_commission,
    'Delivery Income': (l) => l.incomeCategory_delivery,
    'Training Income': (l) => l.incomeCategory_training,
    'Consultancy Income': (l) => l.incomeCategory_consultancy,
    'Rental Income': (l) => l.incomeCategory_rental,
    'Interest Income': (l) => l.incomeCategory_interest,
    'Refunds Received': (l) => l.incomeCategory_refundsReceived,
    'Discounts Received': (l) => l.incomeCategory_discountsReceived,
    'Asset Disposal Income': (l) => l.incomeCategory_assetDisposal,
    'Other Income': (l) => l.incomeCategory_other,
  });

  /// The expense picker's headings (kExpenseCategoryGroups keys); not stored.
  static final expenseGroup = StoredLabelTable({
    'Administration': (l) => l.expenseGroup_administration,
    'Premises & Utilities': (l) => l.expenseGroup_premisesUtilities,
    'Operations': (l) => l.expenseGroup_operations,
    'Transport': (l) => l.expenseGroup_transport,
    'Business': (l) => l.expenseGroup_business,
    'Other': (l) => l.expenseGroup_other,
  });
}

extension TransactionCategoryLabelsOf on AppLocalizations {
  String transactionCategoryLabel(String stored) => TransactionCategoryLabels.category.labelOf(this, stored);
  String expenseGroupLabel(String stored) => TransactionCategoryLabels.expenseGroup.labelOf(this, stored);
}
