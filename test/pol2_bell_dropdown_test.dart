// POL2 Step 1: the bell dropdown in the full Notifications page's style. Its
// rows are the page's own narrow rows (the unread dot, the bold title and
// tint, the grey category, the needs-action word in danger), its group
// headers are SectionLabels (no icon, no coloured count pill), the urgent
// announcement card has a hairline border and no shadow, and the unread
// count in its bar is plain text. The feed, markRead and the bell are
// untouched: the rows and groups come from the same controller as before.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';

import 'helpers/notification_harness.dart';

/// n1, n2 unread (n2 needs action: critical stock); n3 read.
Future<NotificationFeedController> _feed(WidgetTester tester, {bool urgent = false}) async {
  final fs = FakeFirebaseFirestore();
  final at = t0.subtract(const Duration(hours: 1));
  final c = (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: at);
    await seed(fs, 'n2', 'criticalStock', createdAt: at.subtract(const Duration(minutes: 1)));
    await seed(fs, 'n3', 'paymentReceived', createdAt: at.subtract(const Duration(minutes: 2)), readAt: at);
    if (urgent) await _seedUrgent(fs);
    final c = newFeed(fs, 'A', Clock())..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

/// One urgent text announcement, as test/an3_dropdown_announcements_test.dart seeds it.
Future<void> _seedUrgent(FirebaseFirestore fs) => fs.collection(Collections.publicAnnouncements).doc('T1').set({
      'title': 'Title T1',
      'message': 'Message T1',
      'urgent': true,
      'hidden': false,
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

/// What a row looks like, by the stored id: the dot, the title's weight,
/// colour and size, the category's colour, the needs-action word, the fill.
Map<String, String> _rowLooks(WidgetTester tester, NotificationFeedController c) => {
      for (final i in c.items)
        i.id: [
          find.byKey(ValueKey('notifications-unreadDot-${i.id}')).evaluate().length,
          () {
            final t = tester.widget<Text>(find.text(i.notification.title).first);
            return '${t.style!.fontWeight} ${t.style!.color} ${t.style!.fontSize}';
          }(),
          tester.widget<Text>(find.byKey(ValueKey('notifications-category-${i.id}'))).style!.color,
          find.byKey(ValueKey('notifications-needsAction-${i.id}')).evaluate().length,
          () {
            final ink = tester.widget<Ink>(find.descendant(of: find.byKey(ValueKey(i.id)), matching: find.byType(Ink)).first);
            return (ink.decoration as BoxDecoration).color;
          }(),
        ].join(' | '),
    };

void _noGradientOrShadow(WidgetTester tester) {
  for (final e in find
      .descendant(of: find.byType(NotificationsScreen), matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox || w is Ink))
      .evaluate()) {
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
  for (final dark in [false, true]) {
    final look = dark ? 'dark' : 'light';
    testWidgets('$look: the dropdown and the full page draw every row the same way', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: 390, height: 1200, dark: dark);
      final page = _rowLooks(tester, c);
      await pumpNotifications(tester, c, width: 1200, height: 900, dark: dark, dropdown: true);
      expect(tester.takeException(), isNull);
      final dropdown = _rowLooks(tester, c);
      expect(dropdown, page);
      expect(find.byKey(const ValueKey('notifications-unreadDot-n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications-unreadDot-n3')), findsNothing);
      expect(find.byKey(const ValueKey('notifications-needsAction-n2')), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications-needsAction-n1')), findsNothing);
    });
  }

  testWidgets('the dropdown: SectionLabel headers, no icon or count pill, no gradient or shadow, the count as text', (tester) async {
    final c = await _feed(tester, urgent: true);
    await pumpNotifications(tester, c, width: 1200, height: 900, dropdown: true);
    expect(tester.takeException(), isNull);
    final labels = tester.widgetList<SectionLabel>(find.byType(SectionLabel)).map((s) => s.text).toList();
    // The feed's own groups, as before (all three items are recent, so none is "Earlier").
    expect(labels, ['Urgent Announcements', 'Needs Attention']);
    for (final icon in [Icons.priority_high, Icons.history, Icons.campaign_outlined, Icons.workspace_premium_outlined]) {
      expect(find.descendant(of: find.byType(SectionLabel), matching: find.byIcon(icon)), findsNothing);
    }
    expect(find.text('Title T1'), findsOneWidget, reason: 'the urgent announcement is still shown');
    final count = tester.widget<Text>(find.byKey(const ValueKey('notifications-dropdown-unreadCount')));
    expect(count.data, '${c.items.where((i) => !i.isRead).length}', reason: 'the unread notifications, counted as before');
    _noGradientOrShadow(tester);
  });

  testWidgets('the dropdown at text scale 1.3 with reduced motion: no overflow; the dot, the word and the headers stay', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200, height: 900, dropdown: true);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('notifications-unreadDot-n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-needsAction-n2')), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-dropdown-group-attention')), findsOneWidget);
  });

  testWidgets('the dropdown: a tap still marks the row read (the same feed and markRead)', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200, height: 900, dropdown: true);
    expect(c.items.firstWhere((i) => i.id == 'n1').isRead, isFalse);
    await tester.tap(find.text('T n1'));
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(c.items.firstWhere((i) => i.id == 'n1').isRead, isTrue);
    expect(find.byKey(const ValueKey('notifications-unreadDot-n1')), findsNothing);
  });
}
