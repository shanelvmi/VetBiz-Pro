// UX4 (1): the Product Alerts bell in Products and Stock Store on PC and
// tablet inside AppShell. Content 950 (from medium up): the anchored dropdown
// closes first and its "View all" opens the full screen in the shell's
// content; content 696 (a tablet below medium): the bell itself opens it
// there. Either way the sidebar stays with the bell's place highlighted
// (Products, or Stock Store), the PageHeader shows a back arrow, and Back
// returns to the place. Without a shell (a screen pumped alone) both push as
// before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

final _shell = GlobalKey<AppShellState>();

const _places = [AppDestination.home, AppDestination.products, AppDestination.stockStore];

Widget _harness(double sidebar) => Ph7Listening(
      child: Scaffold(
        body: AppShell(
          key: _shell,
          sidebar: (selected, onSelect) => SizedBox(
            width: sidebar,
            child: Column(children: [
              for (final d in _places)
                SizedBox(key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'), height: 48),
            ]),
          ),
          topBar: const SizedBox(height: 64),
          home: const Text('HOME'),
          pageFor: (d) => switch (d) {
            AppDestination.products => ProductsScreen(),
            AppDestination.stockStore => StockStoreScreen(),
            _ => null,
          },
          onOpenFullScreen: (_) async {},
          onReturnedHome: (_) {},
        ),
      ),
    );

Type _typeOf(AppDestination d) => d == AppDestination.products ? ProductsScreen : StockStoreScreen;

Future<AppLocalizations> _tapBell(WidgetTester tester, AppDestination d) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(_typeOf(d))))!;
  await tester.tap(find.byTooltip(l10n.products_stockAlerts));
  await tester.pumpAndSettle();
  return l10n;
}

Finder _viewAll() => find.descendant(of: find.byType(TextButton), matching: find.byIcon(Icons.arrow_forward));

void main() {
  for (final d in const [AppDestination.products, AppDestination.stockStore]) {
    for (final (size, sidebar, dropdown) in const [
      (Size(1200, 800), 250.0, true),
      (Size(1200, 800), 72.0, true),
      (Size(768, 1024), 72.0, false),
    ]) {
      final how = dropdown ? 'the dropdown\'s View all' : 'the bell';
      ph5TestWidgets('${d.name} at ${size.width.toInt()}, sidebar ${sidebar.toInt()}: $how opens Product Alerts in the shell',
          (tester) async {
        await pumpPh5(tester, (_) => _harness(sidebar), size: size, seed: ph7SeedProducts);
        _shell.currentState!.select(d);
        await tester.pumpAndSettle();
        await _tapBell(tester, d);
        if (dropdown) {
          expect(find.byWidgetPredicate((w) => w is StockAlertsScreen && w.isDropdown), findsOneWidget);
          await tester.ensureVisible(_viewAll());
          await tester.pumpAndSettle();
          await tester.tap(_viewAll());
          await tester.pumpAndSettle();
          expect(find.byWidgetPredicate((w) => w is StockAlertsScreen && w.isDropdown), findsNothing,
              reason: 'the dropdown closed first');
        }
        expect(tester.takeException(), isNull);
        final alerts = find.byWidgetPredicate((w) => w is StockAlertsScreen && !w.isDropdown);
        expect(alerts, findsOneWidget);
        expect(tester.getTopLeft(alerts).dx, sidebar, reason: 'in the content, beside the sidebar');
        expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget, reason: 'the sidebar stays, ${d.name} highlighted');
        expect(find.descendant(of: alerts, matching: find.byType(PageHeader)), findsOneWidget);
        expect(find.descendant(of: alerts, matching: find.byType(BackButton)), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(StockAlertsScreen), findsNothing);
        expect(find.byType(_typeOf(d)), findsOneWidget, reason: 'Back returns where you were');
        expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget);
      });
    }

    ph5TestWidgets('${d.name} alone at 1200 (no shell): View all pushes as before', (tester) async {
      await pumpPh5(tester, (_) => Ph7Listening(child: d == AppDestination.products ? ProductsScreen() : StockStoreScreen()),
          size: const Size(1200, 800), seed: ph7SeedProducts);
      await _tapBell(tester, d);
      expect(tester.widget<StockAlertsScreen>(find.byType(StockAlertsScreen)).onViewAll, isNull);
      await tester.ensureVisible(_viewAll());
      await tester.pumpAndSettle();
      await tester.tap(_viewAll());
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is StockAlertsScreen && !w.isDropdown), findsOneWidget);
      expect(tester.getTopLeft(find.byType(StockAlertsScreen)).dx, 0, reason: 'full screen');
    });
  }
}
