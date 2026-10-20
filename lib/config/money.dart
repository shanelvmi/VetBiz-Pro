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

  /// "Tsh 12,500.5": the symbol, a space, then [decimal]. A negative is
  /// "-Tsh 12,500", the same shape as [format] (R3, D2).
  static String symbolDecimal(num amount) =>
      '${amount < 0 ? '-' : ''}${AppDefaults.currencySymbol} ${decimal(amount.abs())}';

  /// The dashboard's breakdown under Net Profit has little room: from a
  /// million it shows "Tsh 10.888M" (three decimals), below that the usual
  /// figure. A negative is "-Tsh 10.888M" (R3, D2).
  static String compactMillions(num amount) {
    if (amount.abs() < 1000000) return symbolDecimal(amount);
    final millions = (amount.abs() / 1000000).toStringAsFixed(3);
    return '${amount < 0 ? '-' : ''}${AppDefaults.currencySymbol} ${millions}M';
  }

  /// The facility card's short form: "Tsh 999", "Tsh 12.5K", "Tsh 1.2M" (one
  /// decimal from a thousand), and "-Tsh 12.5K" for a negative. The card
  /// built this itself, once with "TZS" in front (R3, D1: "Tsh" everywhere).
  static String compact(num amount) {
    final a = amount.abs();
    final digits = a >= 1000000
        ? '${(a / 1000000).toStringAsFixed(1)}M'
        : a >= 1000
            ? '${(a / 1000).toStringAsFixed(1)}K'
            : a.toStringAsFixed(0);
    return '${amount < 0 ? '-' : ''}${AppDefaults.currencySymbol} $digits';
  }

  /// "Tsh 12500": whole shillings with NO thousands separator
  /// (`amount.toStringAsFixed(0)`), as some screens and the thermal printer
  /// receipt show today. Same output as [savedWhole], kept apart because
  /// on-screen text can be changed later and saved text can't
  /// (design-open-questions.md, step 2R).
  static String symbolWhole(num amount) => '${AppDefaults.currencySymbol} ${amount.toStringAsFixed(0)}';

  /// "Tsh 12500" or "Tsh 12500.0": a value read from a document, printed as
  /// Dart prints it (`'Tsh ${data['amount'] ?? 0}'`).
  static String symbolAsStored(Object amount) => '${AppDefaults.currencySymbol} $amount';

  // SAVED text. Activity and transaction descriptions are stored in
  // Firestore, so what they say is history. These keep today's exact output
  // (no thousands separator) on purpose; making saved amounts readable is a
  // refinement decision (design-open-questions.md, step 2R), not a migration.

  /// "Tsh 12500": whole shillings, no thousands separator
  /// (`amount.toStringAsFixed(0)`).
  static String savedWhole(num amount) => '${AppDefaults.currencySymbol} ${amount.toStringAsFixed(0)}';

  /// "Tsh 12500" or "Tsh 12500.0": the stored value exactly as Dart prints it,
  /// for an amount read back from a document whose type isn't known.
  static String savedAsStored(Object amount) => '${AppDefaults.currencySymbol} $amount';
}
