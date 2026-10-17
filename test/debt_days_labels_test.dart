import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';

/// Active Debts said "1 days" and "Over 1 days" (docs/FIXES.md, item 3).
/// debtors_daysCount is also used by the retention and overdue dialogs.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final sw = lookupAppLocalizations(const Locale('sw'));

  test('English: 1 day, otherwise N days', () {
    expect(en.debtors_daysCount(1), '1 day');
    expect(en.debtors_overDays(1), 'Over 1 day');
    for (final n in [0, 2, 30]) {
      expect(en.debtors_daysCount(n), '$n days');
      expect(en.debtors_overDays(n), 'Over $n days');
    }
  });

  test('Kiswahili: siku does not change with the number', () {
    for (final n in [0, 1, 2, 30]) {
      expect(sw.debtors_daysCount(n), 'Siku $n');
      expect(sw.debtors_overDays(n), 'Zaidi ya siku $n');
    }
  });
}
