// RV2b (2) (docs/design/screen_reveal.md 8.1): Notifications, the full page
// (phones and wide) and the dropdown, arrive as one piece. Primary = the
// feed's first page and my state (NotificationFeedController.isLoading);
// a feed already loaded (the bell's, passed in) shows at once with no
// skeleton; the summary line and the chips keep their slots; actions
// (Load older, a refresh, a filter) never replay it; reduced motion is
// instant; no spinner while the first page is late.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/notification_harness.dart';
import 'helpers/phone_list_harness.dart' show ph5PhoneSizes;
import 'helpers/screen_size_matrix.dart';

const _skip = true;

const _skeleton = ValueKey('notifications-revealSkeleton');

/// A feed whose first answer the test gives: loading until [answer].
class _LateFeed extends NotificationFeedController {
  _LateFeed(FakeFirebaseFirestore fs) : super(firestore: fs, facilityId: 'F1', uid: 'A', isAdmin: () => true);

  bool loading = true;
  Object? failure;
  int starts = 0;

  @override
  bool get isLoading => loading;

  @override
  Object? get error => failure;

  @override
  void start() => starts++;

  void answer({Object? error}) {
    failure = error;
    loading = false;
    notifyListeners();
  }
}

Future<void> _pump(WidgetTester tester, NotificationFeedController feed,
    {Size size = const Size(390, 844), bool dropdown = false, bool still = false, MatrixLook look = MatrixLook.light}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final screen = NotificationsScreen(isDropdown: dropdown, controller: feed);
  // A fresh tree each time: a second pump in one test gets a new screen.
  await tester.pumpWidget(KeyedSubtree(key: UniqueKey(), child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'),
    theme: AppTheme.build(AppColorTheme.pasture, look == MatrixLook.dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: still), child: child!),
    home: dropdown
        ? Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 400, height: 600, child: Material(child: screen))))
        : screen,
  )));
  await tester.pump();
}

_LateFeed _late(WidgetTester tester) {
  final feed = _LateFeed(FakeFirebaseFirestore());
  addTearDown(feed.dispose);
  return feed;
}

Future<NotificationFeedController> _held(WidgetTester tester) async {
  final fs = FakeFirebaseFirestore();
  final c = (await tester.runAsync(() async {
    await seed(fs, 'n1', 'lowStock', createdAt: t0);
    await seed(fs, 'n2', 'paymentReceived', createdAt: t0.subtract(const Duration(minutes: 1)), readAt: t0);
    final c = newFeed(fs, 'A', Clock())..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

void main() {
  for (final (label, size, dropdown) in [
    ('phone page', const Size(390, 844), false),
    ('wide page', const Size(1200, 800), false),
    ('dropdown', const Size(1200, 800), true),
  ]) {
    testWidgets('$label: a late first page shows the skeleton at once (no spinner) and reveals at 1200 ms', (tester) async {
      final feed = _late(tester);
      await _pump(tester, feed, size: size, dropdown: dropdown);
      expect(find.byKey(_skeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(AppTimeouts.revealGate);
      await tester.pump();
      // The fade, then the frame that drops the skeleton (as rv2_list_reveal).
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_skeleton), findsNothing);
      // Still waiting after the timeout: the in-place skeleton rows, never a spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      feed.answer();
      await tester.pumpAndSettle();
      expect(find.byKey(_skeleton), findsNothing);
    }, skip: _skip);

    testWidgets('$label: a feed already loaded shows at once, no skeleton, no rise', (tester) async {
      final feed = await _held(tester);
      await _pump(tester, feed, size: size, dropdown: dropdown);
      expect(find.byKey(_skeleton), findsNothing);
      expect(find.byType(SkeletonPulse), findsNothing);
    }, skip: _skip);
  }

  testWidgets('the first page answers: one fade and rise, then the rows', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    await tester.pump(const Duration(milliseconds: 300));
    feed.answer();
    await tester.pump();
    await tester.pump(AppMotion.revealDuration ~/ 2);
    expect(find.byKey(_skeleton), findsOneWidget, reason: 'the skeleton fades out');
    await tester.pumpAndSettle();
    expect(find.byKey(_skeleton), findsNothing);
  }, skip: _skip);

  testWidgets('an error answers it (the error shows in the revealed page)', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    feed.answer(error: StateError('boom'));
    await tester.pumpAndSettle();
    expect(find.byKey(_skeleton), findsNothing);
    expect(find.textContaining('boom'), findsOneWidget);
  }, skip: _skip);

  testWidgets('an empty feed answers it', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    feed.answer();
    await tester.pumpAndSettle();
    expect(find.byKey(_skeleton), findsNothing);
  }, skip: _skip);

  testWidgets('loading again later (a refresh, Load older) never replays the reveal', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    feed.answer();
    await tester.pumpAndSettle();
    feed
      ..loading = true
      ..notifyListeners();
    await tester.pump();
    expect(find.byKey(_skeleton), findsNothing);
    feed.answer();
    await tester.pumpAndSettle();
    expect(find.byKey(_skeleton), findsNothing);
  }, skip: _skip);

  testWidgets('a rebuild, a resize and a theme change never replay it', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    feed.answer();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();
    expect(find.byKey(_skeleton), findsNothing);
  }, skip: _skip);

  testWidgets('reduced motion: the swap is instant', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed, still: true);
    feed.answer();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_skeleton), findsNothing);
  }, skip: _skip);

  testWidgets('the feed is started once; the reveal adds no listener of its own', (tester) async {
    final feed = _late(tester);
    await _pump(tester, feed);
    feed.answer();
    await tester.pumpAndSettle();
    expect(feed.starts, 1);
  }, skip: _skip);

  testWidgets('phone: the summary line and the chips keep their slot (same rects as the loaded page)', (tester) async {
    final held = await _held(tester);
    await _pump(tester, held);
    await tester.pumpAndSettle();
    final chips = tester.getRect(find.byKey(const ValueKey('notifications-chip-all')));
    final summary = tester.getRect(find.byKey(const ValueKey('notifications-summary')));
    final feed = _late(tester);
    await _pump(tester, feed);
    final slot = tester.getRect(find.byKey(const ValueKey('notifications-skeleton-summary')));
    expect((slot.top, slot.height, slot.left), (summary.top, summary.height, summary.left));
    expect(tester.getRect(find.byKey(const ValueKey('notifications-skeleton-chips'))).top, chips.top);
  }, skip: _skip);

  for (final size in [...ph5PhoneSizes.map((s) => s.size), const Size(768, 1024), const Size(1024, 768), const Size(1200, 800)]) {
    for (final look in MatrixLook.values) {
      testWidgets('size ${size.width.toInt()}x${size.height.toInt()} ${look.name}: skeleton and page, no overflow', (tester) async {
        final feed = _late(tester);
        await _pump(tester, feed, size: size, look: look);
        expect(tester.takeException(), isNull);
        expect(find.byKey(_skeleton), findsOneWidget);
        feed.answer();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width < 600) await checkCase(tester, phone: true, where: 'notifications ${size.width}x${size.height} ${look.name}');
      }, skip: _skip);
    }
  }
}
