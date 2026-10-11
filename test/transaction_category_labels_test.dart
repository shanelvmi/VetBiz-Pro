import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/transaction_categories.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';

import 'stored_labels_check.dart';

/// Display lookups for the transaction categories (spec section 6).
void main() {
  test('transaction categories, expense then income', () {
    checkStoredList(
      TransactionCategoryLabels.category,
      [for (final g in kExpenseCategoryGroups.values) ...g, ...kIncomeCategories],
      (l, v) => l.transactionCategoryLabel(v),
    );
  });

  test('expense picker headings', () {
    checkStoredList(TransactionCategoryLabels.expenseGroup, kExpenseCategoryGroups.keys.toList(), (l, v) => l.expenseGroupLabel(v));
  });
}
