// PAGE1: Transactions on PC/tablet pages on the server (the shared pager and
// ListPageBar): page 1, Next, Previous, page size, a filter back to page 1,
// the last page, empty, an error with Retry, the skeleton, a save on top of
// page 1, the reads, and the widths and text sizes. The phone keeps its own
// list (ph5b_transactions_phone_test).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetbiz_pro/models/transaction.dart';
import 'package:vetbiz_pro/providers/transaction_provider.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _wide = Size(1600, 900);

// 30 inside the default range (newest first: m0 .. m29), every type.
final _many = [
  for (var i = 0; i < 30; i++)
    Ph5Tx('m${i.toString().padLeft(2, '0')}', ph5When(i ~/ 6, minutes: 59 - i),
        type: i.isEven ? 'expense' : 'other income', description: 'Item $i', amount: 1000, receipt: 10 + i),
];

Future<CountingFirestore> _open(WidgetTester tester, {Size size = _wide, List<Ph5Tx>? txs, MatrixLook look = MatrixLook.light, double textScale = 1, bool settle = true, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  await tester.runAsync(() => ph5SeedTransactions(store.inner, txs ?? _many));
  await pumpPh5(tester, (fs) => TransactionScreen(firestore: fs),
      size: size, pushed: true, firestore: store, look: look, textScale: textScale, settle: settle);
  return store;
}

void main() {
  ph5TestWidgets('page 1, Next, Previous; the last page has no Next; Previous reads nothing', (tester) async {
    final db = await _open(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Load more transactions'), findsNothing);
    expect(page1PreviousEnabled(tester), isFalse);
    expect(page1NextEnabled(tester), isTrue);

    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(26), reason: 'Next reads one page and one row');
    expect(page1Range(tester), 'Showing 26 to 30');
    expect(page1NextEnabled(tester), isFalse);

    db.resetCounts();
    await page1Previous(tester);
    expect(db.reads, 0);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('page size and the type filter go back to page 1, filtered on the server', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await page1PageSize(tester, 10);
    expect(page1Range(tester), 'Showing 1 to 10');
    expect(page1BarWidget(tester).currentPage, 1);

    await page1Next(tester);
    expect(page1BarWidget(tester).currentPage, 2);
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type: Expense').last);
    await ph5Settle(tester);
    expect(page1BarWidget(tester).currentPage, 1);
    final provider = Provider.of<TransactionProvider>(tester.element(find.byType(TransactionScreen)), listen: false);
    expect(provider.transactionsListController.items.every((t) => t.type == 'expense'), isTrue);
    expect(page1Range(tester), 'Showing 1 to 10');
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 11 to 15', reason: '15 expenses in all, across pages not loaded before');
  });

  ph5TestWidgets('empty: the empty text and the bar says none', (tester) async {
    await _open(tester, txs: const []);
    expect(find.text('No transactions.'), findsWidgets);
    expect(page1NextEnabled(tester), isFalse);
  });

  ph5TestWidgets('an error shows the message and Retry; Retry loads the page', (tester) async {
    final db = CountingFirestore()..failGets = true;
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-error')), findsOneWidget);
    db.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('the skeleton while the page loads, no spinner; the page after', (tester) async {
    final db = CountingFirestore()..holdGets = Completer<void>();
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsOneWidget);
    expect(find.descendant(of: page1Bar, matching: find.byType(CircularProgressIndicator)), findsNothing);
    db.holdGets!.complete();
    db.holdGets = null;
    await ph5Settle(tester);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsNothing);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('a saved transaction is on top of page 1', (tester) async {
    // The plain fake (a save runs a Firestore transaction for its receipt number).
    await pumpPh5(tester, (fs) => TransactionScreen(firestore: fs),
        size: _wide, pushed: true, seed: (fs) => ph5SeedTransactions(fs, _many));
    await page1Next(tester);
    final provider = Provider.of<TransactionProvider>(tester.element(find.byType(TransactionScreen)), listen: false);
    await tester.runAsync(() => provider.addTransaction(
        TransactionModel(id: '', date: ph5When(0), description: 'Brand new', amount: 500, type: 'expense', category: 'Fuel', recordedBy: 'Asha'),
        'facility1'));
    await ph5Settle(tester);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(provider.transactionsListController.items.first.description, 'Brand new');
  });

  ph5TestWidgets('reads on open: the page (pageSize + 1) and the cards\' daily totals; no live listener', (tester) async {
    final db = await _open(tester);
    // The cards read one daily-total document per day seeded (5 days); the
    // one more is the app's own setup (the signed-in user's document).
    expect(db.reads, lessThanOrEqualTo(26 + 5 + 1));
    expect(db.listeners, 1, reason: 'only the app\'s role listener; the live window is the phone\'s only');
    // ignore: avoid_print
    print('PAGE1 Transactions open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
  });

  for (final size in page1Widths) {
    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('${size.width.toInt()} ${look.name} text $scale: the page and the bar, no overflow', (tester) async {
        await _open(tester, size: size, look: look, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(page1Bar, findsOneWidget);
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
