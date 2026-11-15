// POL1 Step C: the Notifications page on phone, tablet and computer. Unread
// is impossible to miss (a primary dot at the row's leading edge, a bold
// title, a soft primary tint, the count in the filter row); read rows are
// regular weight and secondary, with no dot. The category is plain grey
// text; only an item that needs action shows a danger-coloured word. The
// list is grouped "New" then "Earlier". No gradient or shadow is drawn. The
// feed, markRead, the bell and its dropdown are untouched (the dropdown's
// fingerprints in ph8a_wide_unchanged_test.dart are the ones from before).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';

import 'helpers/notification_harness.dart';

const _skip = false;

/// n1, n2, n4, n5 unread; n3, n6 read; n2 needs action (critical stock).
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
    final c = newFeed(fs, 'A', Clock())..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

const _sizes = [('phone', 390.0, 1400.0), ('tablet', 768.0, 1024.0), ('computer', 1200.0, 900.0)];

AppColors _colors(WidgetTester tester) => Theme.of(tester.element(find.byType(NotificationsScreen))).extension<AppColors>()!;

Finder _dot(String id) => find.byKey(ValueKey('notifications-unreadDot-$id'));

/// The row's title Text (the stored title, shown as stored).
Text _title(WidgetTester tester, NotificationFeedController c, String id) {
  final title = c.items.firstWhere((i) => i.id == id).notification.title;
  return tester.widget<Text>(find.text(title).first);
}

void _noGradientOrShadow(WidgetTester tester) {
  final page = find.byType(NotificationsScreen);
  for (final e in find.descendant(of: page, matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox || w is Ink)).evaluate()) {
    final w = e.widget;
    final d = switch (w) {
      Container() => w.decoration,
      DecoratedBox() => w.decoration,
      Ink() => w.decoration,
      _ => null,
    };
    if (d is BoxDecoration) {
      expect(d.gradient, isNull, reason: '$w');
      expect(d.boxShadow, anyOf(isNull, isEmpty), reason: '$w');
    }
  }
}

