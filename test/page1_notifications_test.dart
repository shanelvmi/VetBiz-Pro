// PAGE1: Notifications on PC/tablet: the live listener watches the newest
// page (pageSize + 1: the screen's own feed, AppLimits.pageSize + 1, not 200)
// and Next fetches older ones by cursor, one page (pageSize + 1) at a time;
// no Load older. Page 1 keeps the unread first; older pages are newest
// first. The phone keeps its window, its pager and Load older
// (ph8a_notifications_phone_test, ux6 "phone keeps its bar").
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/widgets/list_page_bar.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/notification_harness.dart';
import 'helpers/page1_harness.dart';

/// [count] read notifications a minute apart (n00 newest).
Future<(CountingFirestore, NotificationFeedController)> _feed(WidgetTester tester, {int count = 60}) async {
  final db = CountingFirestore();
  final c = (await tester.runAsync(() async {
    for (var i = 0; i < count; i++) {
      await seed(db.inner, 'n${i.toString().padLeft(2, '0')}', 'newClient',
          createdAt: t0.subtract(Duration(minutes: i + 1)), readAt: t0);
    }
    final c = newFeed(db, 'A', Clock(), window: AppLimits.pageSize + 1, olderPage: AppLimits.pageSize + 1)..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return (db, c);
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_right)));
  await tester.runAsync(settle);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('page 1 from the live window; Next fetches one older page; Previous reads nothing; the end', (tester) async {
    final (db, c) = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200);
    expect(page1Range(tester), 'Showing 1 to 25');
    expect(find.text('Load older'), findsNothing);
    expect(page1NextEnabled(tester), isTrue);

    db.resetCounts();
    await _next(tester);
    expect(db.reads, lessThanOrEqualTo(26), reason: 'one cursor page');
    expect(page1Range(tester), 'Showing 26 to 50');

    db.resetCounts();
    await _next(tester);
    expect(page1Range(tester), 'Showing 51 to 60');
    expect(db.reads, lessThanOrEqualTo(26));
    expect(page1NextEnabled(tester), isFalse);

    db.resetCounts();
    await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_left)));
    await tester.pumpAndSettle();
    expect(db.reads, 0);
    expect(page1Range(tester), 'Showing 26 to 50');
  });

  testWidgets('a bigger page size loads what page 1 needs and goes back to page 1', (tester) async {
    final (_, c) = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200);
    await _next(tester);
    await tester.tap(find.descendant(of: page1Bar, matching: find.byType(DropdownButton<int>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 per page').last);
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(page1BarWidget(tester).currentPage, 1);
    expect(page1Range(tester), 'Showing 1 to 50');
  });

  testWidgets('a filter goes back to page 1', (tester) async {
    final (_, c) = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200);
    await _next(tester);
    expect(page1BarWidget(tester).currentPage, 2);
    await tester.enterText(find.byType(TextField).first, 'T n0');
    await tester.pumpAndSettle();
    expect(page1BarWidget(tester).currentPage, 1);
  });

  testWidgets('page 1 keeps the unread first; a new notification arrives live on page 1', (tester) async {
    final (db, c) = await _feed(tester);
    await tester.runAsync(() => seed(db.inner, 'u1', 'newClient', createdAt: t0.subtract(const Duration(minutes: 20))));
    await tester.runAsync(settle);
    await pumpNotifications(tester, c, width: 1200);
    final rows = find.byKey(const ValueKey('notification-more-u1'));
    expect(rows, findsOneWidget, reason: 'the unread one, though 20 minutes old, is on page 1');
    await tester.runAsync(() => seed(db.inner, 'fresh', 'newClient', createdAt: t0));
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-more-fresh')), findsOneWidget);
  });

  testWidgets('while Next loads, the page stays, dimmed; no spinner', (tester) async {
    final (db, c) = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200);
    db.holdGets = Completer<void>();
    await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_right)));
    await tester.pump();
    expect(find.byKey(const ValueKey('pagedList-page')), findsOneWidget);
    expect(find.descendant(of: page1Bar, matching: find.byType(CircularProgressIndicator)), findsNothing);
    db.holdGets!.complete();
    db.holdGets = null;
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(page1Range(tester), 'Showing 26 to 50');
  });

  testWidgets('empty: the empty text, no Next', (tester) async {
    final (_, c) = await _feed(tester, count: 0);
    await pumpNotifications(tester, c, width: 1200);
    expect(find.byType(ListPageBar), findsNothing, reason: 'no bar with nothing to page');
  });

  testWidgets('a failed live list shows the message and Retry; Retry listens again', (tester) async {
    final db = CountingFirestore()..failListens = true;
    final c = newFeed(db, 'A', Clock(), window: AppLimits.pageSize + 1)..start();
    addTearDown(c.dispose);
    await tester.runAsync(settle);
    await pumpNotifications(tester, c, width: 1200);
    expect(find.byKey(const ValueKey('notifications-retry')), findsOneWidget);
    db.failListens = false;
    await tester.runAsync(() => seed(db.inner, 'n1', 'newClient', createdAt: t0, readAt: t0));
    await tester.tap(find.byKey(const ValueKey('notifications-retry')));
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-more-n1')), findsOneWidget);
  });

  testWidgets('reads on open: the live page (pageSize + 1) and my state, not 200', (tester) async {
    final (db, c) = await _feed(tester);
    // ignore: avoid_print
    print('PAGE1 Notifications open (listeners, gets, reads): (${db.listeners}, ${db.gets}, ${db.reads})');
    expect(db.reads, lessThanOrEqualTo(26 + 3));
    await pumpNotifications(tester, c, width: 1200);
  });

  for (final width in const [768.0, 1200.0, 1920.0]) {
    for (final (locale, scale) in const [('en', 1.0), ('en', 1.3), ('sw', 1.3)]) {
      testWidgets('$width $locale text $scale: the page and the bar, no overflow', (tester) async {
        final (_, c) = await _feed(tester);
        await pumpNotifications(tester, c, width: width, height: 1000, locale: locale, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(page1BarWidget(tester).itemCount, 25);
      });
    }
  }
}
