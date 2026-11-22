// UX4 (3): a PageHeader's actions end at its right padding on every PC and
// tablet screen, a Flexible action among them or not. Transactions' date
// range (a Flexible) used to leave its unused share after the buttons, so
// they sat left of the edge (the bug the top bar had in UX1a). The places in
// the shell, Transactions and View Reports included, and the archives pushed
// above one (the receipts have no header actions), at windows 768, 1024, 1200 and
// 1920 with the sidebar open (250; at 768 only the 72 rail) and collapsed (72); English at text 1 and
// 1.3, Kiswahili at 1.3. The layout itself: the range still gives way first
// in a narrow bar, as wide as it was in the Row.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_archive_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/screens/services/services_archive_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'pol4_fingerprints_test.dart' show seedPol4Archives;

final _shell = GlobalKey<AppShellState>();

/// The places (top level in the shell) and the pages pushed above one.
final _screens = <String, (Widget Function(FirebaseFirestore fs), bool)>{
  'sales': ((fs) => SalesScreen(firestore: fs), true),
  'services': ((fs) => ServicesScreen(firestore: fs), true),
  'clients': ((fs) => ClientsScreen(firestore: fs), true),
  'debtors': ((fs) => DebtorsScreen(firestore: fs), true),
  'payments': ((fs) => PaymentsScreen(firestore: fs), true),
  'transactions': ((fs) => TransactionScreen(firestore: fs), true),
  'products': ((_) => ProductsScreen(), true),
  'stock store': ((_) => StockStoreScreen(), true),
  'view reports': ((fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()), true),
  'sales archive': ((fs) => SalesArchiveScreen(firestore: fs), false),
  'services archive': ((fs) => ServicesArchiveScreen(firestore: fs), false),
};

Widget _harness(Widget Function(FirebaseFirestore fs) build, FirebaseFirestore fs, double sidebar, bool place) =>
    Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(width: sidebar),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => place && d == AppDestination.sales ? build(fs) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

/// The right edge of [header]'s last action (a Flexible's child).
double _actionsRight(WidgetTester tester, Finder header) {
  final last = tester.widget<PageHeader>(header).actions.last;
  return tester.getTopRight(find.byWidget(last is Flexible ? last.child : last)).dx;
}

void main() {
  for (final width in const [768.0, 1024.0, 1200.0, 1920.0]) {
    // At 768 the sidebar is always the 72 rail (below expanded), never open.
    for (final sidebar in width < 1000 ? const [72.0] : const [250.0, 72.0]) {
      for (final (look, textScale) in const [
        (MatrixLook.light, 1.0),
        (MatrixLook.light, 1.3),
        (MatrixLook.kiswahili, 1.3),
      ]) {
        for (final MapEntry(key: name, value: (build, place)) in _screens.entries) {
          final size = Size(width, width < 1000 ? 1024 : 800);
          ph5TestWidgets(
            '$name at ${width.toInt()}, sidebar ${sidebar.toInt()}, ${look.name} text $textScale: actions end at the right padding',
            (tester) async {
              late FirebaseFirestore store;
              await pumpPh5(
                tester,
                (fs) {
                  store = fs;
                  return _harness(build, fs, sidebar, place);
                },
                size: size,
                look: look,
                textScale: textScale,
                seed: seedPol4Archives,
              );
              if (place) {
                _shell.currentState!.select(AppDestination.sales);
              } else {
                _shell.currentState!.openInContent(build(store), highlight: AppDestination.sales);
              }
              await ph5Settle(tester);
              // Body overflows are other screens' items (the archives', POL4;
              // a 518 content below the 600 the shell gives every page); this
              // checks the header only.
              for (var e = tester.takeException(); e != null; e = tester.takeException()) {
                expect(e.toString(), contains('overflowed'), reason: '$name: $e');
              }
              final header = find.byType(PageHeader);
              expect(header, findsOneWidget);
              expect(tester.widget<PageHeader>(header).actions, isNotEmpty);
              expect(
                _actionsRight(tester, header),
                moreOrLessEquals(tester.getTopRight(header).dx - AppSpacing.s4),
                reason: 'the last action ends at the right padding',
              );
            },
          );
        }
      }
    }
  }

  group('the layout with a Flexible action', () {
    Future<void> pump(WidgetTester tester, double width, double rangeNatural) async {
      await pumpPh5(
        tester,
        (_) => Scaffold(
          appBar: PageHeader(
            title: 'T',
            actions: [
              Flexible(
                child: Container(
                  key: const ValueKey('range'),
                  constraints: BoxConstraints(maxWidth: rangeNatural),
                  height: AppSpacing.s10,
                ),
              ),
              const SizedBox(key: ValueKey('record'), width: 50, height: AppSpacing.s10),
            ],
          ),
        ),
        size: Size(width, 800),
      );
    }

    const inner = PolishMetrics.pagePadding + AppSpacing.s4;

    ph5TestWidgets('room to spare: the range at its size, the buttons at the right padding', (tester) async {
      await pump(tester, 900, 120);
      expect(tester.getSize(find.byKey(const ValueKey('range'))).width, 120);
      expect(tester.getTopRight(find.byKey(const ValueKey('record'))).dx, 900 - AppSpacing.s4);
      expect(tester.getTopLeft(find.byKey(const ValueKey('range'))).dx, 900 - AppSpacing.s4 - 50 - 120);
    });

    ph5TestWidgets('a narrow bar: the range gives way first, to its share as in the Row', (tester) async {
      await pump(tester, 400, 1000);
      // The Row's split: the title and the range share what the 50 leaves.
      const share = (400 - inner - 50) / 2;
      expect(tester.getSize(find.byKey(const ValueKey('range'))).width, moreOrLessEquals(share));
      expect(tester.getTopRight(find.byKey(const ValueKey('record'))).dx, 400 - AppSpacing.s4);
      expect(tester.takeException(), isNull);
    });
  });
}
