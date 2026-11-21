// LAY6a: Clients and Debtors inside AppShell over a seeded fake Firestore,
// at windows 768, 1024 and 1200 with the sidebar open and collapsed (content
// 696, 774, 952, 950, 1128), text 1.3, Light and Dark in every theme, and
// Kiswahili: no overflow with the list and then a record's details open; the
// place highlighted beside the sidebar, no back arrow; the details inline
// from 900 of the content, a slide-over below it (closed by the dimmed list
// and by its own close button, the list still there). Back pops inside,
// then Home, which is told to refresh. The overdue filter and the search
// and notification entries open inside the shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/notification_targets.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _clients = [
  Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer', 'Vet'], balance: 45000, oldestDebt: ph5When(45)),
  Ph5Client('c2', matrixLongClientName, ph5When(0, minutes: 30), types: ['Retailer'], balance: matrixBigAmount, oldestDebt: ph5When(3)),
  Ph5Client('c3', 'Baraka Mushi', ph5When(0, minutes: 60), status: 'Inactive', balance: 12500, oldestDebt: ph5When(10)),
];

final _debts = [
  Ph5Debt('d1', 'c3', ph5When(10), 12500),
  Ph5Debt('d2', 'c1', ph5When(45), 45000),
];

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, _clients);
  await ph5SeedDebts(fs, _debts);
}

final _shell = GlobalKey<AppShellState>();
dynamic _fs;
final _returned = <AppDestination>[];

Widget _harness(dynamic fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in [AppDestination.home, AppDestination.clients, AppDestination.debtors])
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
          AppDestination.clients => ClientsScreen(firestore: fs),
          AppDestination.debtors => DebtorsScreen(firestore: fs),
          _ => null,
        },
        onOpenFullScreen: (_) async {},
        onReturnedHome: _returned.add,
      ),
    );

Type _typeOf(AppDestination d) => d == AppDestination.clients ? ClientsScreen : DebtorsScreen;

/// The row to open: present on both lists.
const _row = 'Amina Juma';

Future<void> _open(WidgetTester tester, AppDestination d) async {
  _shell.currentState!.select(d);
  await ph5Settle(tester);
}

Future<void> _openRow(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_row).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_row).last);
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
  // Light and Dark in every theme, and Kiswahili (pasture, light).
  final looks = [
    for (final theme in AppColorTheme.all)
      for (final look in const [MatrixLook.light, MatrixLook.dark]) (theme, look),
    (AppColorTheme.pasture, MatrixLook.kiswahili),
  ];

  for (final (size, sidebar) in layouts) {
    final content = size.width - sidebar;
    final inline = content >= AppBreakpoints.medium;
    for (final (theme, look) in looks) {
      for (final d in const [AppDestination.clients, AppDestination.debtors]) {
        final name = '${d.name} at content ${content.toInt()} ${theme.id} ${look.name} text 1.3';
        ph5TestWidgets('$name: list and details without overflow; details ${inline ? 'inline' : 'slide over'}',
            (tester) async {
          await pumpPh5(tester, (fs) { _fs = fs; return _harness(fs, sidebar); },
              size: size, look: look, colorTheme: theme, textScale: 1.3, seed: _seed);
          await _open(tester, d);
          expect(tester.takeException(), isNull, reason: 'the list');
          final screen = find.byType(_typeOf(d));
          expect(tester.getTopLeft(screen).dx, sidebar, reason: 'beside the sidebar');
          expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget);
          expect(find.byType(BackButton), findsNothing, reason: 'top level: no back arrow');

          await _openRow(tester);
          expect(tester.takeException(), isNull, reason: 'the details');
          if (inline) {
            expect(_slideOver, findsNothing);
            expect(find.byType(VerticalDivider), findsOneWidget, reason: 'beside the list');
          } else {
            expect(_slideOver, findsOneWidget);
            final panel = tester.getRect(_slideOver);
            expect(panel.right, size.width, reason: 'from the right edge');
            expect(find.text(_row), findsWidgets, reason: 'the list stays under it');
            // The dimmed list closes it.
            await tester.tapAt(Offset(sidebar + 8, panel.center.dy));
            await ph5Settle(tester);
            expect(_slideOver, findsNothing);
            // Open again; the panel's own close button closes it.
            await _openRow(tester);
            await tester.tap(find.descendant(of: _slideOver, matching: find.byIcon(Icons.close)).first);
            await ph5Settle(tester);
            expect(_slideOver, findsNothing);
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  for (final d in const [AppDestination.clients, AppDestination.debtors]) {
    ph5TestWidgets('${d.name}: Back pops inside, then Home, and Home is told to refresh per the registry',
        (tester) async {
      await pumpPh5(tester, (fs) { _fs = fs; return _harness(fs, 250); }, size: const Size(1200, 800), seed: _seed);
      await _open(tester, d);
      await tester.binding.handlePopRoute();
      await ph5Settle(tester);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
      expect(_returned, [d]);
      // The registry: Home refreshes after Debtors, not after Clients (as before LAY2).
      expect(d.refreshHomeOnReturn, d == AppDestination.debtors);
    });
  }

  ph5TestWidgets('Debtors with the Overdue filter, opened in the shell, keeps its filter', (tester) async {
    await pumpPh5(tester, (fs) { _fs = fs; return _harness(fs, 250); }, size: const Size(1200, 800), seed: _seed);
    _shell.currentState!.openInContent(DebtorsScreen(initialStatus: DebtorsScreen.statusOverdue, firestore: _fs),
        highlight: AppDestination.debtors);
    await ph5Settle(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(DebtorsScreen)))!;
    expect(find.text(l10n.common_filterValue(l10n.common_status, l10n.debtors_overdue)), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-debtors-selected')), findsOneWidget);
  });

  ph5TestWidgets('the client search result and a client notification open Clients in the shell', (tester) async {
    await pumpPh5(tester, (fs) { _fs = fs; return _harness(fs, 250); }, size: const Size(1200, 800), seed: _seed);
    _shell.currentState!.openInContent(ClientsScreen(firestore: _fs), highlight: AppDestination.clients);
    await ph5Settle(tester);
    expect(find.byType(ClientsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-clients-selected')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.text('HOME'), findsOneWidget, reason: 'Back returns where you were');
  });

  test('a notification about a client names Clients, a payment Payments (LAY6b); others no shell place', () {
    FacilityNotification n(String type) => FacilityNotification(
        id: 'n1', type: NotificationType.general, title: 't', message: 'm', relatedEntityType: type, relatedEntityId: 'x1');
    expect(notificationTargetPlace(n('client')), AppDestination.clients);
    expect(notificationTargetPlace(n('payment')), AppDestination.payments);
    expect(notificationTargetPlace(n('service')), AppDestination.services); // LAY6d
    expect(notificationTargetPlace(n('assistant')), AppDestination.settings); // LAY7: Settings > Business > Team
    for (final other in ['product']) {
      expect(notificationTargetPlace(n(other)), isNull, reason: other);
    }
  });
}
