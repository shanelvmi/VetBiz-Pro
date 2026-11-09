// HUB1 (1): the action panel's engine (hub_destinations.dart): the collapsed
// two rows and the expanded groups per role, the labels, Find a feature in
// English and Kiswahili, each place opening the same screen as before (route
// spies), and each record action going through the same guard and forms as
// the old "+" sheet (a locked facility opens no form).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/platform_admin/platform_admin_home_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));
final _sw = lookupAppLocalizations(const Locale('sw'));

List<String> _names(List<HubTile> tiles) => tiles.map((t) => t.name).toList();

Map<String, List<String>> _groups({required bool isAdmin, bool isPlatformAdmin = false}) => {
      for (final g in hubGroupsFor(isAdmin: isAdmin, isPlatformAdmin: isPlatformAdmin)) g.group.name: _names(g.tiles),
    };

class _Spy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushed.add(route);
  }
}

void main() {
  group('the collapsed two rows', () {
    test('admin (and Co-admin, an admin in the app): the four records, then Sales, Products, Clients, Debtors', () {
      expect(_names(hubCollapsedTilesFor(isAdmin: true)), [
        'recordSale', 'recordVisit', 'recordPayment', 'addClient', //
        'sales', 'products', 'clients', 'debtors',
      ]);
    }, skip: _skip);

    test('assistant: the same eight (no collapsed tile is admin-only today)', () {
      expect(hubCollapsedTilesFor(isAdmin: false), hubCollapsedTilesFor(isAdmin: true));
    }, skip: _skip);

    test('row 2 labels are one word in English and Kiswahili', () {
      for (final l10n in [_en, _sw]) {
        for (final t in hubCollapsedTiles.skip(4)) {
          expect(hubTileLabel(l10n, t).contains(' '), isFalse, reason: hubTileLabel(l10n, t));
        }
      }
      expect([for (final t in hubCollapsedTiles.skip(4)) hubTileLabel(_en, t)], ['Sales', 'Products', 'Clients', 'Debtors']);
    }, skip: _skip);
  });

  group('the expanded groups', () {
    test('admin: Record, Daily work, Business', () {
      expect(_groups(isAdmin: true), {
        'record': ['recordSale', 'recordVisit', 'recordPayment', 'addClient', 'recordTransaction', 'addProduct', 'addBatch'],
        'dailyWork': ['sales', 'products', 'services', 'clients', 'debtors', 'payments', 'transactions', 'stockStore'],
        'business': ['reports', 'insights'],
      });
    }, skip: _skip);

    test('assistant: no Add Product; the rest keep their order', () {
      final g = _groups(isAdmin: false);
      expect(g['record'], ['recordSale', 'recordVisit', 'recordPayment', 'addClient', 'recordTransaction', 'addBatch']);
      expect(g['dailyWork'], _groups(isAdmin: true)['dailyWork']);
      expect(g['business'], ['reports', 'insights']);
    }, skip: _skip);

    test('platform admin: Platform Admin last in Business (owner answer)', () {
      expect(_groups(isAdmin: true, isPlatformAdmin: true)['business'], ['reports', 'insights', 'platformAdmin']);
      expect(_groups(isAdmin: false, isPlatformAdmin: true)['business'], ['reports', 'insights', 'platformAdmin']);
    }, skip: _skip);

    test('every collapsed tile is in a group; group titles reuse existing labels', () {
      final all = [for (final g in hubGroupsFor(isAdmin: true)) ...g.tiles];
      expect(all.toSet().containsAll(hubCollapsedTiles), isTrue);
      expect([for (final g in HubGroup.values) hubGroupTitle(_en, g)], ['Record', 'Daily work', 'Business']);
    }, skip: _skip);
  });

  group('Find a feature', () {
    List<String> find(String q, {AppLocalizations? shown}) =>
        _names([for (final t in HubTile.values) if (hubTileMatches(shown ?? _en, t, q)) t]);

    test('English labels and keywords', () {
      expect(find('sale'), containsAll(['recordSale', 'sales']));
      expect(find('expense'), containsAll(['recordTransaction', 'transactions']));
      expect(find('owe'), containsAll(['recordPayment', 'debtors']));
      expect(find('warehouse'), ['stockStore']);
      expect(find('  CHARTS '), ['insights']);
    }, skip: _skip);

    test('Kiswahili words find their tile whatever the language shown', () {
      expect(find('mauzo'), contains('sales'));
      expect(find('wadaiwa'), contains('debtors'));
      expect(find('bidhaa', shown: _sw), contains('products'));
    }, skip: _skip);

    test('Settings-screen and profile-menu destinations are not in the panel', () {
      for (final q in ['subscription', 'export', 'trash', 'printer', 'team', 'settings', 'help']) {
        expect(find(q), isEmpty, reason: q);
      }
    }, skip: _skip);

    test('an empty query finds everything', () {
      expect(find(''), _names(HubTile.values));
    }, skip: _skip);
  });

  group('places open the same screens as before', () {
    const screens = {
      HubTile.sales: SalesScreen,
      HubTile.products: ProductsScreen,
      HubTile.services: ServicesScreen,
      HubTile.clients: ClientsScreen,
      HubTile.debtors: DebtorsScreen,
      HubTile.payments: PaymentsScreen,
      HubTile.transactions: TransactionScreen,
      HubTile.stockStore: StockStoreScreen,
      HubTile.reports: ViewReportsScreen,
      HubTile.platformAdmin: PlatformAdminHomeScreen,
    };
    for (final e in screens.entries) {
      testWidgets('${e.key.name} pushes ${e.value} with a back arrow (a pushed page)', (tester) async {
        final spy = _Spy();
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          navigatorObservers: [spy],
          home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
        ));
        openHubPlace(ctx, e.key);
        expect(spy.pushed, hasLength(1));
        final route = spy.pushed.single as MaterialPageRoute<dynamic>;
        expect(route.builder(route.navigator!.context).runtimeType, e.value);
        route.navigator!.removeRoute(route);
        await tester.pump();
      }, skip: _skip);
    }
  });

  group('record actions keep the old guard and forms', () {
    for (final tile in HubTile.values.where((t) => hubTileAction(t) != null)) {
      testWidgets('${tile.name}: locked opens no form; unlocked opens it', (tester) async {
        final opened = <String>[];
        final guarded = <String>[];
        RecordSheetActions actions() => RecordSheetActions(
              recordSale: (_) async => opened.add('recordSale'),
              recordVisit: (_) async => opened.add('recordVisit'),
              recordPayment: (_, __) async => opened.add('recordPayment'),
              addClient: (_) async => opened.add('addClient'),
              addProduct: (_) async => opened.add('addProduct'),
              addBatch: (_) async => opened.add('addBatch'),
              recordTransaction: (_) async => opened.add('recordTransaction'),
              fetchDebtors: (_) async => [Client.fromMap('c1', {'name': 'A', 'phone': '1', 'balance': 10})],
            );
        RecordGuard guard({required bool locked}) => (context, destination, {onNavigate}) async {
              guarded.add(tile.name);
              if (!locked) await onNavigate?.call();
            };
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })));
        var done = 0;
        await runHubTile(ctx, tile, actions: actions(), guard: guard(locked: true), onDone: () => done++);
        expect(guarded, [tile.name]);
        expect(opened, isEmpty);
        await runHubTile(ctx, tile, actions: actions(), guard: guard(locked: false), onDone: () => done++);
        expect(opened, [tile.name]);
        expect(done, 1);
      }, skip: _skip);
    }

    testWidgets('a place does not pass the guard and runs onDone after its screen', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })));
      final opened = <HubTile>[];
      var done = 0;
      await runHubTile(ctx, HubTile.debtors,
          guard: (_, __, {onNavigate}) async => fail('guarded'),
          openPlace: (_, t) async => opened.add(t),
          onDone: () => done++);
      expect(opened, [HubTile.debtors]);
      expect(done, 1);
    }, skip: _skip);
  });
}
