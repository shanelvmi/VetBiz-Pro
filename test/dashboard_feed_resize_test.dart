// DASH-1 report A: the Recent Activity feed spun forever after the window
// was made narrower, and kept spinning when it was made wide again. The
// feed is built in one of two layout branches (side by side when wide,
// stacked when narrow), so a resize drops one StreamBuilder and builds
// another on the SAME cached stream. These pump the real feed, layout and
// query on the fake Firestore, as an admin and as an assistant (two scoped
// queries merged), and resize 1200 -> 400 -> 1200.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_panels.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/merged_query_stream.dart';

const _facility = 'facility1';
const _uid = 'assistant1';

Future<FakeFirebaseFirestore> _threeEntries() async {
  final fs = FakeFirebaseFirestore();
  final logs = fs
      .collection(Collections.facilities)
      .doc(_facility)
      .collection(Collections.activityLogs);
  for (var n = 1; n <= 3; n++) {
    await logs.add({
      'userId': _uid,
      'actionType': 'sales',
      'description': 'Entry $n',
      'timestamp': Timestamp.fromDate(DateTime(2026, 10, 1, 9, n)),
    });
  }
  return fs;
}

/// The dashboard's lower panels around the real feed, wide or stacked by
/// the dashboard's own breakpoint. [stream] is made once, as the dashboard
/// caches it; [feedKey] is the dashboard's GlobalKey on the feed.
Widget _dashboard(
  Stream<List<LogDoc>> stream, {
  Key? feedKey,
  VoidCallback? onRetry,
}) => MaterialApp(
  theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: LayoutBuilder(
        builder:
            (context, constraints) => DashboardLowerPanels(
              glance: const SizedBox(height: 60),
              wide: constraints.maxWidth >= AppBreakpoints.expanded,
              chart: const SizedBox(height: 100),
              feed: RecentActivityFeed(
                key: feedKey,
                stream: stream,
                onRetry: onRetry,
              ),
              quickActions: const SizedBox(height: 50),
            ),
      ),
    ),
  ),
);

Future<void> _resize(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 2000));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The stream as cloud_firestore gives it (web and mobile): one live
/// listener per query, shared by every listener, replaying nothing.
Stream<QuerySnapshot<Map<String, dynamic>>> _sharedLikeCloudFirestore(
  Query<Map<String, dynamic>> q,
) => q.snapshots().asBroadcastStream();

/// The test font draws every letter as a full square, so the card's header
/// overflows by a few pixels where real text fits; only that is ignored.
void _ignoreTestFontOverflow() {
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!'${details.exception}'.contains('overflowed')) onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);
}

void main() {
  for (final (who, isAdmin, snapshotsOf) in [
    ('admin', true, _sharedLikeCloudFirestore),
    ('admin (the fake\'s own stream)', true, null),
    ('assistant', false, null),
  ]) {
    for (final keepFeed in [true, false]) {
      testWidgets(
        '$who${keepFeed ? '' : ', without the GlobalKey'}: the feed shows its entries after every resize',
        (tester) async {
          addTearDown(() => tester.binding.setSurfaceSize(null));
          _ignoreTestFontOverflow();
          final fs = await _threeEntries();
          final stream = recentActivityStream(
            fs,
            _facility,
            isAdmin: isAdmin,
            uid: _uid,
            snapshotsOf: snapshotsOf,
          );

          await tester.binding.setSurfaceSize(const Size(1200, 2000));
          final feedKey = keepFeed ? GlobalKey() : null;
          await tester.pumpWidget(_dashboard(stream, feedKey: feedKey));
          await _resize(tester, 1200);
          expect(
            find.text('Entry 3'),
            findsOneWidget,
            reason: 'wide, first build',
          );

          await _resize(tester, 400);
          expect(tester.takeException(), isNull);
          expect(find.text('Entry 3'), findsOneWidget, reason: 'narrow');

          await _resize(tester, 1200);
          expect(tester.takeException(), isNull);
          expect(find.text('Entry 3'), findsOneWidget, reason: 'wide again');
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'no answer: after the timeout the feed says it could not load and offers Retry',
    (tester) async {
      _ignoreTestFontOverflow();
      final never = StreamController<List<LogDoc>>.broadcast();
      addTearDown(never.close);
      var retried = 0;
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _dashboard(never.stream, onRetry: () => retried++),
      );
      await tester.pump(
        AppTimeouts.liveCardFirstAnswer - const Duration(seconds: 1),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Couldn't load recent activity."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    },
  );
}
