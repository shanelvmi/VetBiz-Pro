import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:vetbiz_pro/config/money.dart';

/// Money must print exactly what the screens' own formatters print today.
void main() {
  // The three formatters screens build for themselves today.
  final legacyCurrency = NumberFormat.currency(locale: 'en_US', symbol: 'Tsh ', decimalDigits: 0);
  final legacyPlain = NumberFormat('#,##0', 'en_US');
  final legacyDecimal = NumberFormat.decimalPattern();

  const amounts = <num>[
    0, 1, 999, 1000, 12500, 12500.4, 12500.5, 12501.5, 1234567.891, -12500, -0.4, 0.125, 1e9,
  ];

  test('format equals NumberFormat.currency(en_US, "Tsh ", 0 decimals)', () {
    for (final a in amounts) {
      expect(Money.format(a), legacyCurrency.format(a), reason: '$a');
    }
  });

  test('plain equals NumberFormat("#,##0", "en_US")', () {
    for (final a in amounts) {
      expect(Money.plain(a), legacyPlain.format(a), reason: '$a');
    }
  });

  test('decimal equals NumberFormat.decimalPattern() with no locale', () {
    for (final a in amounts) {
      expect(Money.decimal(a), legacyDecimal.format(a), reason: '$a');
    }
  });

  test('the exact strings people see', () {
    expect(Money.format(12500), 'Tsh 12,500');
    expect(Money.format(-12500), '-Tsh 12,500');
    expect(Money.plain(12500), '12,500');
    expect(Money.decimal(12500), '12,500');
    expect(Money.decimal(12500.5), '12,500.5');
    expect(Money.decimal(1234567.891), '1,234,567.891');
  });
}
