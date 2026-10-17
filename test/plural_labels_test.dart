import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';

/// The English said "1 payments", "of 1 products", "Expires in 1 days" and
/// so on; the owner approved a singular for one (plural pass after 2F-13).
/// Like test/debt_days_labels_test.dart: English for 1, 0, 2 and 30,
/// Kiswahili for 1 and 2.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final sw = lookupAppLocalizations(const Locale('sw'));

  void check(String key, String Function(AppLocalizations l, int n) label,
      {required String Function(int n) english, required Map<int, String> kiswahili}) {
    test(key, () {
      for (final n in [1, 0, 2, 30]) {
        expect(label(en, n), english(n), reason: 'en $n');
      }
      for (final e in kiswahili.entries) {
        expect(label(sw, e.key), e.value, reason: 'sw ${e.key}');
      }
    });
  }

  check('payments_paymentCount', (l, n) => l.payments_paymentCount(n),
      english: (n) => n == 1 ? '1 payment' : '$n payments',
      kiswahili: {1: 'malipo 1', 2: 'malipo 2'});

  check('payments_debtCount', (l, n) => l.payments_debtCount(n),
      english: (n) => n == 1 ? '1 debt' : '$n debts',
      kiswahili: {1: 'deni 1', 2: 'madeni 2'});

  check('products_showingRange', (l, n) => l.products_showingRange(n, 1, n),
      english: (n) => n == 1 ? 'Showing 1 to 1 of 1 product' : 'Showing 1 to $n of $n products',
      kiswahili: {1: 'Inaonyesha 1 hadi 1 kati ya bidhaa 1', 2: 'Inaonyesha 1 hadi 2 kati ya bidhaa 2'});

  check('reports_unitsCount', (l, n) => l.reports_unitsCount(n),
      english: (n) => n == 1 ? '1 unit' : '$n units',
      kiswahili: {1: 'Kipimo 1', 2: 'Vipimo 2'});

  check('services_foundCount', (l, n) => l.services_foundCount(n),
      english: (n) => '$n found',
      kiswahili: {1: '1 imepatikana', 2: '2 zimepatikana'});

  check('services_archiveSubtitle', (l, n) => l.services_archiveSubtitle(n),
      english: (n) => n == 1 ? 'Services archived after 1 day' : 'Services archived after $n days',
      kiswahili: {
        1: 'Huduma huhifadhiwa kwenye kumbukumbu baada ya siku 1',
        2: 'Huduma huhifadhiwa kwenye kumbukumbu baada ya siku 2',
      });

  check('sales_archiveSubtitle', (l, n) => l.sales_archiveSubtitle(n),
      english: (n) => n == 1 ? 'Sales archived after 1 day' : 'Sales archived after $n days',
      kiswahili: {1: 'Mauzo huhifadhiwa baada ya siku 1', 2: 'Mauzo huhifadhiwa baada ya siku 2'});

  check('sales_archiveShowing', (l, n) => l.sales_archiveShowing(1, n, n, ''),
      english: (n) => n == 1 ? 'Showing 1 to 1 of 1 sale' : 'Showing 1 to $n of $n sales',
      kiswahili: {1: 'Inaonyesha 1 hadi 1 kati ya 1 ya mauzo', 2: 'Inaonyesha 1 hadi 2 kati ya 2 ya mauzo'});

  check('services_archiveShowing', (l, n) => l.services_archiveShowing(1, n, n, ''),
      english: (n) => n == 1 ? 'Showing 1 to 1 of 1 service' : 'Showing 1 to $n of $n services',
      kiswahili: {1: 'Inaonyesha 1 hadi 1 kati ya huduma 1', 2: 'Inaonyesha 1 hadi 2 kati ya huduma 2'});

  check('trash_expiresIn', (l, n) => l.trash_expiresIn(n),
      english: (n) => n == 1 ? 'Expires in 1 day' : 'Expires in $n days',
      kiswahili: {1: 'Kinaisha baada ya siku 1', 2: 'Kinaisha baada ya siku 2'});

  test('the "+" for more pages stays after the total', () {
    expect(en.sales_archiveShowing(1, 20, 20, '+'), 'Showing 1 to 20 of 20+ sales');
    expect(en.services_archiveShowing(1, 20, 20, '+'), 'Showing 1 to 20 of 20+ services');
  });
}
