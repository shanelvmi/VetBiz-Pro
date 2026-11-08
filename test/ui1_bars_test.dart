// UI1 (4), written before the change. No coloured bar down the left of a card
// or row, at every width, in Subscription (the plans and the status), its
// payment history (rows and cards) and Notifications (the page's rows and
// cards, the dropdown's announcements): the status stays in the text and a
// chip. A bar is found by its decoration: a Border with only a left side, or
// a narrow coloured Container leading a row (a ClipRRect's strip is one of
// these inside it). On a phone, Notifications has no search field and no
// date or status filter (wide screens keep them): the app bar with its menu,
// the summary line, the category chips (which still filter) and the list.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_history_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/fake_firestore.dart' show testFacilityId;
import 'helpers/notification_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

const _skip = false;

const _sizes = [Size(360, 740), Size(390, 844), Size(740, 360), Size(768, 1024), Size(1200, 800)];

bool _leftOnly(Decoration? d) {
  if (d is! BoxDecoration) return false;
  final b = d.border;
  return b is Border && b.left != BorderSide.none && b.top == BorderSide.none && b.right == BorderSide.none && b.bottom == BorderSide.none;
}

bool _isStrip(Widget w) {
  if (w is! Container) return false;
  final width = w.constraints?.maxWidth;
  final coloured = w.color != null || (w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color != null);
  return coloured && width != null && width <= 8 && w.child == null;
}

/// Every left accent bar on screen, described.
List<String> leftBars(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => true).evaluate())
        if ((e.widget is Container && _leftOnly((e.widget as Container).decoration)) ||
            (e.widget is DecoratedBox && _leftOnly((e.widget as DecoratedBox).decoration)) ||
            (e.widget is Ink && _leftOnly((e.widget as Ink).decoration)))
          'left border on ${e.widget.runtimeType} under ${e.findAncestorWidgetOfExactType<KeyedSubtree>()?.key ?? '-'}'
        else if (_isStrip(e.widget))
          'coloured strip ${e.widget.runtimeType}',
    ];

Future<NotificationFeedController> _feed(WidgetTester tester) async {
  final fs = FakeFirebaseFirestore();
  final at = t0.subtract(const Duration(hours: 1));
  final c = (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: at);
    await seed(fs, 'n2', 'paymentReceived', createdAt: at.subtract(const Duration(minutes: 1)), readAt: at);
    await seed(fs, 'n3', 'assistantPending', createdAt: at.subtract(const Duration(minutes: 2)), audience: 'admins');
    final c = newFeed(fs, 'A', Clock(), subs: Subs()..facts = expiring)..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

Set<String> _rows() => find
    .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('notification-more-'))
    .evaluate()
    .map((e) => (e.widget.key as ValueKey<String>).value.substring('notification-more-'.length))
    .toSet();

void main() {
  for (final size in _sizes) {
    final phone = size.width < 768;
    for (final look in MatrixLook.values) {
      final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name}';
      testWidgets('Notifications at $where: no left bar; search and filters only on wide screens', (tester) async {
        final c = await _feed(tester);
        await pumpNotifications(tester, c,
            width: size.width, height: size.height, dark: look == MatrixLook.dark, locale: look == MatrixLook.kiswahili ? 'sw' : 'en');
        expect(tester.takeException(), isNull);
        expect(leftBars(tester), isEmpty);
        expect(find.byType(TextField), phone ? findsNothing : findsOneWidget, reason: 'the search field');
        expect(find.byType(DropdownButton<String>), phone ? findsNothing : findsOneWidget, reason: 'the status filter');
        expect(find.byIcon(Icons.calendar_today_outlined), phone ? findsNothing : findsOneWidget, reason: 'the date filter');
        if (phone) {
          expect(find.byKey(const ValueKey('notifications-summary')), findsOneWidget);
          expect(find.byKey(const ValueKey('notifications-chip-all')), findsOneWidget);
          expect(find.byKey(const ValueKey('notifications-page-more')), findsOneWidget, reason: 'the app bar\'s menu');
        }
      }, skip: _skip);

      ph5TestWidgets('Subscription at $where (a payment pending): no left bar', (tester) async {
        await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
            size: size, look: look, pushed: true, seed: (fs) => seedSubscription(fs, pending: true));
        expect(leftBars(tester), isEmpty);
      }, skip: _skip);

      ph5TestWidgets('the payment history at $where: no left bar, the status in a chip', (tester) async {
        await pumpPh5(tester, (fs) => SubscriptionHistoryScreen(facilityId: testFacilityId, primaryColor: Colors.teal, firestore: fs),
            size: size, look: look, pushed: true, seed: seedSubscription);
        expect(leftBars(tester), isEmpty);
      }, skip: _skip);
    }
  }

  testWidgets('the dropdown (wide): no left bar on its rows or announcements', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 1200, height: 800, dropdown: true);
    expect(leftBars(tester), isEmpty);
  }, skip: _skip);

  testWidgets('on a phone the chips still filter; selection mode keeps its actions', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 390, height: 1400);
    expect(_rows(), containsAll(['n1', 'n2']));
    await tester.ensureVisible(find.byKey(const ValueKey('notifications-chip-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications-chip-payment')));
    await tester.pumpAndSettle();
    expect(_rows(), {'n2'});
    await tester.ensureVisible(find.byKey(const ValueKey('notifications-chip-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications-chip-all')));
    await tester.pumpAndSettle();
    await tapPageAction(tester, 'Select');
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
  }, skip: _skip);
}
