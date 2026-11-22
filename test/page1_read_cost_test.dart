// PAGE1 read-cost guard: with 120 records (far more than a page), opening
// each PC/tablet list reads one page (pageSize + 1, or 2 x (pageSize + 1) for
// the two merged lists) plus the documented small extras, and Next reads one
// page more. Before PAGE1 these read every record (Trash, Payments' range),
// 200 (Notifications), or up to 500 plus the whole window (Activity Log).
//
// Documented extras on open (docs/PAGING_AUDIT.md, PAGE1):
// - all: the app's own setup reads (the signed-in user, the facility).
// - Transactions: the cards' daily totals (one document per day in range).
// - Payments: 6 card aggregates, 2 range-total aggregates, 1 day snapshot.
// - Activity Log: the facility (retention) and the admin's expired tidy-up.
// - Notifications: my state document.
// - Trash: one count() for the expiring banner.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/notification_harness.dart' as n;
import 'helpers/page1_harness.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/test_clock.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_settings_wide_test.dart' show ph8UserInfo;

const _many = 120;
const _page = AppLimits.pageSize + 1;
const _wide = Size(1600, 900);

Future<void> _openAndNext(WidgetTester tester, CountingFirestore db, Widget Function(FirebaseFirestore) screen,
    {required int openMax, required int nextMax, required String name}) async {
  await pumpPh5(tester, screen, size: _wide, pushed: true, firestore: db);
  await ph5Settle(tester);
  final open = db.reads;
  db.resetCounts();
  await page1Next(tester);
  final next = db.reads;
  // ignore: avoid_print
  print('PAGE1 read cost $name ($_many records): open $open, Next $next');
  expect(open, lessThanOrEqualTo(openMax), reason: '$name: open');
  expect(next, lessThanOrEqualTo(nextMax), reason: '$name: Next');
  expect(page1Range(tester), 'Showing 26 to 50', reason: '$name: page 2');
}

void main() {
  ph5TestWidgets('Transactions', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() => ph5SeedTransactions(db.inner, [
          for (var i = 0; i < _many; i++) Ph5Tx('t$i', ph5When(i ~/ 30, minutes: i % 30), receipt: i + 1),
        ]));
    // + 4 days of daily totals, + the app's setup.
    await _openAndNext(tester, db, (fs) => TransactionScreen(firestore: fs), openMax: _page + 4 + 2, nextMax: _page, name: 'Transactions');
  });

  ph5TestWidgets('Payments (merged: 2 x (pageSize + 1))', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() async {
      await ph5SeedPayments(db.inner, [for (var i = 0; i < _many; i++) Ph5Payment('p$i', ph5When(0, minutes: i), client: 'C $i')]);
      await ph5SeedTransactions(db.inner,
          [for (var i = 0; i < 40; i++) Ph5Tx('o$i', ph5When(0, minutes: i), type: 'other income', receipt: i + 1)]);
    });
    await _openAndNext(tester, db, (fs) => PaymentsScreen(firestore: fs),
        openMax: 2 * _page + 6 + 2 + 1 + 3, nextMax: 2 * _page, name: 'Payments');
  });

  ph5TestWidgets('Activity Log', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() async {
      final logs = facilityCollection(db.inner, Collections.activityLogs);
      for (var i = 0; i < _many; i++) {
        await logs.doc('e$i').set({
          'timestamp': Timestamp.fromDate(testNow.subtract(Duration(minutes: i + 1))),
          'userId': 'u',
          'userName': 'U',
          'actionType': 'Sales',
          'description': 'Entry $i',
        });
      }
    });
    await _openAndNext(tester, db, (fs) => ActivityLogScreen(isModal: true, firestore: fs, auth: Ph8Auth()),
        openMax: _page + 1 + 2, nextMax: _page, name: 'Activity Log');
  });

  ph5TestWidgets('Trash', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() async {
      final trash = facilityCollection(db.inner, Collections.trashProducts);
      for (var i = 0; i < _many; i++) {
        await trash.doc('p$i').set({
          'name': 'P $i',
          'deletedAt': Timestamp.fromDate(testNow.subtract(Duration(minutes: i + 1))),
          'deletedBy': 'Asha',
        });
      }
    });
    await _openAndNext(tester, db, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
        openMax: _page + 1 + 1, nextMax: _page, name: 'Trash');
  });

  testWidgets('Notifications (the screen\'s own PC/tablet window: pageSize + 1)', (tester) async {
    final db = CountingFirestore();
    final c = (await tester.runAsync(() async {
      for (var i = 0; i < _many; i++) {
        await n.seed(db.inner, 'n$i', 'newClient', createdAt: n.t0.subtract(Duration(minutes: i + 1)), readAt: n.t0);
      }
      final c = n.newFeed(db, 'A', n.Clock(), window: _page)..start();
      await n.settle();
      return c;
    }))!;
    addTearDown(c.dispose);
    await n.pumpNotifications(tester, c, width: _wide.width, height: _wide.height);
    final open = db.reads;
    db.resetCounts();
    await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_right)));
    await tester.runAsync(n.settle);
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('PAGE1 read cost Notifications ($_many records): open $open, Next ${db.reads}');
    expect(open, lessThanOrEqualTo(_page + 1), reason: 'the live page and my state');
    expect(db.reads, lessThanOrEqualTo(_page));
    expect(page1Range(tester), 'Showing 26 to 50');
  });
}
