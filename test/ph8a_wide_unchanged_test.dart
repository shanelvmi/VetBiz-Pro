// PH8a: tablets and computers keep today's screens exactly. At 768x1024,
// 1024x768 and 1200x800 the whole widget tree of each is compared with the
// fingerprint recorded from the code before PH8a
// (test/fixtures/ph5a_wide_fingerprints.json, the ph8a- names): the Products
// and Stock Store bells' panels and the Notifications page and dropdown.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${treeFingerprint(tester, root.first)}');

/// The notifications every look shows: one of each class, with a long text.
Future<NotificationFeedController> _feed(WidgetTester tester) async {
  final fs = FakeFirebaseFirestore();
  // Two hours before now, so "2 hours ago" never changes from day to day.
  final clock = Clock()..now = DateTime.now();
  final at = clock.now.subtract(const Duration(hours: 2));
  return (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: at, title: 'Low stock: Albendazole 10% Chupa ya Lita Moja');
    await seed(fs, 'n2', 'paymentReceived', createdAt: at, readAt: at);
    await seed(fs, 'n3', 'assistantPending', createdAt: at, audience: 'admins');
    await seed(fs, 'n4', 'newClient', createdAt: at);
    final subs = Subs()..facts = expiring;
    final c = newFeed(fs, 'A', clock, subs: subs)..start();
    await settle();
    return c;
  }))!;
}

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    // Below 900 the bell pushes the page, which ph7a- already pins.
    if (size.width >= 900) {
      for (final (name, build) in [
        ('products', (dynamic fs) => ProductsScreen(firestore: fs) as Widget),
        ('stockstore', (dynamic fs) => const StockStoreScreen() as Widget),
      ]) {
        ph5TestWidgets('ph8a-$name-bell-$at: the stock alerts bell\'s panel, placed as before PH8a', (tester) async {
          await pumpPh5(tester, build, size: size, pushed: true, seed: ph7SeedProducts);
          await tester.tap(find.byTooltip('Stock Alerts'));
          await ph5Settle(tester);
          // The route's whole page: the panel's place and size in the window.
          _expect(
            tester,
            'ph8a-$name-bell-$at',
            find.ancestor(of: find.byType(StockAlertsScreen), matching: find.byType(Stack)).last,
          );
        }, skip: _skip);
      }
    }

    for (final dropdown in [false, true]) {
      final kind = dropdown ? 'dropdown' : 'page';
      testWidgets('ph8a-notifications-$kind-$at: as before PH8a', (tester) async {
        final c = await _feed(tester);
        addTearDown(c.dispose);
        await pumpNotifications(tester, c, width: size.width, height: size.height, dropdown: dropdown);
        _expect(tester, 'ph8a-notifications-$kind-$at', find.byType(NotificationsScreen));
        await tester.pumpWidget(const SizedBox());
      }, skip: _skip);
    }
  }
}
