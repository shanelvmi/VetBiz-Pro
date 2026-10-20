import 'package:intl/intl.dart';

import 'app_defaults.dart';

/// Formats amounts of money, the same way everywhere (R3, decisions D1 to D4
/// in docs/RUNBOOK2.md; the exact output is pinned in test/money_test.dart):
/// - one spelling, "Tsh" (D1), and one negative shape, "-Tsh 12,500" (D2);
/// - totals, balances and amounts in whole shillings: [format], [plain]
///   ("Tsh 12,501" for 12,500.5); a unit price keeps up to two decimals when
///   the stored price has them: [unitPrice], [unitPricePlain] (D3);
/// - stored numbers never change: rounding is display only.
class Money {
  Money._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppDefaults.numberLocale,
    symbol: '${AppDefaults.currencySymbol} ',
    decimalDigits: 0,
  );
  static final NumberFormat _plain = NumberFormat('#,##0', AppDefaults.numberLocale);
  static final NumberFormat _decimal = NumberFormat.decimalPattern(AppDefaults.numberLocale);

  /// "Tsh 12,500", "-Tsh 12,500": every total, balance and amount shown.
  static String format(num amount) => _currency.format(amount);

  /// "12,500": [format] without the symbol, where a header or label has it.
  static String plain(num amount) => _plain.format(amount);

  /// "12,500" or "12,500.5": grouping, and up to three decimals when present.
  /// For a text field people edit only: a prefill rounded to whole shillings
  /// would be saved rounded. Everything shown uses [format] or [plain] (R3, D3).
  static String decimal(num amount) => _decimal.format(amount);

  static final NumberFormat _unitPrice = NumberFormat('#,##0.##', AppDefaults.numberLocale);

  /// A unit price: "Tsh 1,250", or "Tsh 1,250.5" / "Tsh 1,250.75" when the
  /// stored price has decimals (at most two). Totals, balances and other
  /// amounts are whole shillings ([format]); stored numbers never change (R3, D3).
  static String unitPrice(num amount) =>
      '${amount < 0 ? '-' : ''}${AppDefaults.currencySymbol} ${unitPricePlain(amount.abs())}';

  /// [unitPrice] without the symbol: "1,250.5", for a column headed "Price".
  static String unitPricePlain(num amount) => _unitPrice.format(amount);

  /// A document value whose type is not known (a subscription amount, stored
  /// as 50000 or 50000.0), shown like [format]: "Tsh 50,000". Missing or not
  /// a number: "Tsh 0".
  static String formatStored(Object? amount) =>
      format(amount is num ? amount : num.tryParse('${amount ?? ''}') ?? 0);

  /// The dashboard's breakdown under Net Profit has little room: from a
  /// million it shows "Tsh 10.888M" (three decimals), below that [format].
  /// A negative is "-Tsh 10.888M" (R3, D2).
  static String compactMillions(num amount) {
    if (amount.abs() < 1000000) return format(amount);
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

  /// SAVED text: activity and transaction descriptions written to Firestore,
  /// for example "Recorded sale to Walk-in - Tsh 12,500". New entries read like
  /// the screens (R3, D4); old entries keep what they say ("Tsh 12500"), and
  /// nothing parses an amount back out of a description.
  static String saved(num amount) => format(amount);
}
