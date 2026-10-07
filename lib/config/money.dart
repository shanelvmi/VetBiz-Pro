import 'package:intl/intl.dart';

import 'app_defaults.dart';

/// Formats amounts of money, the same way everywhere.
///
/// Three shapes exist in the app today, and each is kept exactly (Phase 2
/// rule 5), so moving a screen onto these changes nothing it shows:
/// - [format]: `NumberFormat.currency(locale: 'en_US', symbol: 'Tsh ',
///   decimalDigits: 0)` -> "Tsh 12,500" (rounded to whole shillings)
/// - [plain]: `NumberFormat('#,##0', 'en_US')` -> "12,500" (rounded)
/// - [decimal]: `NumberFormat.decimalPattern()` -> "12,500.5" (keeps up to
///   three decimals). Used by the reports, PDFs and dashboard figures.
class Money {
  Money._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppDefaults.numberLocale,
    symbol: '${AppDefaults.currencySymbol} ',
    decimalDigits: 0,
  );
  static final NumberFormat _plain = NumberFormat('#,##0', AppDefaults.numberLocale);
  static final NumberFormat _decimal = NumberFormat.decimalPattern(AppDefaults.numberLocale);

  /// "Tsh 12,500".
  static String format(num amount) => _currency.format(amount);

  /// "12,500".
  static String plain(num amount) => _plain.format(amount);

  /// "12,500" or "12,500.5": grouping, and up to three decimals when present.
  static String decimal(num amount) => _decimal.format(amount);
}
