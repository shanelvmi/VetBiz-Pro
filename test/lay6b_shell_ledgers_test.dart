// LAY6b: Payments and Transactions inside AppShell over a seeded fake
// Firestore, at windows 768, 1024 and 1200 with the sidebar open and
// collapsed (content 696, 774, 952, 950, 1128), text 1.3, Light and Dark in
// every theme, and Kiswahili: no overflow with the list and then a record's
// details open; the place highlighted beside the sidebar, no back arrow; the
// details inline from 900 of the content, a slide-over below it (closed by
// the dimmed list and by its close button). Back pops inside, then Home,
// which is told to refresh. Debtors' payment history opens Payments with its
// client inside the shell, Debtors still highlighted; a payment notification
// opens Payments in the shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, [
    Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), balance: 45000, oldestDebt: ph5When(45)),
    Ph5Client('c3', 'Baraka Mushi', ph5When(0, minutes: 60), balance: 12500, oldestDebt: ph5When(10)),
  ]);
  await ph5SeedDebts(fs, [Ph5Debt('d1', 'c3', ph5When(10), 12500), Ph5Debt('d2', 'c1', ph5When(45), 45000)]);
  await ph5SeedPayments(fs, [
    Ph5Payment('p1', ph5When(0, minutes: 5), client: 'Amina Juma', clientId: 'c1', amount: 20000, method: 'mpesa'),
    Ph5Payment('p2', ph5When(0, minutes: 40), client: matrixLongClientName, clientId: 'c2', amount: matrixBigAmount),
    Ph5Payment('p3', ph5When(0, minutes: 90), client: 'Baraka Mushi', clientId: 'c3', amount: 7000, source: 'debt_repayment'),
  ]);
  await ph5SeedTransactions(fs, [
    Ph5Tx('t1', ph5When(0, minutes: 5), description: 'Fuel for the car', amount: 30000, receipt: 1),
    Ph5Tx('t2', ph5When(0, minutes: 50), type: 'other income', category: 'Consultation', description: matrixLongClientName, amount: matrixBigAmount, receipt: 2),
    Ph5Tx('t3', ph5When(3), category: 'Rent', description: 'Rent for November', amount: 150000, method: 'mpesa', receipt: 3),
  ]);
}

final _shell = GlobalKey<AppShellState>();
final _returned = <AppDestination>[];
dynamic _fs;

Widget _harness(dynamic fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in [AppDestination.home, AppDestination.debtors, AppDestination.payments, AppDestination.transactions])
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
          AppDestination.debtors => DebtorsScreen(firestore: fs),
          AppDestination.payments => PaymentsScreen(firestore: fs),
          AppDestination.transactions => TransactionScreen(firestore: fs),
          _ => null,
        },
        onOpenFullScreen: (_) async {},
        onReturnedHome: _returned.add,
      ),
    );

Future<void> _pump(WidgetTester tester, Size size, double sidebar,
    {MatrixLook look = MatrixLook.light, AppColorTheme theme = AppColorTheme.pasture, double scale = 1}) =>
    pumpPh5(tester, (fs) {
      _fs = fs;
      return _harness(fs, sidebar);
    }, size: size, look: look, colorTheme: theme, textScale: scale, seed: _seed);

Type _typeOf(AppDestination d) => d == AppDestination.payments ? PaymentsScreen : TransactionScreen;
String _rowOf(AppDestination d) => d == AppDestination.payments ? 'Baraka Mushi' : 'Rent for November';

Future<void> _open(WidgetTester tester, AppDestination d) async {
  _shell.currentState!.select(d);
  await ph5Settle(tester);
}

Future<void> _openRow(WidgetTester tester, String row) async {
  await tester.ensureVisible(find.text(row).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(row).last);
  await ph5Settle(tester);
}

final _slideOver = find.byKey(const ValueKey('details-slide-over'));

