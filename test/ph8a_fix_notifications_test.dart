// PH8a-fix (1), the owner's correction, as POL1 left it: the full
// Notifications page draws no category cards on any size (POL1 removed the
// tablet's too, and the phone's summary line and chips). In their place one
// filter row: All, Unread and the cards' five categories, each with its
// count; a category filters exactly as its card and chip did (tap to
// filter, tap again for All). On a phone Mark all read, Remove read ones and
// Select are in one overflow menu; a tablet keeps the buttons.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

const _menu = ValueKey('notifications-page-more');

// The cards' categories, in their order; "All" is no category.
const _cats = [
  NotificationCategory.critical,
  NotificationCategory.stock,
  NotificationCategory.payment,
  NotificationCategory.debt,
  NotificationCategory.system,
];

/// A filter row segment by its stored value: a category's name, 'all' or 'unread'.
Finder _seg(String value) => find.byKey(ValueKey('notifications-filter-$value'));
Finder _cat(NotificationCategory? c) => _seg(c?.name ?? 'all');

/// One of most categories, some read; the subscription notice too.
Future<NotificationFeedController> _feed(WidgetTester tester) async {
  final fs = FakeFirebaseFirestore();
  final at = t0.subtract(const Duration(hours: 1));
  final c = (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: at);
    await seed(fs, 'n2', 'criticalStock', createdAt: at.subtract(const Duration(minutes: 1)));
    await seed(fs, 'n3', 'paymentReceived', createdAt: at.subtract(const Duration(minutes: 2)), readAt: at);
    await seed(fs, 'n4', 'assistantPending', createdAt: at.subtract(const Duration(minutes: 3)), audience: 'admins');
    await seed(fs, 'n5', 'newClient', createdAt: at.subtract(const Duration(minutes: 4)));
    await seed(fs, 'n6', 'lowStock', createdAt: at.subtract(const Duration(minutes: 5)), readAt: at);
    final subs = Subs()..facts = expiring;
    final c = newFeed(fs, 'A', Clock(), subs: subs)..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

/// The rows on screen, by id (every row has its three-dots menu).
Set<String> _rows() => find
    .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('notification-more-'))
    .evaluate()
    .map((e) => (e.widget.key as ValueKey<String>).value.substring('notification-more-'.length))
    .toSet();

Set<String> _idsWhere(NotificationFeedController c, bool Function(NotificationItem) test) =>
    c.items.where(test).map((i) => i.id).toSet();

String _name(AppLocalizations l, NotificationCategory? c) => switch (c) {
      null => l.common_all,
      NotificationCategory.critical => l.notifications_catCritical,
      NotificationCategory.stock => l.notifications_catStock,
      NotificationCategory.payment => l.notifications_catPayments,
      NotificationCategory.debt => l.notifications_catDebts,
      NotificationCategory.system => l.notifications_catSystem,
      NotificationCategory.other => l.notifications_catUpdates,
    };

Future<void> _phone(WidgetTester tester, NotificationFeedController c) =>
    pumpNotifications(tester, c, width: 390, height: 1400);

String _countOf(WidgetTester tester, String value) =>
    tester.widget<Text>(find.byKey(ValueKey('notifications-filter-$value-count'))).data!;

