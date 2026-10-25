// NOTIF-2c (docs/design/notifications.md, sections 3 and 4, approved): swipe
// at phone width, selection mode, Load older, the menu on the wide table,
// tap targets, and no overflow at 360 px in Light and Dark.
// Written against today's screen, where every one of these fails.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

// Was true until the screens were wired (NOTIF-2c).
const _skip = false;

const _minTap = 48.0;

NotificationItem itemOf(NotificationFeedController c, String id) => c.items.firstWhere((i) => i.id == id);

void main() {
  testWidgets('swipe at 390 px: left removes, right toggles read; nothing on a persistent row', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock');
    await seed(fs, 'n2', 'newClient', createdAt: t0.subtract(const Duration(minutes: 1)));
    await seed(fs, 'p1', 'assistantPending', createdAt: t0.subtract(const Duration(minutes: 2)));
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, width: 390);

    await tester.drag(find.text('T n2'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'n2').isRead, isTrue);
    await tester.drag(find.text('T n2'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'n2').isRead, isFalse);

    await tester.drag(find.text('T n1'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id), isNot(contains('n1')));
    expect(find.text('Notification removed'), findsOneWidget);

    await tester.drag(find.text('T p1'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('T p1'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'p1').isRead, isFalse);
    expect(c.items.map((i) => i.id), contains('p1'));
    // The menu stays on every row: swipes are not discoverable.
    for (final id in ['n2', 'p1']) {
      expect(moreOf(id), findsOneWidget, reason: id);
    }
    await letToastGo(tester);
  }, skip: _skip);

  testWidgets('selection mode: checkboxes, never on persistent rows, Remove selected with Undo', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock');
    await seed(fs, 'n2', 'paymentReceived');
    await seed(fs, 'p1', 'assistantPending');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, width: 390);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-select-p1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification-select-n1')));
    await tester.tap(find.byKey(const ValueKey('notification-select-n2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove selected'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id), ['p1']);
    expect(find.text('2 notifications removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.items.length, 3);
    await letToastGo(tester);
  }, skip: _skip);

  testWidgets('Load older on the full screen; not in the dropdown', (tester) async {
    final fs = FakeFirebaseFirestore();
    for (var i = 1; i <= 5; i++) {
      await seed(fs, 'n$i', 'lowStock', createdAt: t0.subtract(Duration(minutes: i)));
    }
    final c = newFeed(fs, 'A', Clock(), window: 3, olderPage: 2);
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, width: 390, height: 1400);
    await tester.scrollUntilVisible(find.text('Load older'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Load older'));
    await tester.pumpAndSettle();
    expect(c.items.length, 5);

    final d = newFeed(fs, 'A', Clock(), window: 3);
    addTearDown(d.dispose);
    await pumpNotifications(tester, d, dropdown: true);
    expect(find.text('Load older'), findsNothing);
  }, skip: _skip);

  testWidgets('the wide table has the menu on every row; tapping a row reads it', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, width: 1280, height: 900);
    expect(moreOf('n1'), findsOneWidget);
    await tester.tap(find.text('T n1'));
    await tester.pumpAndSettle();
    expect(itemOf(c, 'n1').isRead, isTrue);
    expect(find.text('Remove read ones'), findsOneWidget);
  }, skip: _skip);

  for (final dark in [false, true]) {
    for (final width in [360.0, 390.0]) {
      testWidgets('no overflow at $width px, ${dark ? 'Dark' : 'Light'}; menus and checkboxes are 48 px', (tester) async {
        final fs = FakeFirebaseFirestore();
        final subs = Subs()..facts = expiring;
        await seed(fs, 'n1', 'criticalStock',
            title: 'Critical stock: Oxytetracycline 20% long-acting injection 100 ml', relatedType: 'product', relatedId: 'p');
        await seed(fs, 'p1', 'assistantPending');
        final c = newFeed(fs, 'A', Clock(), subs: subs);
        addTearDown(c.dispose);
        await pumpNotifications(tester, c, width: width, dark: dark);
        expect(tester.takeException(), isNull);
        for (final id in ['n1', 'p1', subscriptionNoticeId]) {
          final size = tester.getSize(moreOf(id));
          expect(size.width >= _minTap && size.height >= _minTap, isTrue, reason: '$id: $size');
        }
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final box = tester.getSize(find.byKey(const ValueKey('notification-select-n1')));
        expect(box.width >= _minTap && box.height >= _minTap, isTrue, reason: '$box');

        await openMenu(tester, 'p1');
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }
  }

  testWidgets('the dropdown at 400 px: menus, Remove read ones, no overflow in Dark', (tester) async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'n1', 'lowStock', title: 'Low stock: a product with a very long name that wraps on two lines');
    final c = newFeed(fs, 'A', Clock());
    addTearDown(c.dispose);
    await pumpNotifications(tester, c, dropdown: true, dark: true);
    expect(tester.takeException(), isNull);
    expect(moreOf('n1'), findsOneWidget);
    await c.markRead([itemOf(c, 'n1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-header-more')));
    await tester.pumpAndSettle();
    expect(find.text('Remove read ones'), findsOneWidget);
  }, skip: _skip);
}
