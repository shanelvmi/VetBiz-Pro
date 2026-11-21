// UX1a: the top-level destinations inside AppShell show the shared
// PageHeader (owner, 2026-11-21): a surface bar, not a teal one; the title
// on the left, not centred; the screen's actions on the right; no back
// arrow. At content 696, 774, 950 and 1128, text 1.3, English and Kiswahili,
// without overflow. On the phone the same screens keep their own bars (no
// PageHeader). Insights is not in UX1a (its body would move: owner).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _shell = GlobalKey<AppShellState>();

const _places = [
  AppDestination.sales,
  AppDestination.services,
  AppDestination.clients,
  AppDestination.debtors,
  AppDestination.payments,
  AppDestination.transactions,
  AppDestination.products,
  AppDestination.stockStore,
  AppDestination.reports,
];

Widget? _pageFor(AppDestination d, FirebaseFirestore fs) => switch (d) {
      AppDestination.sales => SalesScreen(firestore: fs),
      AppDestination.services => ServicesScreen(firestore: fs),
      AppDestination.clients => ClientsScreen(firestore: fs),
      AppDestination.debtors => DebtorsScreen(firestore: fs),
      AppDestination.payments => PaymentsScreen(firestore: fs),
      AppDestination.transactions => TransactionScreen(firestore: fs),
      AppDestination.products => ProductsScreen(),
      AppDestination.stockStore => StockStoreScreen(),
      AppDestination.reports => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
      _ => null,
    };

/// The title each screen had (and keeps), and one action it must still show.
(String, Finder) _expected(AppDestination d, AppLocalizations l) => switch (d) {
      AppDestination.sales => (l.sales_title, find.text(l.sales_recordSale)),
      AppDestination.services => (l.common_serviceRecords, find.text(l.services_recordVisit)),
      AppDestination.clients => (l.clients_title, find.text(l.clients_add)),
      AppDestination.debtors => (l.debtors_title, find.text(l.debtors_recordPayment)),
      AppDestination.payments => (l.payments_title, find.byIcon(Icons.date_range_outlined)),
      AppDestination.transactions => (l.transactions_title, find.text(l.transactions_record)),
      AppDestination.products => (l.products_sellableTitle, find.byIcon(Icons.notifications_none)),
      AppDestination.stockStore => (l.store_title, find.byIcon(Icons.notifications_none)),
      _ => (l.reports_viewTitle, find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    };

Widget _harness(FirebaseFirestore fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(width: sidebar),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => _pageFor(d, fs),
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

void main() {
  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = size.width - sidebar;
    for (final look in const [MatrixLook.light, MatrixLook.kiswahili]) {
      for (final d in _places) {
        ph5TestWidgets('${d.name} at content ${content.toInt()} ${look.name} text 1.3: the PageHeader', (tester) async {
          await pumpPh5(tester, (fs) => _harness(fs, sidebar), size: size, look: look, textScale: 1.3);
          _shell.currentState!.select(d);
          await ph5Settle(tester);
          expect(tester.takeException(), isNull, reason: 'no overflow');

          final header = find.byType(PageHeader);
          expect(header, findsOneWidget);
          expect(find.byType(AppBar), findsNothing, reason: 'the old bar is gone');
          expect(find.byType(BackButton), findsNothing, reason: 'top level: no back arrow');
          final ctx = tester.element(header);
          final (title, action) = _expected(d, ctx.l10n);

          // A surface bar, not a teal one.
          final material = tester.widget<Material>(find.descendant(of: header, matching: find.byType(Material)).first);
          expect(material.color, ctx.colors.surface);
          expect(material.color, isNot(ctx.colors.brandSurface));

          // The title on the left: at the page padding, or after the drawer's
          // menu button (Products and Stock Store below 900), never centred.
          final titleFinder = find.descendant(of: header, matching: find.text(title));
          expect(titleFinder, findsOneWidget);
          final left = tester.getTopLeft(header).dx;
          final hasDrawer = content < AppBreakpoints.medium &&
              (d == AppDestination.products || d == AppDestination.stockStore);
          expect(find.byType(DrawerButton), hasDrawer ? findsOneWidget : findsNothing);
          final titleX = tester.getTopLeft(titleFinder).dx - left;
          if (hasDrawer) {
            expect(titleX, lessThan(PolishMetrics.pagePadding + 64));
          } else {
            expect(titleX, PolishMetrics.pagePadding);
          }

          // The action is in the header, right of the title, and the last
          // action ends at the header's right (4 + the screen's own 12).
          final inHeader = find.descendant(of: header, matching: action);
          expect(inHeader, findsWidgets);
          expect(tester.getTopLeft(inHeader.first).dx, greaterThanOrEqualTo(tester.getTopRight(titleFinder).dx));
          final buttons = find.descendant(of: header, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton || w is IconButton));
          final rightmost = buttons.evaluate().map((e) => tester.getTopRight(find.byElementPredicate((x) => x == e)).dx).reduce((a, b) => a > b ? a : b);
          expect(left + content - rightmost, 16, reason: 'the actions end at the right');
        });
      }
    }
  }

  // The phone keeps its own bars: no PageHeader on any of the nine.
  for (final d in _places) {
    ph5TestWidgets('${d.name} on the phone (390): no PageHeader', (tester) async {
      await pumpPh5(tester, (fs) => _pageFor(d, fs)!, size: const Size(390, 844));
      await ph5Settle(tester);
      expect(find.byType(PageHeader), findsNothing);
      expect(find.byType(AppBar), findsWidgets);
    });
  }
}
