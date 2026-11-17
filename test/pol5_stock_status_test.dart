// POL5 (owner note 4): one function maps a product's STORED stock status to
// one of the four states. It takes the stored English value, never the
// translated label, so the mapping is the same with the app in Kiswahili.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';

/// Every stored value products_screen's `_getProductStatus` writes.
const _expected = {
  'Active': AppStatus.neutral,
  'Not Stocked': AppStatus.neutral,
  'Unknown': AppStatus.neutral,
  'Low Stock': AppStatus.warning,
  'Reorder Soon': AppStatus.warning,
  'Expiring Soon': AppStatus.warning,
  'Depleted': AppStatus.danger,
  'Expired': AppStatus.danger,
};

void main() {
  test('stockAppStatus: every stored value; an unknown one is neutral', () {
    for (final e in _expected.entries) {
      expect(stockAppStatus(e.key), e.value, reason: e.key);
    }
    for (final unknown in ['', 'expired', 'Low stock', 'Out of Stock']) {
      expect(stockAppStatus(unknown), AppStatus.neutral, reason: unknown);
    }
  });

  testWidgets('with the app in Kiswahili the stored values map the same', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(Localizations(
      locale: const Locale('sw'),
      delegates: AppLocalizations.localizationsDelegates,
      child: Builder(builder: (context) {
        l10n = AppLocalizations.of(context)!;
        return const SizedBox();
      }),
    ));
    expect(l10n.localeName, 'sw');
    for (final e in _expected.entries) {
      expect(stockAppStatus(e.key), e.value, reason: e.key);
    }
    // A translated label is not a stored value: passing one would lose the
    // state, which is why callers pass the stored text.
    expect(l10n.products_statusExpired, isNot('Expired'));
    expect(stockAppStatus(l10n.products_statusExpired), AppStatus.neutral);
    expect(l10n.products_statusEmpty, isNotEmpty);
  });
}
