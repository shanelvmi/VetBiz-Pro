// UI5: nothing the old Home reached becomes unreachable, Help moved to the
// More page's top bar, the Needs attention sheet opens each screen with its
// chip chosen, and Home adds no Firestore listener (the pending count comes
// from the bell's own watch).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';

import 'helpers/mr1_more.dart';
import 'helpers/phone_home_harness.dart';

final _dashboard = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();

void main() {
  testWidgets('Help: not on Home\'s top bar, on the More page\'s', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness());
    expect(find.byTooltip('Help'), findsNothing);
    await mrPump(tester, mrMore());
    expect(find.byTooltip('Help'), findsOneWidget);
  });

  test('every place the old Home reached is still reached', () {
    for (final admin in [true, false]) {
      final tiles = homeTilesFor(isAdmin: admin);
      final more = moreItemsFor(isAdmin: admin);
      // Quick access and View all: the record tiles and the '+' sheet.
      expect([for (final t in tiles) homeTileAction(t)].whereType<RecordAction>(), quickAccessActions);
      expect(recordMoreActionsFor(isAdmin: admin), [
        if (admin) RecordAction.addProduct,
        RecordAction.addBatch,
        RecordAction.recordTransaction,
      ]);
      // Go to: Products is the bottom bar's tab; the rest are tiles or More.
      final places = [for (final t in tiles) homeTilePlace(t)].whereType<MoreItem>().toSet();
      for (final item in [MoreItem.clients, MoreItem.debtors, MoreItem.reports, MoreItem.transactions,
          MoreItem.stockStore, MoreItem.services, MoreItem.payments]) {
        expect(places.contains(item) || more.contains(item), isTrue, reason: '$item ($admin)');
      }
    }
    // Needs attention: Product Alerts and Debtors as before, Team Members new.
    expect(AttentionKind.values.map(attentionItemTarget).toSet(), AttentionTarget.values.toSet());
  });

  test('the sheet opens each screen with its chip chosen', () {
    expect(_dashboard, contains('StockAlertsScreen(initialKind: attentionStockKind(item.kind))'));
    expect(_dashboard, contains('DebtorsScreen(initialStatus: DebtorsScreen.statusOverdue)'));
    expect(_dashboard, contains('ManageAssistantsScreen(initialStatus: UserStatus.pending.key)'));
    // The kinds a stock item can choose are the screen's own chips.
    for (final k in AttentionKind.values) {
      final kind = attentionStockKind(k);
      if (kind != null) expect(StockAlertKind.values, contains(kind));
    }
  });

  test('no new listener: the pending count is read from the bell\'s existing watch', () {
    // One pending-members query in the dashboard, as before UI5, and the
    // count is set inside its listener.
    expect(RegExp(r'isEqualTo: UserStatus\.pending\.key').allMatches(_dashboard).length, 1);
    expect(_dashboard, contains('_pendingApprovals = snapshot.docs.length;'));
    final home = File('lib/screens/dashboard/phone_home.dart').readAsStringSync() +
        File('lib/screens/dashboard/phone_home_rows.dart').readAsStringSync() +
        File('lib/screens/dashboard/needs_attention.dart').readAsStringSync() +
        File('lib/screens/dashboard/today_card.dart').readAsStringSync();
    for (final call in ['.snapshots(', '.get(', 'collection(', 'Provider.of<']) {
      expect(home.contains(call), isFalse, reason: 'Home reads nothing itself: $call');
    }
  });
}
