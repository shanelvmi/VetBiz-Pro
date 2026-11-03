// PH8a (1): every notifications bell opens through one helper: the full
// Notifications page on a phone (pushed over the bar; Back returns to the
// same tab and scroll), the dropdown on a wide window, exactly as before
// (below AppBreakpoints.medium the page, as the dashboard did). And the
// bell's unread number (NOTIF-2d, docs/design/notifications.md section 3):
// 1 to 9 then 9+, per person, persistent items counted, the trial not.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/notification_bell.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/notification_harness.dart';
import 'helpers/screen_size_matrix.dart';

// Was true until the implementation (every call threw UnimplementedError).
const _skip = false;

final _anchor = GlobalKey();

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
  home: home,
);

Widget _bell(NotificationFeedController c) => Builder(
  builder:
      (context) => IconButton(
        key: _anchor,
        tooltip: 'BELL',
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () => openNotifications(context, anchorKey: _anchor, controller: c),
      ),
);

Widget _rows(String name) => ListView(
  key: ValueKey('$name list'),
  children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('$name row $i'))],
);

Future<NotificationFeedController> _feed(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final fs = FakeFirebaseFirestore();
  final c =
      (await tester.runAsync(() async {
        await seed(fs, 'n1', 'lowStock');
        final c = newFeed(fs, 'A', Clock())..start();
        await settle();
        return c;
      }))!;
  addTearDown(c.dispose);
  return c;
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

NotificationsScreen _shown(WidgetTester tester) => tester.widget<NotificationsScreen>(find.byType(NotificationsScreen));

double _offset(WidgetTester tester, String name) =>
    tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(ValueKey('$name list')), matching: find.byType(Scrollable)),
        )
        .position
        .pixels;

void main() {
  group('the bell\'s number', () {
    testWidgets('none at 0, 1 to 9, then 9+', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              final l = context.l10n;
              expect(bellCountLabel(0, l), isNull);
              expect(bellCountLabel(1, l), '1');
              expect(bellCountLabel(9, l), '9');
              expect(bellCountLabel(10, l), '9+');
              expect(bellCountLabel(150, l), '9+');
              return const SizedBox();
            },
          ),
        ),
      );
    }, skip: _skip);

    test('per person, persistent items counted, read and the trial not', () async {
      final fs = FakeFirebaseFirestore();
      final subs = Subs()..facts = const SubscriptionFacts(trialInfo: (title: 'Free Trial', message: '20 days left'));
      await seed(fs, 'n1', 'lowStock');
      await seed(fs, 'n2', 'paymentReceived');
      await seed(fs, 'n3', 'newClient');
      await seed(fs, 'old', 'lowStock', readAt: t0);
      final a = newFeed(fs, 'A', Clock(), subs: subs)..start();
      final b = newFeed(fs, 'B', Clock(), subs: subs)..start();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await settle();
      expect(a.unreadAlertCount, 3, reason: 'the read one and the calm trial do not count');
      await a.markRead([a.items.firstWhere((i) => i.id == 'n1')]);
      await settle();
      expect(a.unreadAlertCount, 2);
      expect(b.unreadAlertCount, 3, reason: 'my read is mine');
      subs.set(expiring);
      await settle();
      expect(a.unreadAlertCount, 3, reason: 'the subscription notice counts until I read it');
    }, skip: _skip);

    testWidgets('the icon shows the number, 12 px or more, and nothing at 0', (tester) async {
      _size(tester, const Size(390, 844));
      for (final (count, text) in [(0, null), (3, '3'), (9, '9'), (12, '9+')]) {
        await tester.pumpWidget(_app(Scaffold(body: Center(child: NotificationBellIcon(count: count)))));
        expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
        if (text == null) {
          expect(find.byType(Text), findsNothing);
        } else {
          expect(find.text(text), findsOneWidget);
        }
        expect(smallTexts(tester), isEmpty);
      }
    }, skip: _skip);
  });

  group('the bell opens', () {
    for (final (size, page) in [
      (const Size(360, 740), true),
      (const Size(390, 844), true),
      (const Size(740, 360), true),
      // A large phone turned sideways: the phone signal, though 900 wide or more.
      (const Size(960, 420), true),
      // As before: below AppBreakpoints.medium a page, from it the dropdown.
      (const Size(768, 1024), true),
      (const Size(1024, 768), false),
      (const Size(1200, 800), false),
    ]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(
        'at $at: ${page ? 'the full page, and Back returns to the same scroll' : 'the dropdown, as before'}',
        (tester) async {
          _size(tester, size);
          final c = await _feed(tester);
          await tester.pumpWidget(_app(Scaffold(appBar: AppBar(actions: [_bell(c)]), body: _rows('home'))));
          await tester.drag(find.byKey(const ValueKey('home list')), const Offset(0, -300));
          await tester.pumpAndSettle();
          final before = _offset(tester, 'home');
          await tester.tap(find.byTooltip('BELL'));
          await tester.pumpAndSettle();
          expect(_shown(tester).isDropdown, !page);
          if (!page) {
            expect(tester.getSize(find.byType(NotificationsScreen)).width, 400);
            return;
          }
          expect(find.byType(BackButton), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(NotificationsScreen), findsNothing);
          expect(_offset(tester, 'home'), before);
        },
        skip: _skip,
      );
    }

    testWidgets('in the phone shell the page covers the bar; Back returns to the same tab', (tester) async {
      _size(tester, const Size(390, 844));
      final c = await _feed(tester);
      await tester.pumpWidget(
        _app(
          PhoneShell(
            homeAppBar: AppBar(actions: [_bell(c)]),
            home: (_) => _rows('home'),
            sales: (_) => _rows('sales'),
            products: (_) => _rows('products'),
            more: (_) => _rows('more'),
            onRecord: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('home list')), const Offset(0, -300));
      await tester.pumpAndSettle();
      final before = _offset(tester, 'home');
      await tester.tap(find.byTooltip('BELL'));
      await tester.pumpAndSettle();
      expect(_shown(tester).isDropdown, isFalse);
      expect(find.byType(PhoneBottomBar), findsNothing, reason: 'the page is pushed over the bar');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneBottomBar), findsOneWidget);
      expect(_offset(tester, 'home'), before);
    }, skip: _skip);

    test('every bell goes through the one helper; the copies are gone', () {
      final dashboard = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
      expect(dashboard.contains('_showNotificationsDropdown'), isFalse);
      expect(dashboard.contains('openNotifications('), isTrue);
      expect(dashboard.contains('NotificationBellIcon('), isTrue);
      for (final path in ['lib/screens/products/products_screen.dart', 'lib/screens/store/stockstore_screen.dart']) {
        final source = File(path).readAsStringSync();
        expect(source.contains('_showNotificationsDropdown'), isFalse, reason: path);
        expect(source.contains('showAnchoredDropdown('), isTrue, reason: path);
      }
    }, skip: _skip);
  });
}
