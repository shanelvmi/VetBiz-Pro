// NOTIF-2c (docs/design/notifications.md, section 3, approved): the more
// menu on every row, tap to read, Remove with Undo, Remove read ones with
// its confirmation, per person on the screen, the plain empty state.
// Written against today's screen, where every one of these fails.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

// Was true until the screens were wired (NOTIF-2c).
const _skip = false;

NotificationItem itemOf(NotificationFeedController c, String id) => c.items.firstWhere((i) => i.id == id);

void main() {
  testWidgets('a routine row offers Mark as read, Remove and Open; read, it offers Mark as unread', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'stock', 'lowStock', relatedType: 'product', relatedId: 'p1');
    await seed(fs, 'pay', 'paymentReceived');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c);

    await openMenu(tester, 'stock');
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget, reason: 'the row links to a product');
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'stock').isRead, isTrue);

    await openMenu(tester, 'stock');
    expect(find.text('Mark as unread'), findsOneWidget);
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'stock').isRead, isFalse);

    await openMenu(tester, 'pay');
    expect(find.text('Open'), findsNothing, reason: 'nothing to open');
  }, skip: _skip);

  testWidgets('persistent rows: no Remove, the reason line instead', (tester) async {
    final fs = FakeFirebaseFirestore();
    final subs = Subs()..facts = expiring;
    await seed(fs, 'pending', 'assistantPending');
    await seed(fs, 'rej', 'subscription_rejected');
    final c = newFeed(fs, 'A', Clock(), subs: subs);
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, height: 1400);

    final reasons = {
      subscriptionNoticeId: 'Stays until the subscription is renewed',
      'pending': 'Stays until the request is approved or rejected',
      'rej': 'Stays until a new payment is submitted',
    };
    for (final e in reasons.entries) {
      await openMenu(tester, e.key);
      expect(find.text('Remove'), findsNothing, reason: e.key);
      expect(find.text(e.value), findsOneWidget, reason: e.key);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
    }
  }, skip: _skip);

  testWidgets('the trial row explains itself too', (tester) async {
    final fs = FakeFirebaseFirestore();
    final subs = Subs()..facts = const SubscriptionFacts(trialInfo: (title: 'Free Trial', message: '20 days left'));
    final c = newFeed(fs, 'A', Clock(), subs: subs);
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, dropdown: true);
    await openMenu(tester, trialStatusRowId);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Stays until the free trial ends'), findsOneWidget);
  }, skip: _skip);

  testWidgets('tapping a row marks it read for me only', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'newClient');
    final a = newFeed(fs, 'A', Clock());
    final b = newFeed(fs, 'B', Clock())..start();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpNotifications(tester, a);
    await tester.tap(find.text('T n1'));
    await tester.pumpAndSettle();
    expect(itemOf(a, 'n1').isRead, isTrue);
    expect(itemOf(b, 'n1').isRead, isFalse);
  }, skip: _skip);

  testWidgets('a single Remove has no dialog, only the Undo toast; Undo puts it back', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock');
    final a = newFeed(fs, 'A', Clock());
    final b = newFeed(fs, 'B', Clock())..start();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpNotifications(tester, a);
    await openMenu(tester, 'n1');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('T n1'), findsNothing);
    expect(b.items.map((i) => i.id), ['n1'], reason: 'the other admin still sees it');
    expect(find.text('Notification removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('T n1'), findsOneWidget);
    await letToastGo(tester);
  }, skip: _skip);

  testWidgets('Remove read ones: confirmation, only read removable ones, then Undo restores', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'r1', 'lowStock');
    await seed(fs, 'r2', 'serviceRecorded');
    await seed(fs, 'u1', 'paymentReceived');
    await seed(fs, 'p1', 'assistantPending');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c);
    await c.markRead([itemOf(c, 'r1'), itemOf(c, 'r2'), itemOf(c, 'p1')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove read ones'));
    await tester.pumpAndSettle();
    expect(find.text('Remove 2 read notifications? Only you stop seeing them.'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id).toSet(), {'u1', 'p1'});
    expect(find.text('2 notifications removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id).toSet(), {'r1', 'r2', 'u1', 'p1'});
    await letToastGo(tester);
  }, skip: _skip);

  testWidgets('cancelling the confirmation removes nothing; there is no delete everything', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'r1', 'lowStock');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c);
    await c.markRead([itemOf(c, 'r1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove read ones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id), ['r1']);
    expect(find.textContaining('Delete'), findsNothing);
    expect(find.textContaining('Remove all'), findsNothing);
  }, skip: _skip);

  testWidgets('Mark all as read is per person on the screen', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock');
    final a = newFeed(fs, 'A', Clock());
    final b = newFeed(fs, 'B', Clock())..start();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpNotifications(tester, a, dropdown: true);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(a.hasUnread, isFalse);
    expect(b.hasUnread, isTrue);
  }, skip: _skip);

  testWidgets('the empty state keeps its plain texts, in the dropdown too', (tester) async {
    for (final dropdown in [false, true]) {
      final c = newFeed(FakeFirebaseFirestore(), 'A', Clock());
      await pumpNotifications(tester, c, dropdown: dropdown);
      expect(find.text('No notifications'), findsWidgets, reason: 'dropdown: $dropdown');
      expect(find.text('New updates from your facility will appear here.'), findsOneWidget);
      expect(find.text("You're all caught up!"), findsNothing);
      c.dispose();
    }
  }, skip: _skip);
}
