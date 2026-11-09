// UI5: nothing the old Home reached becomes unreachable (HUB1: through the
// action panel), Help is not on Home's top bar (HUB1: the profile menu has it,
// hub1_partition_test), the Needs attention sheet opens each screen with its
// chip chosen, and Home adds no Firestore listener (the pending count comes
// from the bell's own watch; the panel is static content).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/record_actions.dart' show RecordAction;
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';

import 'helpers/phone_home_harness.dart';

final _dashboard = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();

void main() {
  testWidgets('Help: not on Home\'s top bar (the profile menu has it)', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness());
    expect(find.byTooltip('Help'), findsNothing);
  });

  test('every place the old Home reached is still reached', () {
    // HUB1: the four record tiles, View all's extras and every Go to place
    // are in the role's action panel.
    for (final admin in [true, false]) {
      final panel = [for (final g in hubGroupsFor(isAdmin: admin)) ...g.tiles];
      expect(hubCollapsedTilesFor(isAdmin: admin).take(4).map(hubTileAction),
          [RecordAction.recordSale, RecordAction.recordVisit, RecordAction.recordPayment, RecordAction.addClient]);
      expect([for (final t in panel) hubTileAction(t)].whereType<RecordAction>().toSet(), {
        ...RecordAction.values.where((a) => admin || a != RecordAction.addProduct),
      });
      for (final place in [HubTile.products, HubTile.clients, HubTile.debtors, HubTile.reports, HubTile.transactions,
          HubTile.stockStore, HubTile.services, HubTile.payments, HubTile.sales]) {
        expect(panel, contains(place), reason: '$place ($admin)');
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
        File('lib/screens/dashboard/home_action_panel.dart').readAsStringSync() +
        File('lib/screens/dashboard/hub_tiles.dart').readAsStringSync() +
        File('lib/screens/dashboard/needs_attention.dart').readAsStringSync() +
        File('lib/screens/dashboard/today_card.dart').readAsStringSync();
    for (final call in ['.snapshots(', '.get(', 'collection(', 'Provider.of<']) {
      expect(home.contains(call), isFalse, reason: 'Home reads nothing itself: $call');
    }
  });
}
