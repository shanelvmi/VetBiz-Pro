// LAY5: Products and Stock Store inside AppShell (a fake Firestore, no
// dashboard), at windows 768, 1024 and 1200 with the sidebar open and
// collapsed (content 696, 774, 952, 950, 1128), text 1.3, Light and Dark,
// every colour theme: no overflow, the place highlighted, no back arrow, and
// the filter panel reachable: a left column from medium (900) up, below it the
// drawer opened by the automatic drawer button, where a status filter applies.
// Back pops inside, then Home, and Home is told to refresh (registry). The
// top bar search opens Products with its query inside the shell.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/product_catalog_side_panel.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _shell = GlobalKey<AppShellState>();
final _returned = <AppDestination>[];
final _full = <AppDestination>[];

const _places = [AppDestination.home, AppDestination.products, AppDestination.stockStore, AppDestination.sales];

Widget _harness(double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in _places)
              SizedBox(
                key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'),
                height: 48,
                child: TextButton(onPressed: () => onSelect(d), child: const SizedBox.shrink()),
              ),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => switch (d) {
          AppDestination.products => ProductsScreen(),
          AppDestination.stockStore => StockStoreScreen(),
          _ => null,
        },
        onOpenFullScreen: (d) async => _full.add(d),
        onReturnedHome: _returned.add,
      ),
    );

Type _typeOf(AppDestination d) => d == AppDestination.products ? ProductsScreen : StockStoreScreen;

Future<void> _open(WidgetTester tester, AppDestination d) async {
  _shell.currentState!.select(d);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _returned.clear();
    _full.clear();
  });

  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1024, 768), 72.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = size.width - sidebar;
    final column = content >= AppBreakpoints.medium;
    for (final theme in AppColorTheme.all) {
      for (final look in const [MatrixLook.light, MatrixLook.dark]) {
        for (final d in const [AppDestination.products, AppDestination.stockStore]) {
          final name = '${d.name} at content ${content.toInt()} ${theme.id} ${look.name} text 1.3';
          ph5TestWidgets('$name: highlighted, no back arrow, filter panel ${column ? 'a column' : 'in the drawer'}',
              (tester) async {
            await pumpPh5(tester, (fs) => _harness(sidebar), size: size, look: look, colorTheme: theme, textScale: 1.3);
            await _open(tester, d);
            expect(tester.takeException(), isNull);
            final screen = find.byType(_typeOf(d));
            expect(screen, findsOneWidget);
            expect(tester.getTopLeft(screen).dx, sidebar, reason: 'beside the sidebar');
            expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget);
            expect(find.byType(BackButton), findsNothing, reason: 'top level: no back arrow');
            final panel = find.byType(ProductCatalogSidePanel);
            if (column) {
              expect(panel, findsOneWidget, reason: 'a left column');
              expect(find.byType(DrawerButton), findsNothing);
            } else {
              expect(panel, findsNothing, reason: 'in the closed drawer');
              final button = find.byType(DrawerButton);
              expect(button, findsOneWidget, reason: 'the way to the filter panel stays');
              final l10n = AppLocalizations.of(tester.element(screen))!;
              expect(tester.widget<Tooltip>(find.descendant(of: button, matching: find.byType(Tooltip))).message,
                  MaterialLocalizations.of(tester.element(screen)).openAppDrawerTooltip);
              await tester.tap(button);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(panel, findsOneWidget);
              await tester.tap(find.descendant(of: panel, matching: find.text(l10n.products_statusLowStock)));
              await tester.pumpAndSettle();
              expect(tester.widget<ProductCatalogSidePanel>(panel).selectedStatus, 'Low Stock',
                  reason: 'the filter applies from the drawer');
            }
          });
        }
      }
    }
  }

  for (final d in const [AppDestination.products, AppDestination.stockStore]) {
    ph5TestWidgets('${d.name}: Back pops inside, then Home, and Home is told to refresh', (tester) async {
      await pumpPh5(tester, (fs) => _harness(250), size: const Size(1200, 800));
      await _open(tester, d);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
      expect(_returned, [d]);
      expect(d.refreshHomeOnReturn, isTrue, reason: 'the registry: Home refreshes after it');
    });
  }

  ph5TestWidgets('Products -> Stock Store is not a return to Home; Sales still opens full screen', (tester) async {
    await pumpPh5(tester, (fs) => _harness(250), size: const Size(1200, 800));
    await _open(tester, AppDestination.products);
    await _open(tester, AppDestination.stockStore);
    expect(_returned, isEmpty);
    await _open(tester, AppDestination.sales);
    expect(_full, [AppDestination.sales]);
    expect(find.byType(StockStoreScreen), findsOneWidget);
  });

  ph5TestWidgets('the search result: Products with its query, inside the shell, Products highlighted', (tester) async {
    await pumpPh5(tester, (fs) => _harness(250), size: const Size(1200, 800));
    _shell.currentState!.openInContent(ProductsScreen(initialSearchQuery: 'Albendazole'), highlight: AppDestination.products);
    await tester.pumpAndSettle();
    expect(tester.widget<ProductsScreen>(find.byType(ProductsScreen)).initialSearchQuery, 'Albendazole');
    expect(find.byKey(const ValueKey('sb-products-selected')), findsOneWidget);
    expect(find.text('Albendazole'), findsWidgets, reason: 'the query is in the search field');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget, reason: 'Back returns where you were');
  });

  group('the dashboard', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    test('the search result uses the shell on a wide window and pushes without one', () {
      final at = dash.indexOf('final page = ProductsScreen(initialSearchQuery: p.name);');
      expect(at, isNonNegative);
      final tap = dash.substring(at, dash.indexOf('},', at));
      expect(tap, contains('shell.openInContent(page, highlight: AppDestination.products);'));
      expect(tap, contains('Navigator.push(context, MaterialPageRoute(builder: (_) => page));'));
    });
  });
}
