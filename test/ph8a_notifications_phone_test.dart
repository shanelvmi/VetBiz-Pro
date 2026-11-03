// PH8a (1): the full Notifications page on phones, against the size matrix
// (phone_foundations.md section 10): 360x740, 390x844 and 740x360 in Light,
// Dark and Kiswahili, with long texts: no overflow, 48 px targets, no text
// under 12 px; the three-dots menu, selection mode and Load older too.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

Future<NotificationFeedController> _feed(WidgetTester tester, {int window = 200}) async {
  final fs = FakeFirebaseFirestore();
  final clock = Clock()..now = DateTime.now();
  final at = clock.now.subtract(const Duration(hours: 2));
  final c = (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: at, title: 'Low stock: $matrixLongProductName');
    await seed(fs, 'n2', 'paymentReceived', createdAt: at, readAt: at, title: 'Payment from $matrixLongClientName');
    await seed(fs, 'n3', 'assistantPending', createdAt: at, audience: 'admins');
    await seed(fs, 'n4', 'newClient', createdAt: at.subtract(const Duration(days: 1)));
    final subs = Subs()..facts = expiring;
    final c = newFeed(fs, 'A', clock, subs: subs, window: window)..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

void main() {
  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = '${size.label} ${look.name}';
      testWidgets('the page at $where: no overflow, 48 px targets, text 12 px or more', (tester) async {
        final c = await _feed(tester);
        await pumpNotifications(tester, c,
            width: size.size.width,
            height: size.size.height,
            dark: look == MatrixLook.dark,
            locale: look == MatrixLook.kiswahili ? 'sw' : 'en');
        await checkCase(tester, phone: true, where: 'Notifications $where');
      }, skip: _skip);
    }
  }

  testWidgets('the three-dots menu and selection mode at 360x740 in Kiswahili', (tester) async {
    final c = await _feed(tester);
    await pumpNotifications(tester, c, width: 360, height: 740, locale: 'sw');
    await openMenu(tester, 'n1');
    await checkCase(tester, phone: true, where: 'the menu');
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chagua'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-select-n4')));
    await tester.pumpAndSettle();
    await checkCase(tester, phone: true, where: 'selection mode');
  }, skip: _skip);

  testWidgets('Load older at 390x844', (tester) async {
    final c = await _feed(tester, window: 2);
    await pumpNotifications(tester, c, width: 390, height: 844);
    await tester.scrollUntilVisible(find.text('Load older'), 200,
        scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
    await checkCase(tester, phone: true, where: 'Load older');
  }, skip: _skip);
}
