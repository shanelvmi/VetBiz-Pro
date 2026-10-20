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

  test('saved text keeps its exact legacy shape (no thousands separator)', () {
    for (final a in amounts) {
      expect(Money.savedWhole(a), 'Tsh ${a.toStringAsFixed(0)}', reason: '$a');
    }
    for (final Object v in [12500, 12500.0, 12500.5, 0]) {
      expect(Money.savedAsStored(v), 'Tsh ${v.toString()}', reason: '$v');
    }
    expect(Money.savedWhole(12500), 'Tsh 12500');
    expect(Money.savedAsStored(12500.0), 'Tsh 12500.0');
  });

  test('a currency formatter with an empty symbol prints the same as plain', () {
    // add_edit_service_screen's formatter: NumberFormat.currency(symbol: '').
    final emptySymbol = NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 0);
    for (final a in amounts) {
      expect(Money.plain(a), emptySymbol.format(a), reason: '$a');
    }
  });

  // D2: one negative shape, "-Tsh 12,500" (symbolPlain, which printed
  // "Tsh -12,500", is gone; its callers use format).
  r3Pins('format', Money.format, {
    0: 'Tsh 0',
    1: 'Tsh 1',
    999: 'Tsh 999',
    12500: 'Tsh 12,500',
    12500.5: 'Tsh 12,501',
    1234567.89: 'Tsh 1,234,568',
    -12500: '-Tsh 12,500',
    1e12: 'Tsh 1,000,000,000,000',
  });
  r3Pins('symbolDecimal', Money.symbolDecimal, {
    0: 'Tsh 0',
    1: 'Tsh 1',
    999: 'Tsh 999',
    12500: 'Tsh 12,500',
    12500.5: 'Tsh 12,500.5',
    1234567.89: 'Tsh 1,234,567.89',
    -12500: '-Tsh 12,500',
    1e12: 'Tsh 1,000,000,000,000',
  });
  r3Pins('compactMillions', Money.compactMillions, {
    0: 'Tsh 0',
    1: 'Tsh 1',
    999: 'Tsh 999',
    12500: 'Tsh 12,500',
    12500.5: 'Tsh 12,500.5',
    1234567.89: 'Tsh 1.235M',
    -12500: '-Tsh 12,500',
    -10000888: '-Tsh 10.001M',
    1e12: 'Tsh 1000000.000M',
  });

  // D1: one spelling, "Tsh". The facility card said "TZS".
  r3Pins('compact', Money.compact, {
    0: 'Tsh 0',
    1: 'Tsh 1',
    999: 'Tsh 999',
    12500: 'Tsh 12.5K',
    12500.5: 'Tsh 12.5K',
    1234567.89: 'Tsh 1.2M',
    -12500: '-Tsh 12.5K',
    1e12: 'Tsh 1000000.0M',
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

/// R3 (docs/RUNBOOK2.md D1 to D4): the exact text each Money method prints for
/// the owner's sample amounts. These ARE the decisions; change them only with one.
void r3Pins(String name, String Function(num) method, Map<num, String> expected) {
  test('R3: Money.$name prints exactly what the decisions say', () {
    for (final e in expected.entries) {
      expect(method(e.key), e.value, reason: '${e.key}');
    }
  });
}