void main() {
  test('the needs-action types are pinned: critical stock, product expiry, a rejected payment', () {
    expect({for (final t in NotificationType.values) if (notificationNeedsAction(t)) t}, {
      NotificationType.criticalStock,
      NotificationType.productExpiry,
      NotificationType.subscriptionRejected,
    });
  });

  test('newThenEarlier: the unread first, then the read, each in the order given; nothing dropped', () {
    FacilityNotification n(String id) => FacilityNotification(id: id, type: NotificationType.general, title: id, message: '');
    final items = [
      NotificationItem(n('a'), isRead: true),
      NotificationItem(n('b'), isRead: false),
      NotificationItem(n('c'), isRead: true),
      NotificationItem(n('d'), isRead: false),
    ];
    expect(newThenEarlier(items).map((i) => i.id), ['b', 'd', 'a', 'c']);
  });

  for (final (name, width, height) in _sizes) {
    for (final dark in [false, true]) {
      final look = dark ? 'dark' : 'light';
      testWidgets('$name $look: unread rows have the dot, the bold title and the tint; read rows do not', (tester) async {
        final c = await _feed(tester);
        await pumpNotifications(tester, c, width: width, height: height, dark: dark);
        expect(tester.takeException(), isNull);
        final colors = _colors(tester);
        for (final i in c.items) {
          final title = _title(tester, c, i.id);
          if (i.isRead) {
            expect(_dot(i.id), findsNothing, reason: i.id);
            expect(title.style!.fontWeight, AppFontWeight.regular, reason: i.id);
            expect(title.style!.color, colors.textSecondary, reason: i.id);
          } else {
            expect(_dot(i.id), findsOneWidget, reason: i.id);
            final dot = tester.widget<DecoratedBox>(find.descendant(of: _dot(i.id), matching: find.byType(DecoratedBox)));
            expect((dot.decoration as BoxDecoration).color, colors.primary, reason: i.id);
            expect(title.style!.fontWeight, AppFontWeight.bold, reason: i.id);
            expect(title.style!.color, colors.textPrimary, reason: i.id);
          }
        }
        _noGradientOrShadow(tester);
      }, skip: _skip);
    }

    testWidgets('$name: the category is plain grey text; only the item that needs action has the danger word', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      final colors = _colors(tester);
      for (final i in c.items) {
        final cat = tester.widget<Text>(find.byKey(ValueKey('notifications-category-${i.id}')));
        expect(cat.style!.color, colors.textSecondary, reason: i.id);
        final word = find.byKey(ValueKey('notifications-needsAction-${i.id}'));
        if (notificationNeedsAction(i.type)) {
          expect(tester.widget<Text>(word).data, 'Needs Attention');
          expect(tester.widget<Text>(word).style!.color, colors.dangerStrong);
        } else {
          expect(word, findsNothing, reason: i.id);
        }
      }
      expect(find.byKey(const ValueKey('notifications-needsAction-n2')), findsOneWidget);
      // No "New" or "Read" pill: no tinted box holds those words.
      for (final text in find.descendant(of: find.byType(NotificationsScreen), matching: find.byType(Text)).evaluate()) {
        final box = text.findAncestorWidgetOfExactType<Container>();
        final d = box?.decoration;
        if (d is BoxDecoration && d.borderRadius != null && d.color != null && d.border == null) {
          fail('a tinted pill around "${(text.widget as Text).data}"');
        }
      }
    }, skip: _skip);

    testWidgets('$name: "New" then "Earlier"; marking all read leaves only Earlier and no dot', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      final labels = tester.widgetList<SectionLabel>(find.byType(SectionLabel)).map((s) => s.text).toList();
      expect(labels, ['New', 'Earlier']);
      final newY = tester.getTopLeft(find.byKey(const ValueKey('notifications-group-new'))).dy;
      final earlierY = tester.getTopLeft(find.byKey(const ValueKey('notifications-group-earlier'))).dy;
      for (final i in c.items) {
        final y = tester.getTopLeft(find.byKey(ValueKey('notification-more-${i.id}'))).dy;
        expect(i.isRead ? y > earlierY : (y > newY && y < earlierY), isTrue, reason: '${i.id} in its group');
      }
      await c.markAllRead();
      await tester.pumpAndSettle();
      expect(tester.widgetList<SectionLabel>(find.byType(SectionLabel)).map((s) => s.text), ['Earlier']);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('notifications-unreadDot-')),
          findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('notifications-filter-unread-count'))).data, '0');
    }, skip: _skip);

    testWidgets('$name at text scale 1.3 with reduced motion: no overflow, the dot and the words stay', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      expect(tester.takeException(), isNull);
      expect(_dot('n1'), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications-needsAction-n2')), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications-filter-unread')), findsOneWidget);
    }, skip: _skip);
  }

  for (final (name, width, height) in _sizes.skip(1)) {
    testWidgets('$name keeps its structure: the table columns in order, the filters and the three actions', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: width, height: height);
      final headers = ['Notification', 'Category', 'Date', 'Status'];
      final xs = [for (final h in headers) tester.getTopLeft(find.text(h)).dx];
      expect(xs, orderedEquals([...xs]..sort()), reason: 'the columns in their order');
      expect(find.byType(TextField), findsOneWidget, reason: 'search');
      expect(find.byType(DropdownButton<String>), findsOneWidget, reason: 'the status filter');
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget, reason: 'the date filter');
      for (final a in ['Mark all read', 'Remove read ones', 'Select']) {
        expect(find.widgetWithText(OutlinedButton, a), findsOneWidget, reason: a);
      }
      for (final i in c.items) {
        expect(find.byKey(ValueKey('notification-more-${i.id}')), findsOneWidget, reason: 'each row keeps its menu');
      }
    }, skip: _skip);
  }

  testWidgets('the status filter still compares its stored values: Read shows only the read rows', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200, height: 900);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status: Read').last);
    await tester.pumpAndSettle();
    final shown = find
        .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('notification-more-'))
        .evaluate()
        .map((e) => (e.widget.key as ValueKey<String>).value.substring('notification-more-'.length))
        .toSet();
    expect(shown, {for (final i in c.items) if (i.isRead) i.id});
    expect(tester.widget<Text>(find.byKey(const ValueKey('notifications-filter-all-count'))).data, '${c.items.length}');
  }, skip: _skip);
}
