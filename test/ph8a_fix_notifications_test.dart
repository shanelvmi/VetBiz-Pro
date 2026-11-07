// PH8a-fix (1), the owner's correction: on a phone the full Notifications
// page draws no category cards. In their place a summary line under the app
// bar ("6 notifications, 4 unread", or "All read") and a sideways row of
// category chips (All and the cards' five), each with its unread count; a
// chip filters exactly as its card did (tap to filter, tap again for All).
// Mark all read, Remove read ones and Select go into one overflow menu.
// Tablets keep the cards and the buttons (their fingerprints are in
// ph8a_wide_unchanged_test.dart).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

const _skip = true;

const _menu = ValueKey('notifications-page-more');
const _summary = ValueKey('notifications-summary');

// The cards' categories, in their order; "All" is no category.
const _cats = [
  NotificationCategory.critical,
  NotificationCategory.stock,
  NotificationCategory.payment,
  NotificationCategory.debt,
  NotificationCategory.system,
];

Finder _chip(NotificationCategory? c) => find.byKey(ValueKey('notifications-chip-${c?.name ?? 'all'}'));

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

int _unread(NotificationFeedController c, NotificationCategory? cat) =>
    c.items.where((i) => !i.isRead && (cat == null || i.notification.category == cat)).length;

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

void main() {
  testWidgets('on a phone no category cards; the tablet keeps them', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    expect(find.byType(GridView), findsNothing, reason: 'the cards are a grid');
    expect(_chip(null), findsOneWidget);
    await pumpNotifications(tester, c, width: 1024, height: 768);
    expect(find.byType(GridView), findsOneWidget);
    expect(_chip(null), findsNothing);
    expect(find.byKey(_summary), findsNothing);
    expect(find.byKey(_menu), findsNothing);
  }, skip: _skip);

  testWidgets('the chips: All and the cards\' categories in order, each with its unread count', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    final l = tester.element(find.byKey(_summary)).l10n;
    var lastX = -1.0;
    for (final cat in [null, ..._cats]) {
      final chip = _chip(cat);
      expect(chip, findsOneWidget, reason: '$cat');
      expect(find.descendant(of: chip, matching: find.text(l.notifications_categoryChip(_name(l, cat), _unread(c, cat)))),
          findsOneWidget, reason: '$cat');
      final x = tester.getTopLeft(chip).dx;
      expect(x, greaterThan(lastX), reason: 'in the cards\' order');
      lastX = x;
    }
    expect(tester.widget<ChoiceChip>(find.descendant(of: _chip(null), matching: find.byType(ChoiceChip))).selected, isTrue);
  }, skip: _skip);

  testWidgets('each chip filters exactly as its card does on a tablet; tapped again, All', (tester) async {
    final c = await _feed(tester);
    final tablet = <NotificationCategory, Set<String>>{};
    await pumpNotifications(tester, c, width: 1024, height: 1400);
    final l = tester.element(find.byType(GridView)).l10n;
    final all = _rows();
    for (final cat in _cats) {
      final card = find.descendant(of: find.byType(GridView), matching: find.text(_name(l, cat)));
      await tester.tap(card);
      await tester.pumpAndSettle();
      tablet[cat] = _rows();
      final u = _unread(c, cat);
      expect(find.descendant(of: find.byType(GridView), matching: find.text(u > 0 ? l.notifications_unreadCount(u) : l.notifications_allRead)),
          findsWidgets, reason: 'the card\'s count');
      await tester.tap(card);
      await tester.pumpAndSettle();
    }

    await _phone(tester, c);
    expect(_rows(), all, reason: 'All shows what the tablet shows unfiltered');
    for (final cat in _cats) {
      await tester.ensureVisible(_chip(cat));
      await tester.tap(_chip(cat));
      await tester.pumpAndSettle();
      expect(_rows(), tablet[cat], reason: '$cat');
      expect(tester.widget<ChoiceChip>(find.descendant(of: _chip(cat), matching: find.byType(ChoiceChip))).selected, isTrue);
      await tester.tap(_chip(cat));
      await tester.pumpAndSettle();
      expect(_rows(), all, reason: '$cat tapped again: All');
    }
    await tester.tap(_chip(NotificationCategory.stock));
    await tester.pumpAndSettle();
    await tester.tap(_chip(null));
    await tester.pumpAndSettle();
    expect(_rows(), all);
  }, skip: _skip);

  testWidgets('the selected chip shows a check and says it is selected, not only a colour', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    await tester.tap(_chip(NotificationCategory.stock));
    await tester.pumpAndSettle();
    final finder = find.descendant(of: _chip(NotificationCategory.stock), matching: find.byType(ChoiceChip));
    final chip = tester.widget<ChoiceChip>(finder);
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isNot(false), reason: 'the check mark, besides the colour');
    expect(tester.getSemantics(finder), containsSemantics(isSelected: true));
  }, skip: _skip);

  testWidgets('the summary line from the same counts; All read once nothing is unread', (tester) async {
    final c = await _feed(tester);
    await _phone(tester, c);
    final l = tester.element(find.byKey(_summary)).l10n;
    expect(tester.widget<Text>(find.byKey(_summary)).data, l.notifications_summaryLine(c.items.length, _unread(c, null)));
    expect(tester.getTopLeft(find.byKey(_summary)).dy, lessThan(tester.getTopLeft(_chip(null)).dy), reason: 'under the app bar, above the chips');
    await c.markAllRead();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_summary)).data, l.notifications_allRead);
  }, skip: _skip);

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
  }, skip: _skip);

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
  }, skip: _skip);

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
  }, skip: _skip);

  testWidgets('a tablet keeps the buttons and no menu', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1024, height: 768);
    expect(find.byKey(_menu), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Mark all read'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Remove read ones'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Select'), findsOneWidget);
  }, skip: _skip);
}
