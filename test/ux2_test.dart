// UX2 (owner, 2026-11-21), PC and tablet inside AppShell at content 696,
// 774, 950, 952 and 1128 (768, 1024 and 1200 with the sidebar open and
// collapsed), text 1.3, Light, Dark, Kiswahili, every colour theme:
// - Sales: no Collected card; the cards are sales-only (a service payment
//   and other income collected in the same days do not enter them).
// - Payments: the cards have three rows, the trend on the value's row.
// - Payments and Transactions: a Date column (date and time in one cell),
//   no day header rows or day totals.
// - Clients: Active is a success dot in the list, Inactive neutral.
// - Transactions: the income arrow success, the expense arrow neutral; the
//   signs are kept.
// - Products and Stock Store: no facility name in the filter panel.
// The phone keeps its own layouts (their tests and fingerprints).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_date_format.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/flat_stat_card.dart';
import 'package:vetbiz_pro/widgets/product_catalog_side_panel.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _shell = GlobalKey<AppShellState>();

Widget _harness(double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(width: sidebar),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (_) => null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

const _shapes = [
  (Size(768, 1024), 72.0),
  (Size(1024, 768), 250.0),
  (Size(1024, 768), 72.0),
  (Size(1200, 800), 250.0),
  (Size(1200, 800), 72.0),
];

/// Sales of 30,000 (paid 20,000) over two days, plus money that is not a
/// sale: a service payment and other income, all collected (in payments
/// and dailyCollections) on the same days.
Future<void> _seed(FirebaseFirestore fs) async {
  await ph5SeedSales(fs, [
    Ph5Sale('s1', ph5When(0), client: 'Amina Juma', amount: 10000, paid: 10000),
    Ph5Sale('s2', ph5When(1), client: 'Baraka Mushi', amount: 20000, paid: 10000),
  ]);
  final day = ph5DayKey(ph5When(0));
  await facilityCollection(fs, Collections.dailyCollections).doc(day).set({'totalCollected': 10000 + 777000});
  await facilityCollection(fs, Collections.services).doc('v1').set({
    'name': 'Vaccination', 'totalAmount': 777000, 'totalPaid': 777000,
    'serviceDate': Timestamp.fromDate(ph5When(0)), 'timestamp': Timestamp.fromDate(ph5When(0)),
  });
  await ph5SeedTransactions(fs, [Ph5Tx('t1', ph5When(0), type: 'Other Income', amount: 55000, description: 'Rent received')]);
  await ph5SeedClients(fs, [
    Ph5Client('c1', 'Amina Juma', ph5When(40)),
    Ph5Client('c2', 'Juma Said', ph5When(40), status: 'Inactive'),
  ]);
  await ph5SeedPayments(fs, [
    Ph5Payment('p1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 8000),
    Ph5Payment('p2', ph5When(1, minutes: 5), client: 'Baraka Mushi', amount: 4000),
  ]);
  await ph5SeedTransactions(fs, [
    Ph5Tx('t2', ph5When(0, minutes: 9), type: 'expense', amount: 3000, description: 'Fuel for the car'),
    Ph5Tx('t3', ph5When(1, minutes: 9), type: 'Other Income', amount: 6000, description: 'Rent for November', category: 'Rent'),
  ]);
}

Future<void> _open(WidgetTester tester, Widget Function(FirebaseFirestore) build, Size size, double sidebar,
    {MatrixLook look = MatrixLook.light, AppColorTheme theme = AppColorTheme.pasture, double textScale = 1}) async {
  late FirebaseFirestore store;
  await pumpPh5(tester, (fs) {
    store = fs;
    return Ph7Listening(child: _harness(sidebar));
  }, size: size, look: look, colorTheme: theme, textScale: textScale, seed: (fs) async {
    await _seed(fs);
    await ph7SeedProducts(fs);
  });
  _shell.currentState!.openInContent(build(store), highlight: AppDestination.sales);
  await ph5Settle(tester);
}

AppColors _colors(WidgetTester tester, Type type) => Theme.of(tester.element(find.byType(type))).extension<AppColors>()!;

Iterable<String> _texts(WidgetTester tester, Finder scope) =>
    find.descendant(of: scope, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data ?? '');

void main() {
  for (final (size, sidebar) in _shapes) {
    final content = (size.width - sidebar).toInt();
    for (final look in const [MatrixLook.light, MatrixLook.dark, MatrixLook.kiswahili]) {
      for (final theme in AppColorTheme.all) {
        final where = 'content $content ${look.name} ${theme.id} text 1.3';

        ph5TestWidgets('Sales, $where: three sales-only cards, no Collected', (tester) async {
          await _open(tester, (fs) => SalesScreen(firestore: fs), size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull, reason: where);
          final cards = find.byType(FlatStatCard);
          expect(cards, findsNWidgets(3), reason: where);
          final values = [for (final e in cards.evaluate()) (e.widget as FlatStatCard).value];
          // Total Sales, Revenue, Pending: sales only (no 777,000 service,
          // no 55,000 other income).
          expect(values, ['2', Money.format(30000), Money.format(10000)], reason: where);
          if (look != MatrixLook.kiswahili) expect(find.text('Collected'), findsNothing);
        });

        ph5TestWidgets('Payments, $where: three-row cards; a Date column, no day headers', (tester) async {
          await _open(tester, (fs) => PaymentsScreen(firestore: fs), size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull, reason: where);
          final today = find.byType(FlatStatCard).first;
          final card = tester.widget<FlatStatCard>(today);
          expect(card.footer, isNull, reason: 'no fourth row');
          expect(card.valueTrailing, isA<StatusDot>(), reason: 'the trend beside the value');
          final value = tester.getRect(find.descendant(of: today, matching: find.text(card.value)));
          final trend = tester.getRect(find.descendant(of: today, matching: find.byType(StatusDot)));
          // At text 1.3 the four cards can be too narrow for both: the trend
          // then wraps under the value (no overflow); beside it at 1.0 below.
          expect(trend.top, greaterThanOrEqualTo(value.top - 1), reason: where);
          final screen = find.byType(PaymentsScreen);
          final texts = _texts(tester, screen).toList();
          expect(texts, contains(AppDateFormat.dateTime12.format(ph5When(0, minutes: 5))), reason: where);
          // The old header read "Today - dd Mon yyyy" (the toolbar's range
          // "from - to" is not a header).
          final l = lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'));
          expect(texts.where((t) => t.startsWith('${l.common_today} - ') || t.startsWith('${l.common_yesterday} - ')), isEmpty,
              reason: 'no day header');
        });

        ph5TestWidgets('Transactions, $where: a Date column, no day headers; arrows coloured, signs kept', (tester) async {
          await _open(tester, (fs) => TransactionScreen(firestore: fs), size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull, reason: where);
          final screen = find.byType(TransactionScreen);
          final c = _colors(tester, TransactionScreen);
          final texts = _texts(tester, screen).toList();
          expect(texts, contains(AppDateFormat.dateTime12.format(ph5When(0, minutes: 9))), reason: where);
          expect(texts.where((t) => t.startsWith('Total: ') || t.startsWith('Jumla')), isEmpty, reason: 'no day totals');
          expect(texts.any((t) => t.startsWith('+') && t.contains('6,000')), isTrue, reason: 'income keeps +');
          expect(texts.any((t) => t.startsWith('-') && t.contains('3,000')), isTrue, reason: 'expense keeps -');
          final down = tester.widgetList<Icon>(find.descendant(of: screen, matching: find.byIcon(Icons.arrow_downward)));
          final up = tester.widgetList<Icon>(find.descendant(of: screen, matching: find.byIcon(Icons.arrow_upward)));
          expect(down, isNotEmpty);
          expect(up, isNotEmpty);
          for (final i in down) {
            expect(i.color, c.success, reason: 'income: success');
          }
          for (final i in up) {
            expect(i.color, c.textSecondary, reason: 'expense: neutral, not red');
          }
        });

        ph5TestWidgets('Clients, $where: Active success, Inactive neutral', (tester) async {
          await _open(tester, (fs) => ClientsScreen(firestore: fs), size, sidebar, look: look, theme: theme, textScale: 1.3);
          expect(tester.takeException(), isNull, reason: where);
          final dots = tester.widgetList<StatusDot>(find.descendant(of: find.byType(ClientsScreen), matching: find.byType(StatusDot))).toList();
          expect(dots.where((d) => d.status == AppStatus.success), hasLength(1), reason: 'Amina Juma, Active');
          expect(dots.where((d) => d.status == AppStatus.neutral), hasLength(1), reason: 'Juma Said, Inactive');
        });
      }
    }

    ph5TestWidgets('Payments, content $content text 1.0: the trend beside the value (three rows)', (tester) async {
      await _open(tester, (fs) => PaymentsScreen(firestore: fs), size, sidebar);
      expect(tester.takeException(), isNull);
      final today = find.byType(FlatStatCard).first;
      final card = tester.widget<FlatStatCard>(today);
      final value = tester.getRect(find.descendant(of: today, matching: find.text(card.value)));
      final trend = tester.getRect(find.descendant(of: today, matching: find.byType(StatusDot)));
      expect(trend.left, greaterThan(value.right - 1), reason: 'to the right of the value');
      expect((trend.center.dy - value.center.dy).abs(), lessThan(value.height), reason: 'on the value row');
    });

    for (final (name, build, type) in [
      ('Products', (FirebaseFirestore fs) => const ProductsScreen(), ProductsScreen),
      ('Stock Store', (FirebaseFirestore fs) => const StockStoreScreen(), StockStoreScreen),
    ]) {
      ph5TestWidgets('$name, content $content: the filter panel has no facility name', (tester) async {
        await _open(tester, build, size, sidebar, textScale: 1.3);
        expect(tester.takeException(), isNull);
        final panel = find.byType(ProductCatalogSidePanel);
        if (panel.evaluate().isEmpty) {
          // Below 900 the panel is the drawer: open it.
          final scaffold = tester.state<ScaffoldState>(find.descendant(of: find.byType(type), matching: find.byType(Scaffold)).first);
          scaffold.openDrawer();
          await tester.pumpAndSettle();
        }
        expect(panel, findsOneWidget);
        expect(find.descendant(of: panel, matching: find.text('Kilimo Agrovet')), findsNothing);
        expect(find.descendant(of: panel, matching: find.byIcon(Icons.storefront)), findsNothing);
      });
    }
  }
}