void main() {
  for (final (where, width, height) in [('a phone', 390.0, 1400.0), ('a tablet', 1024.0, 768.0)]) {
    testWidgets('on $where no category cards and no summary line; one filter row', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      expect(find.byType(GridView), findsNothing, reason: 'the cards were a grid');
      expect(find.byKey(const ValueKey('notifications-summary')), findsNothing);
      expect(_cat(null), findsOneWidget);
      expect(_seg('unread'), findsOneWidget);
    });

    testWidgets('on $where: All, Unread and the cards\' categories in order, each with its count', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      final l = tester.element(_cat(null)).l10n;
      expect(_countOf(tester, 'all'), '${c.items.length}');
      expect(_countOf(tester, 'unread'), '${c.items.where((i) => !i.isRead).length}');
      var lastX = tester.getTopLeft(_seg('unread')).dx;
      for (final cat in _cats) {
        expect(find.descendant(of: _cat(cat), matching: find.text(_name(l, cat))), findsOneWidget, reason: '$cat');
        expect(_countOf(tester, cat.name), '${c.items.where((i) => i.notification.category == cat).length}', reason: '$cat');
        final x = tester.getTopLeft(_cat(cat)).dx;
        expect(x, greaterThan(lastX), reason: 'in the cards\' order');
        lastX = x;
      }
    });

    testWidgets('on $where each segment filters as its card did; tapped again, All', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      final all = _rows();
      for (final cat in _cats) {
        await tester.ensureVisible(_cat(cat));
        await tester.pumpAndSettle();
        await tester.tap(_cat(cat));
        await tester.pumpAndSettle();
        expect(_rows(), _idsWhere(c, (i) => i.notification.category == cat), reason: '$cat');
        await tester.ensureVisible(_cat(cat));
        await tester.pumpAndSettle();
        await tester.tap(_cat(cat));
        await tester.pumpAndSettle();
        expect(_rows(), all, reason: '$cat tapped again: All');
      }
      await tester.ensureVisible(_seg('unread'));
      await tester.pumpAndSettle();
      await tester.tap(_seg('unread'));
      await tester.pumpAndSettle();
      expect(_rows(), _idsWhere(c, (i) => !i.isRead), reason: 'the status filter\'s Unread');
      await tester.ensureVisible(_cat(null));
      await tester.pumpAndSettle();
      await tester.tap(_cat(null));
      await tester.pumpAndSettle();
      expect(_rows(), all);
    });
  }

  testWidgets('the selected segment says it is selected, not only a colour', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    await tester.ensureVisible(_cat(NotificationCategory.stock));
    await tester.pumpAndSettle();
    await tester.tap(_cat(NotificationCategory.stock));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    final label = find.descendant(of: _cat(NotificationCategory.stock), matching: find.byType(Text)).first;
    expect(tester.widget<Text>(label).style!.fontWeight, FontWeight.w600, reason: 'bold, besides the colour');
    expect(tester.getSemantics(_cat(NotificationCategory.stock)), isSemantics(isSelected: true, isButton: true, hasTapAction: true));
    handle.dispose();
  });

  testWidgets('the header actions are in one overflow menu on a phone: Mark all read', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    expect(find.widgetWithText(OutlinedButton, 'Mark all read'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Remove read ones'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Select'), findsNothing);
    await tester.tap(find.byKey(_menu));
    await tester.pumpAndSettle();
    expect(find.text('Remove read ones'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(c.hasUnread, isFalse);
  });

  testWidgets('the menu\'s Remove read ones: the confirmation, then Undo', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    final before = c.items.map((i) => i.id).toSet();
    await tester.tap(find.byKey(_menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove read ones'));
    await tester.pumpAndSettle();
    expect(find.text('Remove 2 read notifications? Only you stop seeing them.'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id).toSet(), before.difference({'n3', 'n6'}));
    expect(find.text('2 notifications removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id).toSet(), before);
    await letToastGo(tester);
  });

  testWidgets('the menu\'s Select starts selection mode, as the button did', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    await tester.tap(find.byKey(_menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-select-n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-select-n4')), findsNothing, reason: 'never on persistent rows');
    await tester.tap(find.byKey(const ValueKey('notification-select-n1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove selected'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id), isNot(contains('n1')));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.items.map((i) => i.id), contains('n1'));
    await letToastGo(tester);
  });

  testWidgets('a tablet: Mark all read in the header, the other two in its "more" menu (UX6)', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1024, height: 768);
    expect(find.byKey(_menu), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Mark all read'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notifications-wide-more')));
    await tester.pumpAndSettle();
    expect(find.text('Remove read ones'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
  });
}
