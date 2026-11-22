// PAGE1: the Activity Log on PC/tablet pages on the server inside the
// retention window (no 500-row stream, no whole-window stream for chips).
// An assistant's two questions (what they did, what is about them) are
// merged by cursor, an entry in both shown once. The category filter is off
// with a note (its indexes: docs/PAGE1_INDEXES.md); the search says it looks
// at this page. The phone keeps its streams (ph8a_activity_phone_test).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/page1_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/test_clock.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

const _wide = Size(1600, 900);

/// [count] entries an hour apart (e00 newest). Even ones were done by the
/// signed-in person, every third one is about them (e00, e06... are both),
/// the rest by someone else. One more entry is outside the 90-day window.
Future<void> _seed(FirebaseFirestore fs, {int count = 30}) async {
  final logs = facilityCollection(fs, Collections.activityLogs);
  for (var i = 0; i < count; i++) {
    await logs.doc('e${i.toString().padLeft(2, '0')}').set({
      'timestamp': Timestamp.fromDate(testNow.subtract(Duration(hours: i + 1))),
      'userId': i.isEven ? testUserId : 'admin2',
      'userName': i.isEven ? 'Asha Mushi' : 'Juma Hassan',
      'actionType': 'Sales',
      'description': 'Entry $i',
      if (i % 3 == 0) 'targetUserId': testUserId,
    });
  }
  await logs.doc('old').set({
    'timestamp': Timestamp.fromDate(testNow.subtract(const Duration(days: 120))),
    'userId': testUserId,
    'userName': 'Asha Mushi',
    'actionType': 'Sales',
    'description': 'Too old',
  });
}

Future<CountingFirestore> _open(WidgetTester tester,
    {bool admin = true, int count = 30, Size size = _wide, MatrixLook look = MatrixLook.light, double textScale = 1, CountingFirestore? db}) async {
  final store = db ?? CountingFirestore();
  await tester.runAsync(() => _seed(store.inner, count: count));
  await pumpPh5(tester, (fs) => ActivityLogScreen(isModal: true, firestore: fs, auth: Ph8Auth()),
      size: size, admin: admin, pushed: true, firestore: store, look: look, textScale: textScale);
  await ph5Settle(tester);
  return store;
}

void main() {
  ph5TestWidgets('admin: page 1, Next, Previous; the last page has no Next; nothing outside the window', (tester) async {
    final db = await _open(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(find.text('Entry 0'), findsOneWidget);
    db.resetCounts();
    await page1Next(tester);
    expect(db.reads, lessThanOrEqualTo(26));
    expect(page1Range(tester), 'Showing 26 to 30');
    expect(page1NextEnabled(tester), isFalse);
    expect(find.text('Too old'), findsNothing);
    db.resetCounts();
    await page1Previous(tester);
    expect(db.reads, 0);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('assistant: their own and about-them entries merged, each once, newest first', (tester) async {
    await _open(tester, admin: false);
    // Theirs: the 15 even entries plus the odd multiples of 3 (3, 9, 15, 21, 27).
    expect(page1BarWidget(tester).itemCount, 20);
    expect(page1Range(tester), 'Showing 1 to 20');
    expect(find.text('Entry 1'), findsNothing, reason: 'someone else\'s, not about them');
    expect(find.text('Entry 0'), findsOneWidget, reason: 'theirs and about them: once');
    expect(page1NextEnabled(tester), isFalse);
  });

  ph5TestWidgets('page size goes back to page 1', (tester) async {
    await _open(tester);
    await page1Next(tester);
    await page1PageSize(tester, 10);
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 10');
  });

  ph5TestWidgets('the category filter is off with a note; the search says it looks at this page', (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('activity-categoryUnavailable')), findsOneWidget);
    expect(find.text('Filter by category: not available yet'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.enterText(find.byType(TextField), 'Entry 1');
    await ph5Settle(tester);
    Finder row(String t) => find.descendant(of: find.byKey(const ValueKey('activity-table')), matching: find.text(t));
    expect(row('Entry 1'), findsOneWidget);
    expect(row('Entry 10'), findsOneWidget);
    expect(row('Entry 2'), findsNothing);
    expect(find.text('Search this page...'), findsOneWidget);
  });

  ph5TestWidgets('empty: the empty state', (tester) async {
    await _open(tester, count: 0);
    expect(find.text('No activity logs found'), findsWidgets);
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

  ph5TestWidgets('the skeleton while the page loads', (tester) async {
    final db = CountingFirestore()..holdGets = Completer<void>();
    await _open(tester, db: db);
    expect(find.byKey(const ValueKey('pagedList-skeleton')), findsOneWidget);
    db.holdGets!.complete();
    db.holdGets = null;
    await ph5Settle(tester);
    expect(page1Range(tester), 'Showing 1 to 25');
  });

  ph5TestWidgets('reads on open: one page (pageSize + 1), no live list (it streamed up to 500 + the window)', (tester) async {
    final db = await _open(tester);
    // + the facility (retention), the app's own setup and the admin's
    // expired-entries tidy-up (its own bounded query: the old entry).
    expect(db.listeners, lessThanOrEqualTo(1), reason: 'only the app\'s role listener');
    // ignore: avoid_print
    print('PAGE1 Activity open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    expect(db.reads, lessThanOrEqualTo(26 + 1 + 1 + 2));
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