void main() {
  setUp(_returned.clear);

  const layouts = [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1024, 768), 72.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ];
  final looks = [
    for (final theme in AppColorTheme.all)
      for (final look in const [MatrixLook.light, MatrixLook.dark]) (theme, look),
    (AppColorTheme.pasture, MatrixLook.kiswahili),
  ];

  for (final (size, sidebar) in layouts) {
    final content = size.width - sidebar;
    final inline = content >= AppBreakpoints.medium;
    for (final (theme, look) in looks) {
      for (final d in const [AppDestination.payments, AppDestination.transactions]) {
        final name = '${d.name} at content ${content.toInt()} ${theme.id} ${look.name} text 1.3';
        ph5TestWidgets('$name: list and details without overflow; details ${inline ? 'inline' : 'slide over'}',
            (tester) async {
          await _pump(tester, size, sidebar, look: look, theme: theme, scale: 1.3);
          await _open(tester, d);
          expect(tester.takeException(), isNull, reason: 'the list');
          final screen = find.byType(_typeOf(d));
          expect(tester.getTopLeft(screen).dx, sidebar, reason: 'beside the sidebar');
          expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget);
          expect(find.byType(BackButton), findsNothing, reason: 'top level: no back arrow');

          await _openRow(tester, _rowOf(d));
          expect(tester.takeException(), isNull, reason: 'the details');
          if (inline) {
            expect(_slideOver, findsNothing);
            expect(find.byType(VerticalDivider), findsOneWidget, reason: 'beside the list');
          } else {
            expect(_slideOver, findsOneWidget);
            final panel = tester.getRect(_slideOver);
            expect(panel.right, size.width, reason: 'from the right edge');
            await tester.tapAt(Offset(sidebar + 8, panel.center.dy));
            await ph5Settle(tester);
            expect(_slideOver, findsNothing, reason: 'the dimmed list closes it');
            await _openRow(tester, _rowOf(d));
            await tester.tap(find.descendant(of: _slideOver, matching: find.byIcon(Icons.close)).first);
            await ph5Settle(tester);
            expect(_slideOver, findsNothing, reason: 'its close button closes it');
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  for (final d in const [AppDestination.payments, AppDestination.transactions]) {
    ph5TestWidgets('${d.name}: Back pops inside, then Home, and Home is told to refresh', (tester) async {
      await _pump(tester, const Size(1200, 800), 250);
      await _open(tester, d);
      await tester.binding.handlePopRoute();
      await ph5Settle(tester);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
      expect(_returned, [d]);
      expect(d.refreshHomeOnReturn, isTrue, reason: 'the registry: Home refreshes after both');
    });
  }

  ph5TestWidgets('Debtors -> payment history: Payments with the client, inside the shell, Debtors highlighted',
      (tester) async {
    await _pump(tester, const Size(1200, 800), 250);
    await _open(tester, AppDestination.debtors);
    await tester.tap(find.byTooltip('Payment History').first);
    await ph5Settle(tester);
    final payments = tester.widget<PaymentsScreen>(find.byType(PaymentsScreen));
    expect(payments.initialClientId, isNotNull, reason: 'the client prefilter');
    expect(tester.getTopLeft(find.byType(PaymentsScreen)).dx, 250, reason: 'inside the content area');
    expect(find.byKey(const ValueKey('sb-debtors-selected')), findsOneWidget, reason: 'pushed above Debtors');
    expect(find.byType(BackButton), findsOneWidget, reason: 'a screen above a place keeps its back arrow');
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.byType(DebtorsScreen), findsOneWidget, reason: 'Back returns to Debtors');
  });

  ph5TestWidgets('a payment notification opens Payments in the shell, Payments highlighted', (tester) async {
    await _pump(tester, const Size(1200, 800), 250);
    // What the bell's openPlace does for a target whose place is Payments.
    _shell.currentState!.openInContent(PaymentsScreen(firestore: _fs), highlight: AppDestination.payments);
    await ph5Settle(tester);
    expect(find.byType(PaymentsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-payments-selected')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.text('HOME'), findsOneWidget, reason: 'Back returns where you were');
  });
}
