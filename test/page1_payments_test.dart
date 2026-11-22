// PAGE1: Payments on PC/tablet pages on the server: payments and other
// income merged newest first, one cursor per source (at most 2 x (pageSize +
// 1) reads a page, owner-approved); the toolbar Total and the cards cover the
// whole range by aggregates, never only the page. The phone keeps its
// whole-range ledger (ph5b_payments_phone_test).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _wide = Size(1600, 900);

// Today (the default range): 30 payments of 1,000 (half sales, half debt
// repayments) and 10 other income of 500, interleaved in time.
final _payments = [
  for (var i = 0; i < 30; i++)
    Ph5Payment('p${i.toString().padLeft(2, '0')}', ph5When(0, minutes: i * 4),
        client: 'Client $i', amount: 1000, source: i.isEven ? 'sale' : 'debt_repayment'),
];
final _income = [
  for (var i = 0; i < 10; i++)
    Ph5Tx('o$i', ph5When(0, minutes: i * 12 + 2), type: 'other income', description: 'Income $i', amount: 500, receipt: 100 + i),
];

Future<CountingFirestore> _open(WidgetTester tester,
    {Size size = _wide, bool empty = false, MatrixLook look = MatrixLook.light, double textScale = 1, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  if (!empty) {
    await tester.runAsync(() async {
      await ph5SeedPayments(store.inner, _payments);
      await ph5SeedTransactions(store.inner, _income);
    });
  }
  await pumpPh5(tester, (fs) => PaymentsScreen(firestore: fs),
      size: size, pushed: true, firestore: store, look: look, textScale: textScale);
  return store;
}

void main() {
  ph5TestWidgets('page 1 merges both sources newest first; Next, Previous; the last page has no Next', (tester) async {
    final db = await _open(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(find.text('Client 0'), findsOneWidget, reason: 'the newest payment');
    expect(find.text('Income 0'), findsOneWidget, reason: 'other income on the same page');

    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(2 * 26), reason: 'one page from each source, plus one row each');
    expect(page1Range(tester), 'Showing 26 to 40');
    expect(page1NextEnabled(tester), isFalse);

    db.resetCounts();
    await page1Previous(tester);
    expect(db.reads, 0);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('the toolbar Total covers the whole range (40 rows), not the page', (tester) async {
    await _open(tester);
    // 30 x 1,000 + 10 x 500, while the page shows 25 rows.
    expect(find.text('Total: ${Money.format(35000)}'), findsOneWidget);
    await page1PageSize(tester, 10);
    expect(find.text('Total: ${Money.format(35000)}'), findsOneWidget, reason: 'the page size does not change it');
  });

  ph5TestWidgets('the Today card counts every payment of the day (an aggregate), not the page', (tester) async {
    await _open(tester);
    expect(find.text(Money.format(30000)), findsWidgets, reason: 'Today: 30 payments of 1,000');
  });

  ph5TestWidgets('page size and the type filter go back to page 1, filtered on the server', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await page1PageSize(tester, 10);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 10');
    await page1Next(tester);
    await tester.tap(find.text('Type: All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type: Debt Repayments').last);
    await ph5Settle(tester);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(find.text('Income 0'), findsNothing);
    expect(find.text('Total: ${Money.format(15000)}'), findsOneWidget, reason: '15 debt repayments');
    await page1Next(tester);
    expect(page1Range(tester), 'Showing 11 to 15');
  });

  ph5TestWidgets('empty: the empty text', (tester) async {
    await _open(tester, empty: true);
    expect(find.text('No payments in this period.'), findsWidgets);
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

  ph5TestWidgets('the skeleton while the page loads, no spinner', (tester) async {
    final db = CountingFirestore()..holdGets = Completer<void>();
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsOneWidget);
    expect(find.descendant(of: page1Bar, matching: find.byType(CircularProgressIndicator)), findsNothing);
    db.holdGets!.complete();
    db.holdGets = null;
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('reads on open: a page from each source, the aggregates, no unbounded get', (tester) async {
    final db = await _open(tester);
    // 2 x 26 for the page; 6 card aggregates and 2 range-total aggregates;
    // 1 day snapshot; the app's own setup (user documents). Before PAGE1 this
    // read every payment of the last two months and every row of the range.
    expect(db.reads, lessThanOrEqualTo(2 * 26 + 6 + 2 + 1 + 3));
    // ignore: avoid_print
    print('PAGE1 Payments open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
  });

  for (final size in page1Widths) {
    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('${size.width.toInt()} ${look.name} text $scale: the page and the bar, no overflow', (tester) async {
        await _open(tester, size: size, look: look, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
